#!/usr/bin/env python3
"""
Decentralize AI - Federated Learning System

This module implements a decentralized federated learning system that allows
multiple participants to collaboratively train AI models without sharing raw data.
It includes privacy-preserving techniques, secure aggregation, and incentive mechanisms.
"""

import asyncio
import hashlib
import json
import logging
import time
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from enum import Enum
import numpy as np
import torch
import torch.nn as nn
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.backends import default_backend
import flwr as fl
from flwr.common import (
    Code,
    EvaluateIns,
    EvaluateRes,
    FitIns,
    FitRes,
    GetParametersIns,
    GetParametersRes,
    Status,
    ndarrays_to_parameters,
    parameters_to_ndarrays,
)
from flwr.server import ServerApp, ServerConfig
from flwr.server.strategy import FedAvg
import syft as sy
from syft import VirtualMachine
from syft.core.node.common.action.get_object_action import GetObjectAction
from syft.core.node.common.action.save_object_action import SaveObjectAction
import ray
from ray import tune
import wandb
from web3 import Web3
import ipfshttpclient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ContributionType(Enum):
    """Types of contributions to the federated learning system"""
    MODEL_UPDATE = "model_update"
    DATA_CONTRIBUTION = "data_contribution"
    COMPUTATIONAL_RESOURCE = "computational_resource"
    VALIDATION = "validation"
    RESEARCH = "research"

class PrivacyLevel(Enum):
    """Privacy levels for federated learning"""
    NONE = "none"
    DIFFERENTIAL_PRIVACY = "differential_privacy"
    SECURE_AGGREGATION = "secure_aggregation"
    HOMOMORPHIC_ENCRYPTION = "homomorphic_encryption"

@dataclass
class Contribution:
    """Represents a contribution to the federated learning system"""
    id: str
    contributor_id: str
    contribution_type: ContributionType
    model_weights: Optional[Dict[str, np.ndarray]] = None
    data_hash: Optional[str] = None
    computational_units: Optional[int] = None
    quality_score: float = 0.0
    privacy_level: PrivacyLevel = PrivacyLevel.NONE
    timestamp: float = 0.0
    proof_of_work: Optional[str] = None
    signature: Optional[str] = None

@dataclass
class ModelMetadata:
    """Metadata for a federated learning model"""
    model_id: str
    name: str
    architecture: str
    version: str
    parameters: Dict[str, Any]
    performance_metrics: Dict[str, float]
    training_rounds: int
    contributors: List[str]
    privacy_level: PrivacyLevel
    created_at: float
    updated_at: float

class SecureAggregator:
    """Implements secure aggregation for federated learning"""
    
    def __init__(self, num_participants: int, threshold: int = None):
        self.num_participants = num_participants
        self.threshold = threshold or (num_participants // 2 + 1)
        self.participants = {}
        self.aggregated_weights = None
        
    def add_participant(self, participant_id: str, public_key: bytes):
        """Add a participant with their public key"""
        self.participants[participant_id] = public_key
        
    def secure_aggregate(self, contributions: List[Contribution]) -> Dict[str, np.ndarray]:
        """Securely aggregate model updates from multiple participants"""
        if len(contributions) < self.threshold:
            raise ValueError(f"Not enough contributions. Need {self.threshold}, got {len(contributions)}")
        
        # Verify contributions
        verified_contributions = []
        for contribution in contributions:
            if self._verify_contribution(contribution):
                verified_contributions.append(contribution)
            else:
                logger.warning(f"Invalid contribution from {contribution.contributor_id}")
        
        if len(verified_contributions) < self.threshold:
            raise ValueError("Not enough valid contributions after verification")
        
        # Aggregate model weights
        aggregated_weights = {}
        for contribution in verified_contributions:
            if contribution.model_weights:
                for layer_name, weights in contribution.model_weights.items():
                    if layer_name not in aggregated_weights:
                        aggregated_weights[layer_name] = np.zeros_like(weights)
                    aggregated_weights[layer_name] += weights
        
        # Average the weights
        for layer_name in aggregated_weights:
            aggregated_weights[layer_name] /= len(verified_contributions)
        
        self.aggregated_weights = aggregated_weights
        return aggregated_weights
    
    def _verify_contribution(self, contribution: Contribution) -> bool:
        """Verify the authenticity and validity of a contribution"""
        # Verify signature
        if not self._verify_signature(contribution):
            return False
        
        # Verify proof of work
        if not self._verify_proof_of_work(contribution):
            return False
        
        # Verify model weights format
        if contribution.model_weights:
            for layer_name, weights in contribution.model_weights.items():
                if not isinstance(weights, np.ndarray):
                    return False
                if np.any(np.isnan(weights)) or np.any(np.isinf(weights)):
                    return False
        
        return True
    
    def _verify_signature(self, contribution: Contribution) -> bool:
        """Verify the cryptographic signature of a contribution"""
        if not contribution.signature:
            return False
        
        try:
            # This is a simplified verification - in practice, you'd use proper cryptographic verification
            return len(contribution.signature) > 0
        except Exception:
            return False
    
    def _verify_proof_of_work(self, contribution: Contribution) -> bool:
        """Verify the proof of work for a contribution"""
        if not contribution.proof_of_work:
            return False
        
        # Simple proof of work verification
        data = f"{contribution.contributor_id}{contribution.timestamp}{contribution.model_weights}"
        hash_result = hashlib.sha256(data.encode()).hexdigest()
        return hash_result.startswith("0000")  # Simple difficulty

class DifferentialPrivacy:
    """Implements differential privacy for federated learning"""
    
    def __init__(self, epsilon: float = 1.0, delta: float = 1e-5):
        self.epsilon = epsilon
        self.delta = delta
    
    def add_noise(self, weights: Dict[str, np.ndarray], sensitivity: float = 1.0) -> Dict[str, np.ndarray]:
        """Add calibrated noise to model weights"""
        noisy_weights = {}
        
        for layer_name, weight_array in weights.items():
            # Calculate noise scale
            noise_scale = sensitivity / self.epsilon
            
            # Generate Gaussian noise
            noise = np.random.normal(0, noise_scale, weight_array.shape)
            
            # Add noise to weights
            noisy_weights[layer_name] = weight_array + noise
        
        return noisy_weights
    
    def calculate_sensitivity(self, weights: Dict[str, np.ndarray]) -> float:
        """Calculate the sensitivity of model weights"""
        total_norm = 0.0
        for weight_array in weights.values():
            total_norm += np.linalg.norm(weight_array)
        return total_norm

class FederatedLearningCoordinator:
    """Coordinates federated learning across multiple participants"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.models = {}
        self.contributions = {}
        self.participants = {}
        self.secure_aggregator = SecureAggregator(config.get("max_participants", 100))
        self.differential_privacy = DifferentialPrivacy(
            epsilon=config.get("epsilon", 1.0),
            delta=config.get("delta", 1e-5)
        )
        self.web3 = Web3(Web3.HTTPProvider(config.get("ethereum_rpc", "http://localhost:8545")))
        self.ipfs_client = ipfshttpclient.connect(config.get("ipfs_gateway", "/ip4/127.0.0.1/tcp/5001"))
        
        # Initialize Ray for distributed computing
        if not ray.is_initialized():
            ray.init(address=config.get("ray_address", "auto"))
    
    async def start_training_round(self, model_id: str, participants: List[str]) -> str:
        """Start a new federated learning training round"""
        round_id = f"round_{int(time.time())}"
        
        logger.info(f"Starting training round {round_id} for model {model_id}")
        
        # Initialize round
        round_config = {
            "model_id": model_id,
            "participants": participants,
            "start_time": time.time(),
            "status": "active"
        }
        
        # Store round configuration
        await self._store_round_config(round_id, round_config)
        
        # Notify participants
        await self._notify_participants(participants, {
            "type": "training_round_start",
            "round_id": round_id,
            "model_id": model_id
        })
        
        return round_id
    
    async def submit_contribution(self, contribution: Contribution) -> bool:
        """Submit a contribution to the federated learning system"""
        try:
            # Validate contribution
            if not self._validate_contribution(contribution):
                logger.error(f"Invalid contribution from {contribution.contributor_id}")
                return False
            
            # Store contribution
            self.contributions[contribution.id] = contribution
            
            # Update participant info
            if contribution.contributor_id not in self.participants:
                self.participants[contribution.contributor_id] = {
                    "total_contributions": 0,
                    "quality_score": 0.0,
                    "last_contribution": time.time()
                }
            
            self.participants[contribution.contributor_id]["total_contributions"] += 1
            self.participants[contribution.contributor_id]["quality_score"] = contribution.quality_score
            self.participants[contribution.contributor_id]["last_contribution"] = time.time()
            
            # Store on IPFS for decentralization
            await self._store_contribution_ipfs(contribution)
            
            # Update blockchain if configured
            if self.config.get("use_blockchain", False):
                await self._update_blockchain(contribution)
            
            logger.info(f"Contribution {contribution.id} submitted successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to submit contribution: {e}")
            return False
    
    async def aggregate_contributions(self, round_id: str) -> Dict[str, np.ndarray]:
        """Aggregate contributions for a training round"""
        try:
            # Get contributions for this round
            round_contributions = await self._get_round_contributions(round_id)
            
            if len(round_contributions) < self.config.get("min_contributions", 3):
                raise ValueError("Not enough contributions for aggregation")
            
            # Apply privacy-preserving techniques
            if self.config.get("use_differential_privacy", False):
                for contribution in round_contributions:
                    if contribution.model_weights:
                        contribution.model_weights = self.differential_privacy.add_noise(
                            contribution.model_weights
                        )
            
            # Securely aggregate contributions
            aggregated_weights = self.secure_aggregator.secure_aggregate(round_contributions)
            
            # Store aggregated model
            await self._store_aggregated_model(round_id, aggregated_weights)
            
            logger.info(f"Successfully aggregated {len(round_contributions)} contributions")
            return aggregated_weights
            
        except Exception as e:
            logger.error(f"Failed to aggregate contributions: {e}")
            raise
    
    async def evaluate_model(self, model_id: str, test_data: Dict[str, Any]) -> Dict[str, float]:
        """Evaluate a federated learning model"""
        try:
            # Get model weights
            model_weights = await self._get_model_weights(model_id)
            
            # Load test data
            test_dataset = self._load_test_data(test_data)
            
            # Evaluate model
            metrics = await self._evaluate_model_weights(model_weights, test_dataset)
            
            # Update model metadata
            await self._update_model_metrics(model_id, metrics)
            
            return metrics
            
        except Exception as e:
            logger.error(f"Failed to evaluate model: {e}")
            raise
    
    def _validate_contribution(self, contribution: Contribution) -> bool:
        """Validate a contribution"""
        # Check required fields
        if not contribution.id or not contribution.contributor_id:
            return False
        
        # Check contribution type
        if contribution.contribution_type not in ContributionType:
            return False
        
        # Check model weights format
        if contribution.model_weights:
            for layer_name, weights in contribution.model_weights.items():
                if not isinstance(weights, np.ndarray):
                    return False
                if np.any(np.isnan(weights)) or np.any(np.isinf(weights)):
                    return False
        
        # Check quality score
        if not (0.0 <= contribution.quality_score <= 1.0):
            return False
        
        return True
    
    async def _store_contribution_ipfs(self, contribution: Contribution):
        """Store contribution on IPFS"""
        try:
            # Serialize contribution
            contribution_data = asdict(contribution)
            
            # Store on IPFS
            result = self.ipfs_client.add_json(contribution_data)
            contribution.ipfs_hash = result["Hash"]
            
            logger.info(f"Contribution stored on IPFS: {contribution.ipfs_hash}")
            
        except Exception as e:
            logger.error(f"Failed to store contribution on IPFS: {e}")
    
    async def _update_blockchain(self, contribution: Contribution):
        """Update blockchain with contribution information"""
        try:
            # This would interact with smart contracts
            # For now, just log the action
            logger.info(f"Updating blockchain with contribution {contribution.id}")
            
        except Exception as e:
            logger.error(f"Failed to update blockchain: {e}")
    
    async def _store_round_config(self, round_id: str, config: Dict[str, Any]):
        """Store round configuration"""
        # In a real implementation, this would store to a database
        logger.info(f"Storing round config for {round_id}")
    
    async def _notify_participants(self, participants: List[str], message: Dict[str, Any]):
        """Notify participants about training round"""
        # In a real implementation, this would send notifications
        logger.info(f"Notifying {len(participants)} participants")
    
    async def _get_round_contributions(self, round_id: str) -> List[Contribution]:
        """Get contributions for a specific round"""
        # In a real implementation, this would query the database
        return list(self.contributions.values())
    
    async def _store_aggregated_model(self, round_id: str, weights: Dict[str, np.ndarray]):
        """Store aggregated model weights"""
        # In a real implementation, this would store to a database
        logger.info(f"Storing aggregated model for round {round_id}")
    
    async def _get_model_weights(self, model_id: str) -> Dict[str, np.ndarray]:
        """Get model weights by ID"""
        # In a real implementation, this would query the database
        return {}
    
    def _load_test_data(self, test_data: Dict[str, Any]) -> Any:
        """Load test data for evaluation"""
        # In a real implementation, this would load actual test data
        return test_data
    
    async def _evaluate_model_weights(self, weights: Dict[str, np.ndarray], test_dataset: Any) -> Dict[str, float]:
        """Evaluate model weights on test dataset"""
        # In a real implementation, this would run actual evaluation
        return {
            "accuracy": 0.85,
            "precision": 0.82,
            "recall": 0.88,
            "f1_score": 0.85
        }
    
    async def _update_model_metrics(self, model_id: str, metrics: Dict[str, float]):
        """Update model performance metrics"""
        # In a real implementation, this would update the database
        logger.info(f"Updating metrics for model {model_id}")

class FederatedLearningClient:
    """Client for participating in federated learning"""
    
    def __init__(self, client_id: str, config: Dict[str, Any]):
        self.client_id = client_id
        self.config = config
        self.model = None
        self.training_data = None
        self.coordinator = None
        
    async def join_federation(self, coordinator_url: str):
        """Join a federated learning federation"""
        try:
            # Connect to coordinator
            self.coordinator = FederatedLearningCoordinator(self.config)
            
            # Register with coordinator
            await self._register_with_coordinator(coordinator_url)
            
            logger.info(f"Client {self.client_id} joined federation")
            
        except Exception as e:
            logger.error(f"Failed to join federation: {e}")
            raise
    
    async def train_model(self, model_weights: Dict[str, np.ndarray], training_data: Any) -> Dict[str, np.ndarray]:
        """Train model on local data"""
        try:
            # Load model with provided weights
            self.model = self._load_model(model_weights)
            
            # Train on local data
            updated_weights = await self._train_local_model(training_data)
            
            # Create contribution
            contribution = Contribution(
                id=f"contrib_{self.client_id}_{int(time.time())}",
                contributor_id=self.client_id,
                contribution_type=ContributionType.MODEL_UPDATE,
                model_weights=updated_weights,
                quality_score=self._calculate_quality_score(),
                timestamp=time.time()
            )
            
            # Submit contribution
            success = await self.coordinator.submit_contribution(contribution)
            
            if success:
                logger.info(f"Client {self.client_id} submitted model update")
                return updated_weights
            else:
                raise Exception("Failed to submit contribution")
                
        except Exception as e:
            logger.error(f"Failed to train model: {e}")
            raise
    
    def _load_model(self, weights: Dict[str, np.ndarray]) -> nn.Module:
        """Load model with provided weights"""
        # In a real implementation, this would load the actual model
        return nn.Module()
    
    async def _train_local_model(self, training_data: Any) -> Dict[str, np.ndarray]:
        """Train model on local data"""
        # In a real implementation, this would perform actual training
        return {}
    
    def _calculate_quality_score(self) -> float:
        """Calculate quality score for the contribution"""
        # In a real implementation, this would calculate actual quality metrics
        return 0.85
    
    async def _register_with_coordinator(self, coordinator_url: str):
        """Register with the federated learning coordinator"""
        # In a real implementation, this would register with the coordinator
        logger.info(f"Registering with coordinator at {coordinator_url}")

# Example usage
async def main():
    """Example usage of the federated learning system"""
    
    # Configuration
    config = {
        "max_participants": 100,
        "min_contributions": 3,
        "epsilon": 1.0,
        "delta": 1e-5,
        "use_differential_privacy": True,
        "use_blockchain": True,
        "ethereum_rpc": "http://localhost:8545",
        "ipfs_gateway": "/ip4/127.0.0.1/tcp/5001"
    }
    
    # Create coordinator
    coordinator = FederatedLearningCoordinator(config)
    
    # Start training round
    participants = ["client1", "client2", "client3"]
    round_id = await coordinator.start_training_round("model_1", participants)
    
    # Simulate contributions
    for i, participant in enumerate(participants):
        contribution = Contribution(
            id=f"contrib_{participant}_{i}",
            contributor_id=participant,
            contribution_type=ContributionType.MODEL_UPDATE,
            model_weights={"layer1": np.random.randn(100, 50)},
            quality_score=0.8 + i * 0.05,
            timestamp=time.time()
        )
        
        await coordinator.submit_contribution(contribution)
    
    # Aggregate contributions
    aggregated_weights = await coordinator.aggregate_contributions(round_id)
    
    print(f"Aggregated weights: {list(aggregated_weights.keys())}")

if __name__ == "__main__":
    asyncio.run(main())
