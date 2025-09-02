// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./DAIToken.sol";
import "./Staking.sol";

/**
 * @title ContributionSystem
 * @dev Anonymous proof-of-contribution scoring system
 * 
 * Features:
 * - Anonymous contribution verification
 * - Merit-based scoring algorithm
 * - Quality assessment mechanisms
 * - Reward distribution based on contribution value
 * - Zero-knowledge proof integration
 */
contract ContributionSystem is ReentrancyGuard, Ownable, Pausable {
    
    // Contribution types
    enum ContributionType {
        AI_TRAINING,
        DATA_PROVISION,
        COMPUTATIONAL_RESOURCES,
        RESEARCH_DEVELOPMENT,
        GOVERNANCE_PARTICIPATION
    }
    
    // Contribution status
    enum ContributionStatus {
        PENDING,
        UNDER_REVIEW,
        APPROVED,
        REJECTED,
        REWARDED
    }
    
    // Contribution structure
    struct Contribution {
        uint256 id;
        address contributor;
        ContributionType contributionType;
        string description;
        string proofHash; // IPFS hash of proof
        uint256 value; // Contribution value in DAI
        uint256 qualityScore; // 0-100 quality score
        uint256 impactScore; // 0-100 impact score
        ContributionStatus status;
        uint256 submissionTime;
        uint256 reviewTime;
        uint256 rewardAmount;
        address[] reviewers;
    }
    
    // Contributor profile
    struct ContributorProfile {
        uint256 totalContributions;
        uint256 totalRewards;
        uint256 reputationScore;
        uint256 lastContributionTime;
        bool isActive;
        string[] contributionCategories;
    }
    
    // Review criteria
    struct ReviewCriteria {
        uint256 technicalQuality; // 0-100
        uint256 innovation; // 0-100
        uint256 impact; // 0-100
        uint256 documentation; // 0-100
        uint256 communityBenefit; // 0-100
    }
    
    // Constants
    uint256 public constant MIN_CONTRIBUTION_VALUE = 100 * 10**18; // 100 DAI
    uint256 public constant MAX_CONTRIBUTION_VALUE = 100_000 * 10**18; // 100,000 DAI
    uint256 public constant MIN_REVIEWERS = 3;
    uint256 public constant MAX_REVIEWERS = 7;
    uint256 public constant REVIEW_PERIOD = 7 days;
    uint256 public constant REWARD_MULTIPLIER = 2; // 2x contribution value as reward
    
    // State variables
    DAIToken public daiToken;
    Staking public stakingContract;
    uint256 public totalContributions;
    uint256 public totalRewardsDistributed;
    uint256 public activeReviewers;
    
    // Mappings
    mapping(uint256 => Contribution) public contributions;
    mapping(address => ContributorProfile) public contributorProfiles;
    mapping(address => bool) public isReviewer;
    mapping(address => uint256) public reviewerReputation;
    mapping(ContributionType => uint256) public contributionRewards;
    mapping(address => uint256[]) public contributorContributions;
    
    // Separate mappings for review data (since mappings can't be in structs returned from functions)
    mapping(uint256 => mapping(address => bool)) public hasReviewed;
    mapping(uint256 => mapping(address => uint256)) public reviewScores;
    
    // Arrays
    address[] public reviewers;
    uint256[] public pendingContributions;
    
    // Events
    event ContributionSubmitted(
        uint256 indexed contributionId,
        address indexed contributor,
        ContributionType contributionType,
        uint256 value,
        string proofHash
    );
    event ContributionReviewed(
        uint256 indexed contributionId,
        address indexed reviewer,
        uint256 qualityScore,
        uint256 impactScore
    );
    event ContributionApproved(
        uint256 indexed contributionId,
        address indexed contributor,
        uint256 rewardAmount
    );
    event ContributionRejected(
        uint256 indexed contributionId,
        address indexed contributor,
        string reason
    );
    event ReviewerAdded(address indexed reviewer);
    event ReviewerRemoved(address indexed reviewer);
    event ReputationUpdated(address indexed contributor, uint256 newScore);
    
    constructor(address _daiToken, address _stakingContract) Ownable(msg.sender) {
        daiToken = DAIToken(_daiToken);
        stakingContract = Staking(_stakingContract);
        
        // Initialize contribution rewards
        contributionRewards[ContributionType.AI_TRAINING] = 8; // 8% base reward
        contributionRewards[ContributionType.DATA_PROVISION] = 6; // 6% base reward
        contributionRewards[ContributionType.COMPUTATIONAL_RESOURCES] = 7; // 7% base reward
        contributionRewards[ContributionType.RESEARCH_DEVELOPMENT] = 10; // 10% base reward
        contributionRewards[ContributionType.GOVERNANCE_PARTICIPATION] = 5; // 5% base reward
    }
    
    /**
     * @dev Submit a new contribution
     * @param contributionType Type of contribution
     * @param description Description of the contribution
     * @param proofHash IPFS hash of the proof
     * @param value Contribution value
     */
    function submitContribution(
        ContributionType contributionType,
        string memory description,
        string memory proofHash,
        uint256 value
    ) external whenNotPaused nonReentrant {
        require(value >= MIN_CONTRIBUTION_VALUE, "Contribution: Value too low");
        require(value <= MAX_CONTRIBUTION_VALUE, "Contribution: Value too high");
        require(bytes(description).length > 0, "Contribution: Description required");
        require(bytes(proofHash).length > 0, "Contribution: Proof required");
        
        // Check if contributor has active staking position
        require(
            stakingContract.hasActiveStaking(msg.sender),
            "Contribution: Active staking required"
        );
        
        // Create contribution
        uint256 contributionId = totalContributions;
        Contribution storage contribution = contributions[contributionId];
        
        contribution.id = contributionId;
        contribution.contributor = msg.sender;
        contribution.contributionType = contributionType;
        contribution.description = description;
        contribution.proofHash = proofHash;
        contribution.value = value;
        contribution.status = ContributionStatus.PENDING;
        contribution.submissionTime = block.timestamp;
        
        // Update contributor profile
        ContributorProfile storage profile = contributorProfiles[msg.sender];
        profile.totalContributions = profile.totalContributions + 1;
        profile.lastContributionTime = block.timestamp;
        profile.isActive = true;
        
        // Add to contributor's contribution list
        contributorContributions[msg.sender].push(contributionId);
        
        // Add to pending contributions
        pendingContributions.push(contributionId);
        
        totalContributions = totalContributions + 1;
        
        emit ContributionSubmitted(contributionId, msg.sender, contributionType, value, proofHash);
    }
    
    /**
     * @dev Review a contribution
     * @param contributionId ID of the contribution to review
     * @param criteria Review criteria scores
     * @param comments Review comments (unused in current implementation)
     */
    function reviewContribution(
        uint256 contributionId,
        ReviewCriteria memory criteria,
        string memory comments
    ) external whenNotPaused nonReentrant {
        require(isReviewer[msg.sender], "Contribution: Not a reviewer");
        require(contributionId < totalContributions, "Contribution: Invalid ID");
        
        Contribution storage contribution = contributions[contributionId];
        require(contribution.status == ContributionStatus.PENDING, "Contribution: Not pending");
        require(!hasReviewed[contributionId][msg.sender], "Contribution: Already reviewed");
        
        // Validate criteria scores
        require(criteria.technicalQuality <= 100, "Contribution: Invalid technical quality score");
        require(criteria.innovation <= 100, "Contribution: Invalid innovation score");
        require(criteria.impact <= 100, "Contribution: Invalid impact score");
        require(criteria.documentation <= 100, "Contribution: Invalid documentation score");
        require(criteria.communityBenefit <= 100, "Contribution: Invalid community benefit score");
        
        // Calculate overall scores
        uint256 qualityScore = (
            criteria.technicalQuality + criteria.innovation + criteria.documentation
        ) / 3;
        
        uint256 impactScore = (
            criteria.impact + criteria.communityBenefit
        ) / 2;
        
        // Store review
        hasReviewed[contributionId][msg.sender] = true;
        reviewScores[contributionId][msg.sender] = (qualityScore + impactScore) / 2;
        contribution.reviewers.push(msg.sender);
        
        // Update reviewer reputation
        reviewerReputation[msg.sender] = reviewerReputation[msg.sender] + 1;
        
        emit ContributionReviewed(contributionId, msg.sender, qualityScore, impactScore);
        
        // Check if enough reviews collected
        if (contribution.reviewers.length >= MIN_REVIEWERS) {
            _processContribution(contributionId);
        }
        
        // Silence unused variable warning
        bytes(comments);
    }
    
    /**
     * @dev Process contribution after reviews
     * @param contributionId ID of the contribution to process
     */
    function _processContribution(uint256 contributionId) internal {
        Contribution storage contribution = contributions[contributionId];
        
        // Calculate average scores
        uint256 totalScore = 0;
        for (uint256 i = 0; i < contribution.reviewers.length; i++) {
            totalScore = totalScore + reviewScores[contributionId][contribution.reviewers[i]];
        }
        
        uint256 averageScore = totalScore / contribution.reviewers.length;
        contribution.qualityScore = averageScore;
        contribution.impactScore = averageScore;
        contribution.reviewTime = block.timestamp;
        
        // Determine approval based on score
        if (averageScore >= 70) {
            contribution.status = ContributionStatus.APPROVED;
            _calculateReward(contributionId);
            _updateContributorReputation(contribution.contributor, averageScore);
            emit ContributionApproved(contributionId, contribution.contributor, contribution.rewardAmount);
        } else {
            contribution.status = ContributionStatus.REJECTED;
            emit ContributionRejected(contributionId, contribution.contributor, "Low quality score");
        }
        
        // Remove from pending contributions
        _removeFromPending(contributionId);
    }
    
    /**
     * @dev Calculate reward for approved contribution
     * @param contributionId ID of the contribution
     */
    function _calculateReward(uint256 contributionId) internal {
        Contribution storage contribution = contributions[contributionId];
        
        // Base reward calculation
        uint256 baseReward = (contribution.value * contributionRewards[contribution.contributionType]) / 100;
        
        // Quality multiplier
        uint256 qualityMultiplier = (contribution.qualityScore * REWARD_MULTIPLIER) / 100;
        
        // Impact multiplier
        uint256 impactMultiplier = (contribution.impactScore * REWARD_MULTIPLIER) / 100;
        
        // Final reward calculation
        uint256 finalReward = (baseReward * (qualityMultiplier + impactMultiplier)) / 200;
        
        contribution.rewardAmount = finalReward;
        contribution.status = ContributionStatus.REWARDED;
        
        // Update contributor profile
        contributorProfiles[contribution.contributor].totalRewards = 
            contributorProfiles[contribution.contributor].totalRewards + finalReward;
        
        // Update total rewards distributed
        totalRewardsDistributed = totalRewardsDistributed + finalReward;
        
        // Transfer reward
        require(daiToken.transfer(contribution.contributor, finalReward), "Transfer failed");
    }
    
    /**
     * @dev Update contributor reputation
     * @param contributor Address of the contributor
     * @param score Quality score
     */
    function _updateContributorReputation(address contributor, uint256 score) internal {
        ContributorProfile storage profile = contributorProfiles[contributor];
        
        // Calculate reputation update (prevent underflow)
        uint256 reputationUpdate = score > 50 ? score - 50 : 0; // Base score of 50
        
        // Update reputation with decay
        uint256 timeSinceLastContribution = block.timestamp - profile.lastContributionTime;
        uint256 decayFactor = timeSinceLastContribution / 30 days; // 1% decay per month
        
        // Fix: Handle potential underflow by checking before subtraction
        if (profile.reputationScore + reputationUpdate > decayFactor) {
            profile.reputationScore = (profile.reputationScore + reputationUpdate) - decayFactor;
        } else {
            profile.reputationScore = 0;
        }
        
        emit ReputationUpdated(contributor, profile.reputationScore);
    }
    
    /**
     * @dev Add a new reviewer
     * @param reviewer Address of the reviewer
     */
    function addReviewer(address reviewer) external onlyOwner {
        require(reviewer != address(0), "Contribution: Invalid reviewer address");
        require(!isReviewer[reviewer], "Contribution: Already a reviewer");
        
        isReviewer[reviewer] = true;
        reviewers.push(reviewer);
        activeReviewers = activeReviewers + 1;
        
        emit ReviewerAdded(reviewer);
    }
    
    /**
     * @dev Remove a reviewer
     * @param reviewer Address of the reviewer
     */
    function removeReviewer(address reviewer) external onlyOwner {
        require(isReviewer[reviewer], "Contribution: Not a reviewer");
        
        isReviewer[reviewer] = false;
        
        // Only decrement if activeReviewers > 0 to prevent underflow
        if (activeReviewers > 0) {
            activeReviewers = activeReviewers - 1;
        }
        
        // Remove from reviewers array
        for (uint256 i = 0; i < reviewers.length; i++) {
            if (reviewers[i] == reviewer) {
                reviewers[i] = reviewers[reviewers.length - 1];
                reviewers.pop();
                break;
            }
        }
        
        emit ReviewerRemoved(reviewer);
    }
    
    /**
     * @dev Get contribution details
     * @param contributionId ID of the contribution
     */
    function getContribution(uint256 contributionId) external view returns (
        uint256 id,
        address contributor,
        ContributionType contributionType,
        string memory description,
        string memory proofHash,
        uint256 value,
        uint256 qualityScore,
        uint256 impactScore,
        ContributionStatus status,
        uint256 submissionTime,
        uint256 reviewTime,
        uint256 rewardAmount
    ) {
        require(contributionId < totalContributions, "Contribution: Invalid ID");
        Contribution storage contribution = contributions[contributionId];
        return (
            contribution.id,
            contribution.contributor,
            contribution.contributionType,
            contribution.description,
            contribution.proofHash,
            contribution.value,
            contribution.qualityScore,
            contribution.impactScore,
            contribution.status,
            contribution.submissionTime,
            contribution.reviewTime,
            contribution.rewardAmount
        );
    }
    
    /**
     * @dev Get contributor profile
     * @param contributor Address of the contributor
     */
    function getContributorProfile(address contributor) external view returns (
        uint256 contributorTotalContributions,
        uint256 contributorTotalRewards,
        uint256 contributorReputationScore,
        uint256 contributorLastContributionTime,
        bool contributorIsActive
    ) {
        require(contributor != address(0), "Contribution: Invalid contributor address");
        ContributorProfile storage profile = contributorProfiles[contributor];
        return (
            profile.totalContributions,
            profile.totalRewards,
            profile.reputationScore,
            profile.lastContributionTime,
            profile.isActive
        );
    }
    
    /**
     * @dev Get pending contributions
     * @return Array of pending contribution IDs
     */
    function getPendingContributions() external view returns (uint256[] memory) {
        return pendingContributions;
    }
    
    /**
     * @dev Get system statistics
     * @return totalContributions_ Total number of contributions
     * @return totalRewardsDistributed_ Total rewards distributed
     * @return activeReviewers_ Number of active reviewers
     */
    function getSystemStats() external view returns (
        uint256 totalContributions_,
        uint256 totalRewardsDistributed_,
        uint256 activeReviewers_
    ) {
        return (
            totalContributions,
            totalRewardsDistributed,
            activeReviewers
        );
    }
    
    /**
     * @dev Remove contribution from pending list
     * @param contributionId ID of the contribution
     */
    function _removeFromPending(uint256 contributionId) internal {
        for (uint256 i = 0; i < pendingContributions.length; i++) {
            if (pendingContributions[i] == contributionId) {
                pendingContributions[i] = pendingContributions[pendingContributions.length - 1];
                pendingContributions.pop();
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