// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title DAIToken
 * @dev Decentralize AI Token - The native token of the Decentralize AI network
 * 
 * Features:
 * - ERC20 standard with voting capabilities
 * - Burnable tokens for deflationary mechanics
 * - Pausable for emergency situations
 * - Ownable for initial distribution management
 * - Fixed supply of 1 billion tokens
 */
contract DAIToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, Ownable, Pausable {
    
    // Fixed total supply: 1 billion tokens
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18;
    
    // Token allocation constants
    uint256 public constant CONTRIBUTORS_ALLOCATION = 600_000_000 * 10**18; // 60%
    uint256 public constant VALIDATORS_ALLOCATION = 200_000_000 * 10**18;   // 20%
    uint256 public constant TREASURY_ALLOCATION = 100_000_000 * 10**18;     // 10%
    uint256 public constant EARLY_ALLOCATION = 50_000_000 * 10**18;         // 5%
    uint256 public constant RESERVE_ALLOCATION = 50_000_000 * 10**18;       // 5%
    
    // Distribution tracking
    mapping(address => bool) public hasReceivedInitialAllocation;
    uint256 public distributedTokens;
    
    // Emergency controls
    bool public emergencyMode;
    mapping(address => bool) public emergencyExempt;
    
    event EmergencyModeToggled(bool enabled);
    event EmergencyExemptUpdated(address indexed account, bool exempt);
    event InitialDistribution(address indexed to, uint256 amount, string category);
    
    constructor() 
        ERC20("Decentralize AI Token", "DAI") 
        ERC20Permit("Decentralize AI Token") 
        Ownable(msg.sender) 
    {
        // Mint total supply to contract for controlled distribution
        _mint(address(this), TOTAL_SUPPLY);
    }
    
    /**
     * @dev Distribute initial token allocation
     * @param to Address to receive tokens
     * @param amount Amount of tokens to distribute
     * @param category Category of allocation (contributors, validators, etc.)
     */
    function distributeInitialAllocation(
        address to,
        uint256 amount,
        string memory category
    ) internal {
        require(!hasReceivedInitialAllocation[to], "DAI: Already received initial allocation");
        require(distributedTokens + amount <= TOTAL_SUPPLY, "DAI: Exceeds total supply");
        require(to != address(0), "DAI: Invalid address");
        
        hasReceivedInitialAllocation[to] = true;
        distributedTokens += amount;
        
        _transfer(address(this), to, amount);
        
        emit InitialDistribution(to, amount, category);
    }
    
    /**
     * @dev Batch distribute initial allocations
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to distribute
     * @param categories Array of allocation categories
     */
    function batchDistributeInitialAllocation(
        address[] calldata recipients,
        uint256[] calldata amounts,
        string[] calldata categories
    ) external onlyOwner {
        require(
            recipients.length == amounts.length && 
            amounts.length == categories.length,
            "DAI: Array length mismatch"
        );
        
        for (uint256 i = 0; i < recipients.length; i++) {
            distributeInitialAllocation(recipients[i], amounts[i], categories[i]);
        }
    }
    
    /**
     * @dev Toggle emergency mode
     * @param enabled Whether to enable emergency mode
     */
    function toggleEmergencyMode(bool enabled) external onlyOwner {
        emergencyMode = enabled;
        emit EmergencyModeToggled(enabled);
    }
    
    /**
     * @dev Set emergency exemption for an address
     * @param account Address to set exemption for
     * @param exempt Whether the address is exempt from emergency restrictions
     */
    function setEmergencyExempt(address account, bool exempt) external onlyOwner {
        emergencyExempt[account] = exempt;
        emit EmergencyExemptUpdated(account, exempt);
    }
    
    /**
     * @dev Override _update to include emergency mode checks
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Votes) whenNotPaused {
        // Allow transfers during emergency mode only for exempt addresses
        if (emergencyMode) {
            require(
                emergencyExempt[from] || emergencyExempt[to] || from == address(0) || to == address(0),
                "DAI: Emergency mode active"
            );
        }
        
        super._update(from, to, value);
    }

    /**
     * @dev Override nonces to resolve diamond inheritance
     */
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
    
    // Note: _update function above handles both ERC20 and ERC20Votes functionality
    // No need for separate _afterTokenTransfer, _mint, or _burn overrides
    
    /**
     * @dev Pause token transfers
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Get remaining tokens available for distribution
     */
    function getRemainingDistribution() external view returns (uint256) {
        return TOTAL_SUPPLY - distributedTokens;
    }
    
    /**
     * @dev Check if address has received initial allocation
     */
    function hasReceivedAllocation(address account) external view returns (bool) {
        return hasReceivedInitialAllocation[account];
    }
    
    /**
     * @dev Get distribution statistics
     */
    function getDistributionStats() external view returns (
        uint256 total,
        uint256 distributed,
        uint256 remaining
    ) {
        total = TOTAL_SUPPLY;
        distributed = distributedTokens;
        remaining = total - distributed;
    }
}
