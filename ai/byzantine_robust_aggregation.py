#!/usr/bin/env python3
"""
Decentralize AI - Byzantine-Robust Aggregation

This module implements Byzantine-robust aggregation algorithms for federated learning
that can handle malicious participants and ensure the integrity of the learning process.

Features:
- Krum aggregation algorithm
- Bulyan aggregation algorithm
- Coordinate-wise median aggregation
- Trimmed mean aggregation
- Byzantine-robust secure aggregation
- Adaptive threshold mechanisms
"""

import numpy as np
import torch
import torch.nn as nn
from typing import Dict, List, Tuple, Any, Optional, Callable
import asyncio
import time
from dataclasses import dataclass
from enum import Enum
import logging
from scipy import stats
from sklearn.cluster import DBSCAN
import warnings
warnings.filterwarnings('ignore')

logger = logging.getLogger(__name__)

class AggregationMethod(Enum):
    """Available aggregation methods"""
    FEDAVG = "fedavg"
    KRUM = "krum"
    BULYAN = "bulyan"
    COORDINATE_MEDIAN = "coordinate_median"
    TRIMMED_MEAN = "trimmed_mean"
    BYZANTINE_ROBUST = "byzantine_robust"

@dataclass
class AggregationResult:
    """Result of aggregation operation"""
    aggregated_weights: Dict[str, np.ndarray]
    method_used: AggregationMethod
    participants_used: List[str]
    participants_excluded: List[str]
    robustness_score: float
    computation_time: float

class ByzantineRobustAggregator:
    """Byzantine-robust aggregation for federated learning"""
    
    def __init__(self, max_byzantine_ratio: float = 0.3, min_participants: int = 3):
        self.max_byzantine_ratio = max_byzantine_ratio
        self.min_participants = min_participants
        self.aggregation_history = []
        
    def krum_aggregation(self, model_updates: Dict[str, Dict[str, np.ndarray]], 
                        f: int = None) -> AggregationResult:
        """
        Krum aggregation algorithm - selects the most similar model update
        
        Args:
            model_updates: Dictionary mapping participant IDs to their model updates
            f: Maximum number of Byzantine participants (if None, calculated from ratio)
        """
        start_time = time.time()
        
        if f is None:
            f = int(len(model_updates) * self.max_byzantine_ratio)
        
        if len(model_updates) < 2 * f + 3:
            raise ValueError(f"Not enough participants for Krum. Need at least {2 * f + 3}, got {len(model_updates)}")
        
        participants = list(model_updates.keys())
        scores = {}
        
        # Calculate Krum scores for each participant
        for i, participant_i in enumerate(participants):
            distances = []
            for j, participant_j in enumerate(participants):
                if i != j:
                    distance = self._calculate_distance(
                        model_updates[participant_i], 
                        model_updates[participant_j]
                    )
                    distances.append(distance)
            
            # Sort distances and take the closest n-f-2 participants
            distances.sort()
            krum_score = sum(distances[:len(participants) - f - 2])
            scores[participant_i] = krum_score
        
        # Select participant with minimum Krum score
        selected_participant = min(scores, key=scores.get)
        
        # Aggregate using only the selected participant
        aggregated_weights = model_updates[selected_participant].copy()
        
        computation_time = time.time() - start_time
        
        return AggregationResult(
            aggregated_weights=aggregated_weights,
            method_used=AggregationMethod.KRUM,
            participants_used=[selected_participant],
            participants_excluded=[p for p in participants if p != selected_participant],
            robustness_score=self._calculate_robustness_score(scores),
            computation_time=computation_time
        )
    
    def bulyan_aggregation(self, model_updates: Dict[str, Dict[str, np.ndarray]], 
                          f: int = None) -> AggregationResult:
        """
        Bulyan aggregation algorithm - combines Krum with coordinate-wise median
        
        Args:
            model_updates: Dictionary mapping participant IDs to their model updates
            f: Maximum number of Byzantine participants
        """
        start_time = time.time()
        
        if f is None:
            f = int(len(model_updates) * self.max_byzantine_ratio)
        
        if len(model_updates) < 4 * f + 3:
            raise ValueError(f"Not enough participants for Bulyan. Need at least {4 * f + 3}, got {len(model_updates)}")
        
        # Step 1: Use Krum to select n-2f participants
        n = len(model_updates)
        krum_f = n - 2 * f - 2
        
        # Run Krum multiple times to select multiple participants
        selected_participants = []
        remaining_updates = model_updates.copy()
        
        for _ in range(n - 2 * f):
            if len(remaining_updates) < 2 * krum_f + 3:
                break
            
            krum_result = self.krum_aggregation(remaining_updates, krum_f)
            selected_participant = krum_result.participants_used[0]
            selected_participants.append(selected_participant)
            del remaining_updates[selected_participant]
        
        # Step 2: Use coordinate-wise median on selected participants
        selected_updates = {p: model_updates[p] for p in selected_participants}
        aggregated_weights = self._coordinate_wise_median(selected_updates)
        
        computation_time = time.time() - start_time
        
        return AggregationResult(
            aggregated_weights=aggregated_weights,
            method_used=AggregationMethod.BULYAN,
            participants_used=selected_participants,
            participants_excluded=[p for p in model_updates.keys() if p not in selected_participants],
            robustness_score=self._calculate_robustness_score({p: 0 for p in selected_participants}),
            computation_time=computation_time
        )
    
    def coordinate_wise_median(self, model_updates: Dict[str, Dict[str, np.ndarray]]) -> AggregationResult:
        """
        Coordinate-wise median aggregation - robust to outliers
        
        Args:
            model_updates: Dictionary mapping participant IDs to their model updates
        """
        start_time = time.time()
        
        if len(model_updates) < self.min_participants:
            raise ValueError(f"Not enough participants for median aggregation. Need at least {self.min_participants}")
        
        aggregated_weights = self._coordinate_wise_median(model_updates)
        
        computation_time = time.time() - start_time
        
        return AggregationResult(
            aggregated_weights=aggregated_weights,
            method_used=AggregationMethod.COORDINATE_MEDIAN,
            participants_used=list(model_updates.keys()),
            participants_excluded=[],
            robustness_score=0.8,  # Median is generally robust
            computation_time=computation_time
        )
    
    def trimmed_mean_aggregation(self, model_updates: Dict[str, Dict[str, np.ndarray]], 
                               trim_ratio: float = 0.1) -> AggregationResult:
        """
        Trimmed mean aggregation - removes outliers and averages
        
        Args:
            model_updates: Dictionary mapping participant IDs to their model updates
            trim_ratio: Fraction of participants to trim from each end
        """
        start_time = time.time()
        
        if len(model_updates) < self.min_participants:
            raise ValueError(f"Not enough participants for trimmed mean. Need at least {self.min_participants}")
        
        participants = list(model_updates.keys())
        n_trim = int(len(participants) * trim_ratio)
        
        # Get layer names
        layer_names = list(model_updates[participants[0]].keys())
        aggregated_weights = {}
        
        for layer_name in layer_names:
            # Collect all weights for this layer
            layer_weights = []
            for participant in participants:
                layer_weights.append(model_updates[participant][layer_name])
            
            # Trim and average
            trimmed_weights = self._trim_and_average(layer_weights, n_trim)
            aggregated_weights[layer_name] = trimmed_weights
        
        computation_time = time.time() - start_time
        
        return AggregationResult(
            aggregated_weights=aggregated_weights,
            method_used=AggregationMethod.TRIMMED_MEAN,
            participants_used=participants,
            participants_excluded=[],
            robustness_score=0.7,
            computation_time=computation_time
        )
    
    def adaptive_byzantine_robust_aggregation(self, model_updates: Dict[str, Dict[str, np.ndarray]], 
                                           participant_reputation: Dict[str, float] = None) -> AggregationResult:
        """
        Adaptive Byzantine-robust aggregation that combines multiple methods
        
        Args:
            model_updates: Dictionary mapping participant IDs to their model updates
            participant_reputation: Optional reputation scores for participants
        """
        start_time = time.time()
        
        if len(model_updates) < self.min_participants:
            raise ValueError(f"Not enough participants for adaptive aggregation. Need at least {self.min_participants}")
        
        # Detect potential Byzantine participants
        byzantine_participants = self._detect_byzantine_participants(model_updates, participant_reputation)
        
        # Filter out Byzantine participants
        clean_updates = {p: model_updates[p] for p in model_updates.keys() 
                        if p not in byzantine_participants}
        
        if len(clean_updates) < self.min_participants:
            # Fall back to robust method if too many participants are filtered
            logger.warning("Too many participants filtered as Byzantine, using coordinate-wise median")
            return self.coordinate_wise_median(model_updates)
        
        # Use appropriate aggregation method based on remaining participants
        if len(clean_updates) >= 4 * int(len(model_updates) * self.max_byzantine_ratio) + 3:
            # Use Bulyan if we have enough participants
            result = self.bulyan_aggregation(clean_updates)
        elif len(clean_updates) >= 2 * int(len(model_updates) * self.max_byzantine_ratio) + 3:
            # Use Krum if we have moderate number of participants
            result = self.krum_aggregation(clean_updates)
        else:
            # Use coordinate-wise median as fallback
            result = self.coordinate_wise_median(clean_updates)
        
        # Update excluded participants
        result.participants_excluded.extend(byzantine_participants)
        result.computation_time = time.time() - start_time
        
        return result
    
    def _calculate_distance(self, model1: Dict[str, np.ndarray], model2: Dict[str, np.ndarray]) -> float:
        """Calculate Euclidean distance between two models"""
        total_distance = 0.0
        
        for layer_name in model1.keys():
            if layer_name in model2:
                diff = model1[layer_name] - model2[layer_name]
                total_distance += np.sum(diff ** 2)
        
        return np.sqrt(total_distance)
    
    def _coordinate_wise_median(self, model_updates: Dict[str, Dict[str, np.ndarray]]) -> Dict[str, np.ndarray]:
        """Calculate coordinate-wise median of model updates"""
        participants = list(model_updates.keys())
        layer_names = list(model_updates[participants[0]].keys())
        aggregated_weights = {}
        
        for layer_name in layer_names:
            # Collect all weights for this layer
            layer_weights = np.array([model_updates[p][layer_name] for p in participants])
            
            # Calculate median along the first axis (across participants)
            median_weights = np.median(layer_weights, axis=0)
            aggregated_weights[layer_name] = median_weights
        
        return aggregated_weights
    
    def _trim_and_average(self, weights_list: List[np.ndarray], n_trim: int) -> np.ndarray:
        """Trim outliers and average the remaining weights"""
        if n_trim == 0:
            return np.mean(weights_list, axis=0)
        
        # Calculate norms for trimming
        norms = [np.linalg.norm(w) for w in weights_list]
        
        # Sort by norm
        sorted_indices = np.argsort(norms)
        
        # Trim from both ends
        trimmed_indices = sorted_indices[n_trim:-n_trim] if n_trim > 0 else sorted_indices
        
        # Average trimmed weights
        trimmed_weights = [weights_list[i] for i in trimmed_indices]
        return np.mean(trimmed_weights, axis=0)
    
    def _detect_byzantine_participants(self, model_updates: Dict[str, Dict[str, np.ndarray]], 
                                     participant_reputation: Dict[str, float] = None) -> List[str]:
        """Detect potential Byzantine participants using clustering"""
        participants = list(model_updates.keys())
        
        if len(participants) < 3:
            return []
        
        # Calculate pairwise distances
        distances = np.zeros((len(participants), len(participants)))
        for i, p1 in enumerate(participants):
            for j, p2 in enumerate(participants):
                if i != j:
                    distances[i][j] = self._calculate_distance(
                        model_updates[p1], model_updates[p2]
                    )
        
        # Use DBSCAN clustering to detect outliers
        clustering = DBSCAN(eps=np.percentile(distances, 75), min_samples=2)
        cluster_labels = clustering.fit_predict(distances)
        
        # Identify outliers (label -1)
        byzantine_participants = [participants[i] for i, label in enumerate(cluster_labels) if label == -1]
        
        # Additional reputation-based filtering
        if participant_reputation:
            low_reputation_threshold = np.percentile(list(participant_reputation.values()), 20)
            low_reputation_participants = [p for p, rep in participant_reputation.items() 
                                         if rep < low_reputation_threshold]
            byzantine_participants.extend(low_reputation_participants)
        
        return list(set(byzantine_participants))
    
    def _calculate_robustness_score(self, scores: Dict[str, float]) -> float:
        """Calculate robustness score based on aggregation method"""
        if not scores:
            return 0.0
        
        # Normalize scores to 0-1 range
        max_score = max(scores.values()) if scores.values() else 1.0
        min_score = min(scores.values()) if scores.values() else 0.0
        
        if max_score == min_score:
            return 1.0
        
        # Calculate coefficient of variation (lower is better)
        mean_score = np.mean(list(scores.values()))
        std_score = np.std(list(scores.values()))
        
        if mean_score == 0:
            return 0.0
        
        cv = std_score / mean_score
        robustness_score = max(0.0, 1.0 - cv)
        
        return robustness_score

class ByzantineRobustFederatedLearning:
    """Byzantine-robust federated learning coordinator"""
    
    def __init__(self, max_byzantine_ratio: float = 0.3):
        self.aggregator = ByzantineRobustAggregator(max_byzantine_ratio)
        self.participant_reputation = {}
        self.aggregation_history = []
        
    async def conduct_robust_round(self, model_updates: Dict[str, Dict[str, np.ndarray]], 
                                 method: AggregationMethod = AggregationMethod.ADAPTIVE) -> AggregationResult:
        """Conduct a Byzantine-robust federated learning round"""
        
        logger.info(f"Starting robust aggregation round with {len(model_updates)} participants")
        
        # Select aggregation method
        if method == AggregationMethod.KRUM:
            result = self.aggregator.krum_aggregation(model_updates)
        elif method == AggregationMethod.BULYAN:
            result = self.aggregator.bulyan_aggregation(model_updates)
        elif method == AggregationMethod.COORDINATE_MEDIAN:
            result = self.aggregator.coordinate_wise_median(model_updates)
        elif method == AggregationMethod.TRIMMED_MEAN:
            result = self.aggregator.trimmed_mean_aggregation(model_updates)
        elif method == AggregationMethod.ADAPTIVE:
            result = self.aggregator.adaptive_byzantine_robust_aggregation(
                model_updates, self.participant_reputation
            )
        else:
            raise ValueError(f"Unknown aggregation method: {method}")
        
        # Update participant reputation based on inclusion
        self._update_reputation(result)
        
        # Store aggregation history
        self.aggregation_history.append(result)
        
        logger.info(f"Aggregation completed using {result.method_used.value}")
        logger.info(f"Participants used: {len(result.participants_used)}")
        logger.info(f"Participants excluded: {len(result.participants_excluded)}")
        logger.info(f"Robustness score: {result.robustness_score:.3f}")
        
        return result
    
    def _update_reputation(self, result: AggregationResult):
        """Update participant reputation based on aggregation results"""
        for participant in result.participants_used:
            if participant not in self.participant_reputation:
                self.participant_reputation[participant] = 0.5
            else:
                # Increase reputation for participants included in aggregation
                self.participant_reputation[participant] = min(1.0, 
                    self.participant_reputation[participant] + 0.1)
        
        for participant in result.participants_excluded:
            if participant not in self.participant_reputation:
                self.participant_reputation[participant] = 0.3
            else:
                # Decrease reputation for participants excluded from aggregation
                self.participant_reputation[participant] = max(0.0, 
                    self.participant_reputation[participant] - 0.1)
    
    def get_participant_reputation(self) -> Dict[str, float]:
        """Get current participant reputation scores"""
        return self.participant_reputation.copy()
    
    def get_aggregation_statistics(self) -> Dict[str, Any]:
        """Get statistics about aggregation history"""
        if not self.aggregation_history:
            return {}
        
        methods_used = [result.method_used.value for result in self.aggregation_history]
        robustness_scores = [result.robustness_score for result in self.aggregation_history]
        computation_times = [result.computation_time for result in self.aggregation_history]
        
        return {
            'total_rounds': len(self.aggregation_history),
            'methods_used': methods_used,
            'average_robustness_score': np.mean(robustness_scores),
            'average_computation_time': np.mean(computation_times),
            'participant_reputation': self.participant_reputation
        }

# Example usage and testing
async def main():
    """Example usage of Byzantine-robust aggregation"""
    
    # Initialize Byzantine-robust federated learning
    robust_fl = ByzantineRobustFederatedLearning(max_byzantine_ratio=0.3)
    
    # Create sample model updates (some with Byzantine behavior)
    model_updates = {}
    participants = [f"participant_{i}" for i in range(10)]
    
    for i, participant in enumerate(participants):
        # Create normal model updates
        if i < 7:  # 7 normal participants
            model_updates[participant] = {
                'layer1': np.random.randn(100, 50) * 0.1,
                'layer2': np.random.randn(50, 10) * 0.1
            }
        else:  # 3 Byzantine participants with malicious updates
            model_updates[participant] = {
                'layer1': np.random.randn(100, 50) * 10.0,  # Large malicious updates
                'layer2': np.random.randn(50, 10) * 10.0
            }
    
    # Test different aggregation methods
    methods = [
        AggregationMethod.KRUM,
        AggregationMethod.BULYAN,
        AggregationMethod.COORDINATE_MEDIAN,
        AggregationMethod.TRIMMED_MEAN,
        AggregationMethod.ADAPTIVE
    ]
    
    for method in methods:
        print(f"\nTesting {method.value} aggregation:")
        try:
            result = await robust_fl.conduct_robust_round(model_updates, method)
            print(f"  Participants used: {len(result.participants_used)}")
            print(f"  Participants excluded: {len(result.participants_excluded)}")
            print(f"  Robustness score: {result.robustness_score:.3f}")
            print(f"  Computation time: {result.computation_time:.3f}s")
        except Exception as e:
            print(f"  Error: {e}")
    
    # Get final statistics
    stats = robust_fl.get_aggregation_statistics()
    print(f"\nFinal statistics: {stats}")

if __name__ == "__main__":
    asyncio.run(main())
