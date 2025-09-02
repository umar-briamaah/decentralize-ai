// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./DAIToken.sol";

/**
 * @title Staking
 * @dev Staking contract for validators and contributors
 * 
 * Features:
 * - Validator staking with slashing protection
 * - Contributor staking for quality assurance
 * - Reward distribution based on performance
 * - Emergency pause functionality
 * - Insurance pool for slashing protection
 */
contract Staking is ReentrancyGuard, Ownable, Pausable {
    

    
    // Staking types
    enum StakingType {
        VALIDATOR,
        CONTRIBUTOR_AI_TRAINING,
        CONTRIBUTOR_DATA_PROVISION,
        CONTRIBUTOR_COMPUTATIONAL,
        CONTRIBUTOR_RESEARCH
    }
    
    // Staking position
    struct StakingPosition {
        StakingType stakingType;
        uint256 amount;
        uint256 startTime;
        uint256 lockPeriod;
        bool isActive;
        uint256 rewardsEarned;
        uint256 lastRewardTime;
        uint256 performanceScore;
    }
    
    // Validator specific data
    struct ValidatorInfo {
        string nodeId;
        string ipAddress;
        uint256 uptime;
        uint256 totalBlocks;
        uint256 missedBlocks;
        bool isActive;
        uint256 slashingRisk;
    }
    
    // Constants
    uint256 public constant MIN_VALIDATOR_STAKE = 10_000 * 10**18; // 10,000 DAI
    uint256 public constant MIN_CONTRIBUTOR_STAKE = 1_000 * 10**18; // 1,000 DAI
    uint256 public constant MAX_VALIDATORS = 100;
    uint256 public constant REWARD_RATE = 5; // 5% base APY
    uint256 public constant PERFORMANCE_BONUS_RATE = 10; // 10% max bonus
    uint256 public constant SLASHING_PENALTY = 5; // 5% penalty for slashing
    
    // State variables
    DAIToken public daiToken;
    uint256 public totalStaked;
    uint256 public totalValidators;
    uint256 public insurancePool;
    uint256 public totalRewardsDistributed;
    
    // Mappings
    mapping(address => StakingPosition) public stakingPositions;
    mapping(address => ValidatorInfo) public validatorInfo;
    mapping(address => uint256) public pendingRewards;
    mapping(address => uint256) public slashingHistory;
    mapping(StakingType => uint256) public stakingRewards;
    
    // Arrays
    address[] public validators;
    address[] public contributors;
    
    // Events
    event Staked(address indexed user, StakingType stakingType, uint256 amount, uint256 lockPeriod);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 amount);
    event ValidatorRegistered(address indexed validator, string nodeId, string ipAddress);
    event ValidatorSlashed(address indexed validator, uint256 amount, string reason);
    event InsurancePoolDeposited(uint256 amount);
    event InsurancePoolWithdrawn(uint256 amount);
    event PerformanceUpdated(address indexed user, uint256 newScore);
    
    constructor(address _daiToken) Ownable(msg.sender) {
        daiToken = DAIToken(_daiToken);
        
        // Initialize staking rewards for each type
        stakingRewards[StakingType.VALIDATOR] = 5; // 5% APY
        stakingRewards[StakingType.CONTRIBUTOR_AI_TRAINING] = 8; // 8% APY
        stakingRewards[StakingType.CONTRIBUTOR_DATA_PROVISION] = 6; // 6% APY
        stakingRewards[StakingType.CONTRIBUTOR_COMPUTATIONAL] = 7; // 7% APY
        stakingRewards[StakingType.CONTRIBUTOR_RESEARCH] = 10; // 10% APY
    }
    
    /**
     * @dev Stake tokens for validator role
     * @param amount Amount of tokens to stake
     * @param nodeId Node identifier
     * @param ipAddress IP address of the node
     * @param lockPeriod Lock period in seconds
     */
    function stakeAsValidator(
        uint256 amount,
        string memory nodeId,
        string memory ipAddress,
        uint256 lockPeriod
    ) external whenNotPaused nonReentrant {
        require(amount >= MIN_VALIDATOR_STAKE, "Staking: Insufficient stake amount");
        require(totalValidators < MAX_VALIDATORS, "Staking: Maximum validators reached");
        require(!stakingPositions[msg.sender].isActive, "Staking: Already staked");
        require(lockPeriod >= 30 days, "Staking: Lock period too short");
        
        // Transfer tokens from user to contract
        daiToken.transferFrom(msg.sender, address(this), amount);
        
        // Create staking position
        stakingPositions[msg.sender] = StakingPosition({
            stakingType: StakingType.VALIDATOR,
            amount: amount,
            startTime: block.timestamp,
            lockPeriod: lockPeriod,
            isActive: true,
            rewardsEarned: 0,
            lastRewardTime: block.timestamp,
            performanceScore: 100 // Start with perfect score
        });
        
        // Set validator info
        validatorInfo[msg.sender] = ValidatorInfo({
            nodeId: nodeId,
            ipAddress: ipAddress,
            uptime: 100,
            totalBlocks: 0,
            missedBlocks: 0,
            isActive: true,
            slashingRisk: 0
        });
        
        // Update state
        totalStaked = totalStaked + amount;
        totalValidators = totalValidators + 1;
        validators.push(msg.sender);
        
        emit Staked(msg.sender, StakingType.VALIDATOR, amount, lockPeriod);
        emit ValidatorRegistered(msg.sender, nodeId, ipAddress);
    }
    
    /**
     * @dev Stake tokens for contributor role
     * @param stakingType Type of contribution
     * @param amount Amount of tokens to stake
     * @param lockPeriod Lock period in seconds
     */
    function stakeAsContributor(
        StakingType stakingType,
        uint256 amount,
        uint256 lockPeriod
    ) external whenNotPaused nonReentrant {
        require(stakingType != StakingType.VALIDATOR, "Staking: Use stakeAsValidator for validator staking");
        require(amount >= MIN_CONTRIBUTOR_STAKE, "Staking: Insufficient stake amount");
        require(!stakingPositions[msg.sender].isActive, "Staking: Already staked");
        require(lockPeriod >= 7 days, "Staking: Lock period too short");
        
        // Transfer tokens from user to contract
        daiToken.transferFrom(msg.sender, address(this), amount);
        
        // Create staking position
        stakingPositions[msg.sender] = StakingPosition({
            stakingType: stakingType,
            amount: amount,
            startTime: block.timestamp,
            lockPeriod: lockPeriod,
            isActive: true,
            rewardsEarned: 0,
            lastRewardTime: block.timestamp,
            performanceScore: 100
        });
        
        // Update state
        totalStaked = totalStaked + amount;
        contributors.push(msg.sender);
        
        emit Staked(msg.sender, stakingType, amount, lockPeriod);
    }
    
    /**
     * @dev Unstake tokens and claim rewards
     */
    function unstake() external whenNotPaused nonReentrant {
        StakingPosition storage position = stakingPositions[msg.sender];
        require(position.isActive, "Staking: No active position");
        require(
            block.timestamp >= position.startTime + position.lockPeriod,
            "Staking: Lock period not expired"
        );
        
        // Calculate rewards
        uint256 rewards = calculateRewards(msg.sender);
        uint256 totalAmount = position.amount + rewards;
        
        // Update state
        totalStaked = totalStaked - position.amount;
        totalRewardsDistributed = totalRewardsDistributed + rewards;
        
        // Handle validator specific logic
        if (position.stakingType == StakingType.VALIDATOR) {
            totalValidators = totalValidators - 1;
            validatorInfo[msg.sender].isActive = false;
            _removeValidator(msg.sender);
        } else {
            _removeContributor(msg.sender);
        }
        
        // Deactivate position
        position.isActive = false;
        position.rewardsEarned = position.rewardsEarned + rewards;
        
        // Transfer tokens back to user
        daiToken.transfer(msg.sender, totalAmount);
        
        emit Unstaked(msg.sender, position.amount, rewards);
    }
    
    /**
     * @dev Claim pending rewards without unstaking
     */
    function claimRewards() external whenNotPaused nonReentrant {
        StakingPosition storage position = stakingPositions[msg.sender];
        require(position.isActive, "Staking: No active position");
        
        uint256 rewards = calculateRewards(msg.sender);
        require(rewards > 0, "Staking: No rewards to claim");
        
        // Update position
        position.lastRewardTime = block.timestamp;
        position.rewardsEarned = position.rewardsEarned + rewards;
        
        // Update state
        totalRewardsDistributed = totalRewardsDistributed + rewards;
        
        // Transfer rewards
        daiToken.transfer(msg.sender, rewards);
        
        emit RewardsClaimed(msg.sender, rewards);
    }
    
    /**
     * @dev Calculate rewards for a staker
     * @param staker Address of the staker
     * @return rewards Calculated rewards
     */
    function calculateRewards(address staker) public view returns (uint256) {
        StakingPosition memory position = stakingPositions[staker];
        if (!position.isActive) return 0;
        
        uint256 timeElapsed = block.timestamp - position.lastRewardTime;
        uint256 baseReward = (position.amount * stakingRewards[position.stakingType] * timeElapsed) / (100 * 365 days);
        
        // Apply performance bonus
        uint256 performanceBonus = (baseReward * position.performanceScore) / 100;
        
        return baseReward + performanceBonus;
    }
    
    /**l
     * @dev Update validator performance
     * @param validator Address of the validator
     * @param uptime New uptime percentage
     * @param totalBlocks Total blocks produced
     * @param missedBlocks Missed blocks
     */
    function updateValidatorPerformance(
        address validator,
        uint256 uptime,
        uint256 totalBlocks,
        uint256 missedBlocks
    ) external onlyOwner {
        ValidatorInfo storage info = validatorInfo[validator];
        require(info.isActive, "Staking: Validator not active");
        
        info.uptime = uptime;
        info.totalBlocks = totalBlocks;
        info.missedBlocks = missedBlocks;
        
        // Calculate performance score
        uint256 performanceScore = 100;
        if (totalBlocks > 0) {
            uint256 missedPercentage = (missedBlocks * 100) / totalBlocks;
            performanceScore = performanceScore - missedPercentage;
        }
        
        // Update staking position
        stakingPositions[validator].performanceScore = performanceScore;
        
        emit PerformanceUpdated(validator, performanceScore);
    }
    
    /**
     * @dev Slash validator for malicious behavior
     * @param validator Address of the validator to slash
     * @param amount Amount to slash
     * @param reason Reason for slashing
     */
    function slashValidator(
        address validator,
        uint256 amount,
        string memory reason
    ) external onlyOwner {
        StakingPosition storage position = stakingPositions[validator];
        require(position.isActive, "Staking: Validator not active");
        require(position.stakingType == StakingType.VALIDATOR, "Staking: Not a validator");
        require(amount <= position.amount, "Staking: Slash amount exceeds stake");
        
        // Calculate slash amount
        uint256 slashAmount = (position.amount * SLASHING_PENALTY) / 100;
        if (slashAmount > amount) slashAmount = amount;
        
        // Update position
        position.amount = position.amount - slashAmount;
        position.performanceScore = position.performanceScore - 10; // Reduce performance score
        
        // Update state
        totalStaked = totalStaked - slashAmount;
        slashingHistory[validator] = slashingHistory[validator] + slashAmount;
        
        // Add to insurance pool
        insurancePool = insurancePool + slashAmount;
        
        emit ValidatorSlashed(validator, slashAmount, reason);
    }
    
    /**
     * @dev Deposit to insurance pool
     * @param amount Amount to deposit
     */
    function depositToInsurancePool(uint256 amount) external onlyOwner {
        daiToken.transferFrom(msg.sender, address(this), amount);
        insurancePool = insurancePool + amount;
        emit InsurancePoolDeposited(amount);
    }
    
    /**
     * @dev Withdraw from insurance pool
     * @param amount Amount to withdraw
     */
    function withdrawFromInsurancePool(uint256 amount) external onlyOwner {
        require(amount <= insurancePool, "Staking: Insufficient insurance pool");
        insurancePool = insurancePool - amount;
        daiToken.transfer(msg.sender, amount);
        emit InsurancePoolWithdrawn(amount);
    }
    
    /**
     * @dev Get validator list
     * @return Array of validator addresses
     */
    function getValidators() external view returns (address[] memory) {
        return validators;
    }
    
    /**
     * @dev Get contributor list
     * @return Array of contributor addresses
     */
    function getContributors() external view returns (address[] memory) {
        return contributors;
    }
    
    /**
     * @dev Get staking statistics
     * @return totalStaked Total amount staked
     * @return totalValidators Total number of validators
     * @return totalRewardsDistributed Total rewards distributed
     * @return insurancePool Insurance pool balance
     */
    function getStakingStats() external view returns (
        uint256 totalStaked,
        uint256 totalValidators,
        uint256 totalRewardsDistributed,
        uint256 insurancePool
    ) {
        return (
            totalStaked,
            totalValidators,
            totalRewardsDistributed,
            insurancePool
        );
    }
    
    /**
     * @dev Check if address has active staking position
     */
    function hasActiveStaking(address account) external view returns (bool) {
        return stakingPositions[account].isActive;
    }
    
    /**
     * @dev Remove validator from array
     * @param validator Address of validator to remove
     */
    function _removeValidator(address validator) internal {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == validator) {
                validators[i] = validators[validators.length - 1];
                validators.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Remove contributor from array
     * @param contributor Address of contributor to remove
     */
    function _removeContributor(address contributor) internal {
        for (uint256 i = 0; i < contributors.length; i++) {
            if (contributors[i] == contributor) {
                contributors[i] = contributors[contributors.length - 1];
                contributors.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
