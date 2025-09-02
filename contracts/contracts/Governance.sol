// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DAIToken.sol";

/**
 * @title Governance
 * @dev Constitutional governance system for Decentralize AI network
 * 
 * Features:
 * - Quadratic voting to prevent whale dominance
 * - Constitutional compliance checking
 * - Merit-based voting power
 * - Emergency governance procedures
 * - Transparent proposal and voting system
 */
contract Governance is 
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    Ownable
{
    
    // Constitutional requirements
    uint256 public constant CONSTITUTIONAL_AMENDMENT_THRESHOLD = 67; // 67% required
    uint256 public constant EMERGENCY_THRESHOLD = 80; // 80% for emergency measures
    uint256 public constant DELIBERATION_PERIOD = 7 days; // Minimum deliberation time
    
    // Proposal categories
    enum ProposalCategory {
        GENERAL,           // General governance proposals
        CONSTITUTIONAL,    // Constitutional amendments
        ECONOMIC,          // Economic policy changes
        TECHNICAL,         // Technical upgrades
        EMERGENCY          // Emergency measures
    }
    
    // Proposal metadata
    struct ProposalMetadata {
        ProposalCategory category;
        string description;
        string constitutionalCompliance;
        bool requiresConstitutionalReview;
        uint256 deliberationStart;
    }
    
    // Storage
    mapping(uint256 => ProposalMetadata) public proposalMetadata;
    mapping(address => bool) public constitutionalReviewers;
    mapping(address => uint256) public meritScores;
    mapping(uint256 => uint256) public quadraticVotes; // Track quadratic votes for each proposal
    uint256 public nextProposalId = 1; // Counter for proposal IDs
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        ProposalCategory category,
        address indexed proposer,
        string description
    );
    event ConstitutionalReview(
        uint256 indexed proposalId,
        address indexed reviewer,
        bool compliant
    );
    event MeritScoreUpdated(address indexed account, uint256 newScore);
    event EmergencyModeActivated(uint256 indexed proposalId);
    event QuadraticVoteCast(uint256 indexed proposalId, address indexed voter, uint256 votes);
    
    constructor(
        DAIToken _token,
        TimelockController _timelock
    )
        Governor("Decentralize AI Governance")
        GovernorSettings(
            1, // voting delay (1 block)
            40320, // voting period (1 week in blocks, assuming 15s block time)
            0 // proposal threshold (0 tokens required to propose)
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4) // 4% quorum
        GovernorTimelockControl(_timelock)
        Ownable(msg.sender)
    {}
    
    /**
     * @dev Create a new governance proposal
     * @param targets Array of target addresses for calls
     * @param values Array of ETH values for calls
     * @param calldatas Array of calldata for calls
     * @param description Description of the proposal
     * @param category Category of the proposal
     * @param constitutionalCompliance Constitutional compliance statement
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        ProposalCategory category,
        string memory constitutionalCompliance
    ) public returns (uint256) {
        
        // Check if proposer has sufficient merit score
        require(meritScores[msg.sender] >= 100, "Governance: Insufficient merit score");
        
        // Create proposal
        uint256 proposalId = super.propose(targets, values, calldatas, description);
        
        // Store metadata
        proposalMetadata[proposalId] = ProposalMetadata({
            category: category,
            description: description,
            constitutionalCompliance: constitutionalCompliance,
            requiresConstitutionalReview: category == ProposalCategory.CONSTITUTIONAL,
            deliberationStart: block.timestamp
        });
        
        // Increment proposal counter
        nextProposalId = nextProposalId + 1;
        
        emit ProposalCreated(proposalId, category, msg.sender, description);
        
        return proposalId;
    }
    
    /**
     * @dev Cast a vote with quadratic voting
     * @param proposalId ID of the proposal
     * @param support Support value (0=against, 1=for, 2=abstain)
     * @param votes Number of votes to cast (will be squared)
     */
    function castVoteQuadratic(
        uint256 proposalId,
        uint8 support,
        uint256 votes
    ) public returns (uint256) {
        // Implement quadratic voting
        uint256 quadraticVoteCost = votes * votes;
        
        // Check if voter has sufficient voting power
        require(
            getVotes(msg.sender, proposalSnapshot(proposalId)) >= quadraticVoteCost,
            "Governance: Insufficient voting power"
        );
        
        // Store quadratic votes for tracking
        quadraticVotes[proposalId] = quadraticVotes[proposalId] + quadraticVoteCost;
        
        emit QuadraticVoteCast(proposalId, msg.sender, votes);
        
        return super.castVote(proposalId, support);
    }
    
    /**
     * @dev Cast a vote with reason and quadratic voting
     * @param proposalId ID of the proposal
     * @param support Support value
     * @param reason Reason for the vote
     * @param votes Number of votes to cast
     */
    function castVoteWithReasonQuadratic(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        uint256 votes
    ) public returns (uint256) {
        uint256 quadraticVotesCost = votes * votes;
        
        require(
            getVotes(msg.sender, proposalSnapshot(proposalId)) >= quadraticVotesCost,
            "Governance: Insufficient voting power"
        );
        
        quadraticVotes[proposalId] = quadraticVotes[proposalId] + quadraticVotesCost;
        
        emit QuadraticVoteCast(proposalId, msg.sender, votes);
        
        return super.castVoteWithReason(proposalId, support, reason);
    }
    
    /**
     * @dev Check if a proposal meets constitutional requirements
     * @param proposalId ID of the proposal
     */
    function _checkConstitutionalCompliance(uint256 proposalId) internal view returns (bool) {
        ProposalMetadata memory metadata = proposalMetadata[proposalId];
        
        // For constitutional amendments, require supermajority
        if (metadata.category == ProposalCategory.CONSTITUTIONAL) {
            return _getProposalVotes(proposalId) >= CONSTITUTIONAL_AMENDMENT_THRESHOLD;
        }
        
        // For emergency measures, require emergency threshold
        if (metadata.category == ProposalCategory.EMERGENCY) {
            return _getProposalVotes(proposalId) >= EMERGENCY_THRESHOLD;
        }
        
        return true;
    }
    
    /**
     * @dev Get proposal votes percentage
     * @param proposalId ID of the proposal
     */
    function _getProposalVotes(uint256 proposalId) internal view returns (uint256) {
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = proposalVotes(proposalId);
        uint256 totalVotes = forVotes + againstVotes + abstainVotes;
        
        if (totalVotes == 0) return 0;
        
        return (forVotes * 100) / totalVotes;
    }
    
    /**
     * @dev Update merit score for an address
     * @param account Address to update
     * @param newScore New merit score
     */
    function updateMeritScore(address account, uint256 newScore) external onlyOwner {
        require(account != address(0), "Governance: Invalid account address");
        meritScores[account] = newScore;
        emit MeritScoreUpdated(account, newScore);
    }
    
    /**
     * @dev Add constitutional reviewer
     * @param reviewer Address to add as reviewer
     */
    function addConstitutionalReviewer(address reviewer) external onlyOwner {
        require(reviewer != address(0), "Governance: Invalid reviewer address");
        constitutionalReviewers[reviewer] = true;
    }
    
    /**
     * @dev Remove constitutional reviewer
     * @param reviewer Address to remove as reviewer
     */
    function removeConstitutionalReviewer(address reviewer) external onlyOwner {
        constitutionalReviewers[reviewer] = false;
    }
    
    /**
     * @dev Submit constitutional review
     * @param proposalId ID of the proposal
     * @param compliant Whether the proposal is constitutionally compliant
     */
    function submitConstitutionalReview(
        uint256 proposalId,
        bool compliant
    ) external {
        require(constitutionalReviewers[msg.sender], "Governance: Not a constitutional reviewer");
        require(proposalId < _nextProposalId(), "Governance: Invalid proposal ID");
        
        emit ConstitutionalReview(proposalId, msg.sender, compliant);
    }
    
    /**
     * @dev Activate emergency mode for a proposal
     * @param proposalId ID of the proposal
     */
    function activateEmergencyMode(uint256 proposalId) external onlyOwner {
        require(proposalId < _nextProposalId(), "Governance: Invalid proposal ID");
        ProposalMetadata storage metadata = proposalMetadata[proposalId];
        metadata.category = ProposalCategory.EMERGENCY;
        
        emit EmergencyModeActivated(proposalId);
    }
    
    /**
     * @dev Get proposal metadata
     * @param proposalId ID of the proposal
     */
    function getProposalMetadata(uint256 proposalId) external view returns (ProposalMetadata memory) {
        require(proposalId < _nextProposalId(), "Governance: Invalid proposal ID");
        return proposalMetadata[proposalId];
    }
    
    /**
     * @dev Check if address can propose
     * @param account Address to check
     */
    function canPropose(address account) external view returns (bool) {
        return meritScores[account] >= 100;
    }
    
    /**
     * @dev Get merit score for an address
     * @param account Address to check
     */
    function getMeritScore(address account) external view returns (uint256) {
        return meritScores[account];
    }
    
    /**
     * @dev Override execute to add constitutional checks
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable override(Governor) returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);
        ProposalMetadata memory metadata = proposalMetadata[proposalId];
        
        // Check constitutional compliance for constitutional amendments
        if (metadata.requiresConstitutionalReview) {
            require(
                _checkConstitutionalCompliance(proposalId),
                "Governance: Constitutional compliance not verified"
            );
        }
        
        // Check deliberation period
        require(
            block.timestamp >= metadata.deliberationStart + DELIBERATION_PERIOD,
            "Governance: Deliberation period not met"
        );
        
        return super.execute(targets, values, calldatas, descriptionHash);
    }
    
    // Override required functions
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }
    
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }
    
    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }
    
    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }
    
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor) returns (uint256) {
        return propose(targets, values, calldatas, description, ProposalCategory.GENERAL, "");
    }
    
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }
    
    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
    
    function supportsInterface(bytes4 interfaceId) public view override(Governor) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    // Required override functions for multiple inheritance
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }
    
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }
    
    function proposalNeedsQueuing(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }
    
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }
    
    /**
     * @dev Get the next proposal ID
     * @return The next proposal ID
     */
    function _nextProposalId() internal view returns (uint256) {
        return nextProposalId;
    }
}