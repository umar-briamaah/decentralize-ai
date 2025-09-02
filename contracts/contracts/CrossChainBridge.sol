// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./DAIToken.sol";

/**
 * @title CrossChainBridge
 * @dev Cross-chain bridge for Decentralize AI tokens and governance
 * 
 * Features:
 * - Multi-chain token transfers
 * - Cross-chain governance synchronization
 * - Bridge security and validation
 * - Support for Polygon and Arbitrum
 * - Automated bridge operations
 */
contract CrossChainBridge is ReentrancyGuard, Ownable, Pausable {
    

    
    // Supported chains
    enum Chain {
        ETHEREUM,
        POLYGON,
        ARBITRUM,
        OPTIMISM
    }
    
    // Bridge operation types
    enum OperationType {
        TOKEN_TRANSFER,
        GOVERNANCE_SYNC,
        STAKE_TRANSFER,
        REWARD_DISTRIBUTION
    }
    
    // Bridge transaction
    struct BridgeTransaction {
        uint256 transactionId;
        address user;
        Chain sourceChain;
        Chain targetChain;
        OperationType operationType;
        uint256 amount;
        bytes data;
        uint256 timestamp;
        bool isProcessed;
        bool isValid;
    }
    
    // Chain configuration
    struct ChainConfig {
        bool isSupported;
        address bridgeContract;
        uint256 chainId;
        uint256 minTransferAmount;
        uint256 maxTransferAmount;
        uint256 bridgeFee;
        bool isActive;
    }
    
    // Constants
    uint256 public constant MIN_BRIDGE_AMOUNT = 1 * 10**18; // 1 DAI
    uint256 public constant MAX_BRIDGE_AMOUNT = 1000000 * 10**18; // 1M DAI
    uint256 public constant BRIDGE_FEE_PERCENTAGE = 1; // 1%
    uint256 public constant BRIDGE_TIMEOUT = 24 hours;
    
    // State variables
    DAIToken public daiToken;
    uint256 public totalTransactions;
    uint256 public totalBridgedAmount;
    uint256 public totalBridgeFees;
    
    // Mappings
    mapping(uint256 => BridgeTransaction) public bridgeTransactions;
    mapping(Chain => ChainConfig) public chainConfigs;
    mapping(address => uint256[]) public userTransactions;
    mapping(bytes32 => bool) public processedHashes;
    mapping(address => bool) public bridgeValidators;
    
    // Arrays
    address[] public validators;
    
    // Events
    event BridgeTransactionInitiated(
        uint256 indexed transactionId,
        address indexed user,
        Chain sourceChain,
        Chain targetChain,
        OperationType operationType,
        uint256 amount
    );
    event BridgeTransactionProcessed(
        uint256 indexed transactionId,
        address indexed user,
        bool success
    );
    event ChainConfigUpdated(Chain chain, address bridgeContract, uint256 chainId);
    event BridgeValidatorAdded(address indexed validator);
    event BridgeValidatorRemoved(address indexed validator);
    event BridgeFeeUpdated(uint256 newFeePercentage);
    
    constructor(address _daiToken) Ownable(msg.sender) {
        daiToken = DAIToken(_daiToken);
        
        // Initialize chain configurations
        _initializeChainConfigs();
    }
    
    /**
     * @dev Initialize chain configurations
     */
    function _initializeChainConfigs() internal {
        // Ethereum mainnet
        chainConfigs[Chain.ETHEREUM] = ChainConfig({
            isSupported: true,
            bridgeContract: address(this),
            chainId: 1,
            minTransferAmount: MIN_BRIDGE_AMOUNT,
            maxTransferAmount: MAX_BRIDGE_AMOUNT,
            bridgeFee: BRIDGE_FEE_PERCENTAGE,
            isActive: true
        });
        
        // Polygon
        chainConfigs[Chain.POLYGON] = ChainConfig({
            isSupported: true,
            bridgeContract: address(0), // To be set
            chainId: 137,
            minTransferAmount: MIN_BRIDGE_AMOUNT,
            maxTransferAmount: MAX_BRIDGE_AMOUNT,
            bridgeFee: BRIDGE_FEE_PERCENTAGE,
            isActive: true
        });
        
        // Arbitrum
        chainConfigs[Chain.ARBITRUM] = ChainConfig({
            isSupported: true,
            bridgeContract: address(0), // To be set
            chainId: 42161,
            minTransferAmount: MIN_BRIDGE_AMOUNT,
            maxTransferAmount: MAX_BRIDGE_AMOUNT,
            bridgeFee: BRIDGE_FEE_PERCENTAGE,
            isActive: true
        });
        
        // Optimism
        chainConfigs[Chain.OPTIMISM] = ChainConfig({
            isSupported: true,
            bridgeContract: address(0), // To be set
            chainId: 10,
            minTransferAmount: MIN_BRIDGE_AMOUNT,
            maxTransferAmount: MAX_BRIDGE_AMOUNT,
            bridgeFee: BRIDGE_FEE_PERCENTAGE,
            isActive: true
        });
    }
    
    /**
     * @dev Initiate cross-chain token transfer
     * @param targetChain Target chain for the transfer
     * @param amount Amount of tokens to transfer
     * @param recipient Recipient address on target chain
     */
    function initiateTokenTransfer(
        Chain targetChain,
        uint256 amount,
        address recipient
    ) external whenNotPaused nonReentrant {
        require(chainConfigs[targetChain].isSupported, "CrossChainBridge: Chain not supported");
        require(chainConfigs[targetChain].isActive, "CrossChainBridge: Chain not active");
        require(amount >= chainConfigs[targetChain].minTransferAmount, "CrossChainBridge: Amount too low");
        require(amount <= chainConfigs[targetChain].maxTransferAmount, "CrossChainBridge: Amount too high");
        require(recipient != address(0), "CrossChainBridge: Invalid recipient");
        
        // Calculate bridge fee
        uint256 bridgeFee = (amount * chainConfigs[targetChain].bridgeFee) / 100;
        uint256 transferAmount = amount - bridgeFee;
        
        // Transfer tokens from user to bridge
        daiToken.transferFrom(msg.sender, address(this), amount);
        
        // Create bridge transaction
        uint256 transactionId = totalTransactions;
        BridgeTransaction storage transaction = bridgeTransactions[transactionId];
        
        transaction.transactionId = transactionId;
        transaction.user = msg.sender;
        transaction.sourceChain = Chain.ETHEREUM;
        transaction.targetChain = targetChain;
        transaction.operationType = OperationType.TOKEN_TRANSFER;
        transaction.amount = transferAmount;
        transaction.data = abi.encode(recipient);
        transaction.timestamp = block.timestamp;
        transaction.isProcessed = false;
        transaction.isValid = true;
        
        // Update state
        totalTransactions = totalTransactions + 1;
        totalBridgedAmount = totalBridgedAmount + transferAmount;
        totalBridgeFees = totalBridgeFees + bridgeFee;
        
        // Add to user transactions
        userTransactions[msg.sender].push(transactionId);
        
        emit BridgeTransactionInitiated(
            transactionId,
            msg.sender,
            Chain.ETHEREUM,
            targetChain,
            OperationType.TOKEN_TRANSFER,
            transferAmount
        );
    }
    
    /**
     * @dev Process bridge transaction (called by validators)
     * @param transactionId ID of the transaction to process
     * @param success Whether the transaction was successful on target chain
     */
    function processBridgeTransaction(
        uint256 transactionId,
        bool success
    ) external whenNotPaused nonReentrant {
        require(bridgeValidators[msg.sender], "CrossChainBridge: Not a validator");
        require(transactionId < totalTransactions, "CrossChainBridge: Invalid transaction ID");
        
        BridgeTransaction storage transaction = bridgeTransactions[transactionId];
        require(!transaction.isProcessed, "CrossChainBridge: Transaction already processed");
        require(block.timestamp <= transaction.timestamp + BRIDGE_TIMEOUT, "CrossChainBridge: Transaction timeout");
        
        transaction.isProcessed = true;
        
        if (success) {
            // Transaction successful on target chain
            transaction.isValid = true;
        } else {
            // Transaction failed, refund user
            transaction.isValid = false;
            _refundTransaction(transaction);
        }
        
        emit BridgeTransactionProcessed(transactionId, transaction.user, success);
    }
    
    /**
     * @dev Refund failed transaction
     * @param transaction Bridge transaction to refund
     */
    function _refundTransaction(BridgeTransaction storage transaction) internal {
        // Calculate refund amount (including bridge fee)
        uint256 refundAmount = transaction.amount;
        uint256 bridgeFee = (refundAmount * chainConfigs[transaction.targetChain].bridgeFee) / 100;
        refundAmount = refundAmount + bridgeFee;
        
        // Transfer tokens back to user
        daiToken.transfer(transaction.user, refundAmount);
        
        // Update state
        totalBridgedAmount = totalBridgedAmount - transaction.amount;
        totalBridgeFees = totalBridgeFees - bridgeFee;
    }
    
    /**
     * @dev Sync governance across chains
     * @param targetChain Target chain for governance sync
     * @param proposalData Encoded proposal data
     */
    function syncGovernance(
        Chain targetChain,
        bytes memory proposalData
    ) external whenNotPaused nonReentrant {
        require(chainConfigs[targetChain].isSupported, "CrossChainBridge: Chain not supported");
        require(chainConfigs[targetChain].isActive, "CrossChainBridge: Chain not active");
        
        // Create bridge transaction for governance sync
        uint256 transactionId = totalTransactions;
        BridgeTransaction storage transaction = bridgeTransactions[transactionId];
        
        transaction.transactionId = transactionId;
        transaction.user = msg.sender;
        transaction.sourceChain = Chain.ETHEREUM;
        transaction.targetChain = targetChain;
        transaction.operationType = OperationType.GOVERNANCE_SYNC;
        transaction.amount = 0;
        transaction.data = proposalData;
        transaction.timestamp = block.timestamp;
        transaction.isProcessed = false;
        transaction.isValid = true;
        
        totalTransactions = totalTransactions + 1;
        userTransactions[msg.sender].push(transactionId);
        
        emit BridgeTransactionInitiated(
            transactionId,
            msg.sender,
            Chain.ETHEREUM,
            targetChain,
            OperationType.GOVERNANCE_SYNC,
            0
        );
    }
    
    /**
     * @dev Update chain configuration
     * @param chain Chain to update
     * @param bridgeContract Bridge contract address on target chain
     * @param chainId Chain ID
     */
    function updateChainConfig(
        Chain chain,
        address bridgeContract,
        uint256 chainId
    ) external onlyOwner {
        require(chainConfigs[chain].isSupported, "CrossChainBridge: Chain not supported");
        
        chainConfigs[chain].bridgeContract = bridgeContract;
        chainConfigs[chain].chainId = chainId;
        
        emit ChainConfigUpdated(chain, bridgeContract, chainId);
    }
    
    /**
     * @dev Add bridge validator
     * @param validator Address of the validator
     */
    function addBridgeValidator(address validator) external onlyOwner {
        require(!bridgeValidators[validator], "CrossChainBridge: Already a validator");
        
        bridgeValidators[validator] = true;
        validators.push(validator);
        
        emit BridgeValidatorAdded(validator);
    }
    
    /**
     * @dev Remove bridge validator
     * @param validator Address of the validator
     */
    function removeBridgeValidator(address validator) external onlyOwner {
        require(bridgeValidators[validator], "CrossChainBridge: Not a validator");
        
        bridgeValidators[validator] = false;
        
        // Remove from validators array
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == validator) {
                validators[i] = validators[validators.length - 1];
                validators.pop();
                break;
            }
        }
        
        emit BridgeValidatorRemoved(validator);
    }
    
    /**
     * @dev Update bridge fee percentage
     * @param newFeePercentage New fee percentage
     */
    function updateBridgeFee(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 10, "CrossChainBridge: Fee too high");
        
        // Update fee for all chains
        for (uint256 i = 0; i < 4; i++) {
            chainConfigs[Chain(i)].bridgeFee = newFeePercentage;
        }
        
        emit BridgeFeeUpdated(newFeePercentage);
    }
    
    /**
     * @dev Get bridge transaction details
     * @param transactionId ID of the transaction
     */
    function getBridgeTransaction(uint256 transactionId) external view returns (
        uint256 id,
        address user,
        Chain sourceChain,
        Chain targetChain,
        OperationType operationType,
        uint256 amount,
        bytes memory data,
        uint256 timestamp,
        bool isProcessed,
        bool isValid
    ) {
        BridgeTransaction storage transaction = bridgeTransactions[transactionId];
        return (
            transaction.transactionId,
            transaction.user,
            transaction.sourceChain,
            transaction.targetChain,
            transaction.operationType,
            transaction.amount,
            transaction.data,
            transaction.timestamp,
            transaction.isProcessed,
            transaction.isValid
        );
    }
    
    /**
     * @dev Get user transactions
     * @param user Address of the user
     */
    function getUserTransactions(address user) external view returns (uint256[] memory) {
        return userTransactions[user];
    }
    
    /**
     * @dev Get bridge statistics
     */
    function getBridgeStats() external view returns (
        uint256 totalTransactions,
        uint256 totalBridgedAmount,
        uint256 totalBridgeFees,
        uint256 validatorsCount
    ) {
        return (
            totalTransactions,
            totalBridgedAmount,
            totalBridgeFees,
            validators.length
        );
    }
    
    /**
     * @dev Get chain configuration
     * @param chain Chain to get configuration for
     */
    function getChainConfig(Chain chain) external view returns (
        bool isSupported,
        address bridgeContract,
        uint256 chainId,
        uint256 minTransferAmount,
        uint256 maxTransferAmount,
        uint256 bridgeFee,
        bool isActive
    ) {
        ChainConfig storage config = chainConfigs[chain];
        return (
            config.isSupported,
            config.bridgeContract,
            config.chainId,
            config.minTransferAmount,
            config.maxTransferAmount,
            config.bridgeFee,
            config.isActive
        );
    }
    
    /**
     * @dev Pause bridge operations
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause bridge operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
