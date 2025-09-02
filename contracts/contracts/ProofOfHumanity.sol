// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./DAIToken.sol";

/**
 * @title ProofOfHumanity
 * @dev Sybil-resistance mechanism using proof-of-humanity verification
 * 
 * Features:
 * - Human verification through multiple attestation methods
 * - Reputation-based Sybil resistance
 * - Decentralized verification process
 * - Economic incentives for honest behavior
 * - Privacy-preserving verification
 */
contract ProofOfHumanity is ReentrancyGuard, Ownable, Pausable {
    

    
    // Verification methods
    enum VerificationMethod {
        SOCIAL_ATTESTATION,
        BIOMETRIC_VERIFICATION,
        KNOWLEDGE_PROOF,
        BEHAVIORAL_ANALYSIS,
        COMMUNITY_VOUCHING
    }
    
    // Human status
    enum HumanStatus {
        UNVERIFIED,
        PENDING_VERIFICATION,
        VERIFIED,
        SUSPENDED,
        REVOKED
    }
    
    // Human profile
    struct HumanProfile {
        address humanAddress;
        HumanStatus status;
        uint256 verificationScore;
        uint256 attestationCount;
        uint256 lastVerificationTime;
        bool isActive;
        mapping(VerificationMethod => bool) verificationMethods;
        mapping(address => bool) attestations;
    }
    
    // Attestation
    struct Attestation {
        address attester;
        address human;
        VerificationMethod method;
        uint256 confidence;
        string proof;
        uint256 timestamp;
        bool isValid;
    }
    
    // Constants
    uint256 public constant MIN_VERIFICATION_SCORE = 70;
    uint256 public constant MAX_VERIFICATION_SCORE = 100;
    uint256 public constant ATTESTATION_REWARD = 10 * 10**18; // 10 DAI
    uint256 public constant VERIFICATION_DEPOSIT = 100 * 10**18; // 100 DAI
    uint256 public constant MIN_ATTESTATIONS = 3;
    uint256 public constant ATTESTATION_TIMEOUT = 7 days;
    
    // State variables
    DAIToken public daiToken;
    uint256 public totalHumans;
    uint256 public totalAttestations;
    uint256 public totalRewardsDistributed;
    
    // Mappings
    mapping(address => HumanProfile) public humanProfiles;
    mapping(address => bool) public isHuman;
    mapping(address => bool) public isAttester;
    mapping(uint256 => Attestation) public attestations;
    mapping(address => uint256[]) public humanAttestations;
    mapping(VerificationMethod => uint256) public methodWeights;
    
    // Arrays
    address[] public verifiedHumans;
    address[] public attesters;
    
    // Events
    event HumanRegistered(address indexed human, uint256 verificationScore);
    event HumanVerified(address indexed human, uint256 verificationScore);
    event HumanSuspended(address indexed human, string reason);
    event AttestationSubmitted(address indexed attester, address indexed human, VerificationMethod method);
    event AttestationVerified(uint256 indexed attestationId, bool isValid);
    event AttesterAdded(address indexed attester);
    event AttesterRemoved(address indexed attester);
    event VerificationMethodUpdated(VerificationMethod method, uint256 weight);
    
    constructor(address _daiToken) Ownable(msg.sender) {
        daiToken = DAIToken(_daiToken);
        
        // Initialize verification method weights
        methodWeights[VerificationMethod.SOCIAL_ATTESTATION] = 20;
        methodWeights[VerificationMethod.BIOMETRIC_VERIFICATION] = 30;
        methodWeights[VerificationMethod.KNOWLEDGE_PROOF] = 25;
        methodWeights[VerificationMethod.BEHAVIORAL_ANALYSIS] = 15;
        methodWeights[VerificationMethod.COMMUNITY_VOUCHING] = 10;
    }
    
    /**
     * @dev Register as a human candidate
     */
    function registerAsHuman() external whenNotPaused nonReentrant {
        require(!isHuman[msg.sender], "ProofOfHumanity: Already registered");
        require(humanProfiles[msg.sender].humanAddress == address(0), "ProofOfHumanity: Profile exists");
        
        // Create human profile
        HumanProfile storage profile = humanProfiles[msg.sender];
        profile.humanAddress = msg.sender;
        profile.status = HumanStatus.PENDING_VERIFICATION;
        profile.verificationScore = 0;
        profile.attestationCount = 0;
        profile.lastVerificationTime = block.timestamp;
        profile.isActive = true;
        
        totalHumans = totalHumans + 1;
        
        emit HumanRegistered(msg.sender, 0);
    }
    
    /**
     * @dev Submit attestation for human verification
     * @param human Address of the human to attest
     * @param method Verification method used
     * @param confidence Confidence level (0-100)
     * @param proof Proof of verification
     */
    function submitAttestation(
        address human,
        VerificationMethod method,
        uint256 confidence,
        string memory proof
    ) external whenNotPaused nonReentrant {
        require(isAttester[msg.sender], "ProofOfHumanity: Not an attester");
        require(human != msg.sender, "ProofOfHumanity: Cannot attest to self");
        require(humanProfiles[human].humanAddress != address(0), "ProofOfHumanity: Human not registered");
        require(confidence <= 100, "ProofOfHumanity: Invalid confidence level");
        require(!humanProfiles[human].attestations[msg.sender], "ProofOfHumanity: Already attested");
        
        // Create attestation
        uint256 attestationId = totalAttestations;
        Attestation storage attestation = attestations[attestationId];
        
        attestation.attester = msg.sender;
        attestation.human = human;
        attestation.method = method;
        attestation.confidence = confidence;
        attestation.proof = proof;
        attestation.timestamp = block.timestamp;
        attestation.isValid = true;
        
        // Update human profile
        HumanProfile storage profile = humanProfiles[human];
        profile.attestations[msg.sender] = true;
        profile.attestationCount = profile.attestationCount + 1;
        profile.verificationMethods[method] = true;
        
        // Add to human's attestation list
        humanAttestations[human].push(attestationId);
        
        totalAttestations = totalAttestations + 1;
        
        emit AttestationSubmitted(msg.sender, human, method);
        
        // Check if human can be verified
        _checkVerificationStatus(human);
    }
    
    /**
     * @dev Check if human can be verified
     * @param human Address of the human
     */
    function _checkVerificationStatus(address human) internal {
        HumanProfile storage profile = humanProfiles[human];
        
        if (profile.attestationCount >= MIN_ATTESTATIONS) {
            // Calculate verification score
            uint256 verificationScore = _calculateVerificationScore(human);
            
            if (verificationScore >= MIN_VERIFICATION_SCORE) {
                // Verify human
                profile.status = HumanStatus.VERIFIED;
                profile.verificationScore = verificationScore;
                profile.lastVerificationTime = block.timestamp;
                
                isHuman[human] = true;
                verifiedHumans.push(human);
                
                // Distribute rewards to attesters
                _distributeAttestationRewards(human);
                
                emit HumanVerified(human, verificationScore);
            }
        }
    }
    
    /**
     * @dev Calculate verification score for a human
     * @param human Address of the human
     * @return verificationScore Calculated verification score
     */
    function _calculateVerificationScore(address human) internal view returns (uint256) {
        HumanProfile storage profile = humanProfiles[human];
        uint256[] memory humanAtts = humanAttestations[human];
        
        uint256 totalScore = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < humanAtts.length; i++) {
            Attestation storage attestation = attestations[humanAtts[i]];
            
            if (attestation.isValid) {
                uint256 methodWeight = methodWeights[attestation.method];
                uint256 weightedScore = (attestation.confidence * methodWeight) / 100;
                
                totalScore = totalScore + weightedScore;
                totalWeight = totalWeight + methodWeight;
            }
        }
        
        if (totalWeight == 0) return 0;
        
        return (totalScore * 100) / totalWeight;
    }
    
    /**
     * @dev Distribute rewards to attesters
     * @param human Address of the verified human
     */
    function _distributeAttestationRewards(address human) internal {
        uint256[] memory humanAtts = humanAttestations[human];
        
        for (uint256 i = 0; i < humanAtts.length; i++) {
            Attestation storage attestation = attestations[humanAtts[i]];
            
            if (attestation.isValid) {
                // Transfer reward to attester
                daiToken.transfer(attestation.attester, ATTESTATION_REWARD);
                totalRewardsDistributed = totalRewardsDistributed + ATTESTATION_REWARD;
            }
        }
    }
    
    /**
     * @dev Suspend a human
     * @param human Address of the human to suspend
     * @param reason Reason for suspension
     */
    function suspendHuman(address human, string memory reason) external onlyOwner {
        require(isHuman[human], "ProofOfHumanity: Human not verified");
        
        HumanProfile storage profile = humanProfiles[human];
        profile.status = HumanStatus.SUSPENDED;
        profile.isActive = false;
        
        // Remove from verified humans array
        _removeFromVerifiedHumans(human);
        isHuman[human] = false;
        
        emit HumanSuspended(human, reason);
    }
    
    /**
     * @dev Revoke human verification
     * @param human Address of the human to revoke
     */
    function revokeHuman(address human) external onlyOwner {
        require(isHuman[human], "ProofOfHumanity: Human not verified");
        
        HumanProfile storage profile = humanProfiles[human];
        profile.status = HumanStatus.REVOKED;
        profile.isActive = false;
        
        // Remove from verified humans array
        _removeFromVerifiedHumans(human);
        isHuman[human] = false;
        
        emit HumanSuspended(human, "Verification revoked");
    }
    
    /**
     * @dev Add attester
     * @param attester Address of the attester
     */
    function addAttester(address attester) external onlyOwner {
        require(!isAttester[attester], "ProofOfHumanity: Already an attester");
        
        isAttester[attester] = true;
        attesters.push(attester);
        
        emit AttesterAdded(attester);
    }
    
    /**
     * @dev Remove attester
     * @param attester Address of the attester
     */
    function removeAttester(address attester) external onlyOwner {
        require(isAttester[attester], "ProofOfHumanity: Not an attester");
        
        isAttester[attester] = false;
        
        // Remove from attesters array
        for (uint256 i = 0; i < attesters.length; i++) {
            if (attesters[i] == attester) {
                attesters[i] = attesters[attesters.length - 1];
                attesters.pop();
                break;
            }
        }
        
        emit AttesterRemoved(attester);
    }
    
    /**
     * @dev Update verification method weight
     * @param method Verification method
     * @param weight New weight
     */
    function updateVerificationMethodWeight(VerificationMethod method, uint256 weight) external onlyOwner {
        require(weight <= 100, "ProofOfHumanity: Invalid weight");
        
        methodWeights[method] = weight;
        emit VerificationMethodUpdated(method, weight);
    }
    
    /**
     * @dev Get human verification status
     * @param human Address of the human
     */
    function getHumanStatus(address human) external view returns (
        HumanStatus status,
        uint256 verificationScore,
        uint256 attestationCount,
        bool isActive
    ) {
        HumanProfile storage profile = humanProfiles[human];
        return (
            profile.status,
            profile.verificationScore,
            profile.attestationCount,
            profile.isActive
        );
    }
    
    /**
     * @dev Get human attestations
     * @param human Address of the human
     */
    function getHumanAttestations(address human) external view returns (uint256[] memory) {
        return humanAttestations[human];
    }
    
    /**
     * @dev Get attestation details
     * @param attestationId ID of the attestation
     */
    function getAttestation(uint256 attestationId) external view returns (
        address attester,
        address human,
        VerificationMethod method,
        uint256 confidence,
        string memory proof,
        uint256 timestamp,
        bool isValid
    ) {
        Attestation storage attestation = attestations[attestationId];
        return (
            attestation.attester,
            attestation.human,
            attestation.method,
            attestation.confidence,
            attestation.proof,
            attestation.timestamp,
            attestation.isValid
        );
    }
    
    /**
     * @dev Get system statistics
     */
    function getSystemStats() external view returns (
        uint256 totalHumans,
        uint256 totalAttestations,
        uint256 totalRewardsDistributed,
        uint256 verifiedHumansCount,
        uint256 attestersCount
    ) {
        return (
            totalHumans,
            totalAttestations,
            totalRewardsDistributed,
            verifiedHumans.length,
            attesters.length
        );
    }
    
    /**
     * @dev Remove human from verified humans array
     * @param human Address of the human
     */
    function _removeFromVerifiedHumans(address human) internal {
        for (uint256 i = 0; i < verifiedHumans.length; i++) {
            if (verifiedHumans[i] == human) {
                verifiedHumans[i] = verifiedHumans[verifiedHumans.length - 1];
                verifiedHumans.pop();
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
