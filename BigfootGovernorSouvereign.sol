// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// Custom explicit interface mapping your BigfootNFT functions directly
interface IBigfootNFTVotes {
    function getVotes(address account) external view returns (uint256);
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
}

/**
 * @title BigfootGovernorSovereign
 * @dev Governance contract mapped to the BigfootNFT voting power system.
 */
contract BigfootGovernorSovereign is Governor, GovernorSettings, GovernorCountingSimple, GovernorTimelockControl, AccessControl {
    
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant WEBMASTER_ROLE = keccak256("WEBMASTER_ROLE");

    // Core Ledger Addresses
    address public constant TIMELOCK_ADDRESS = 0xBbe836B8D8b8aA742989Ff9E4EFbEcE211681877;
    address public constant VAULT_ADMIN = 0x5F0Abd8D46b94F1734fCB9eCdE6f1006d0ffc549;

    // Custom internal reference point for your NFT contract tracking
    IBigfootNFTVotes public immutable nftVotingToken;

    constructor(address _nftTokenAddress, address _mainDeveloper)
        Governor("BigfootGovernorSovereign")
        GovernorSettings(1, 45818, 1 * 10**18) // 1 block delay, ~1 week voting period, 1 NFT threshold to propose
        GovernorTimelockControl(TimelockController(payable(TIMELOCK_ADDRESS)))
    {
        nftVotingToken = IBigfootNFTVotes(_nftTokenAddress);

        // 1. Assign supreme administrative control to the Safe vault
        _grantRole(DEFAULT_ADMIN_ROLE, VAULT_ADMIN);

        // 2. Assign technical roles for full-stack maintenance
        _grantRole(MAINTAINER_ROLE, _mainDeveloper);
        _grantRole(WEBMASTER_ROLE, _mainDeveloper);
    }

    /**
     * @dev Overriding standard clock mechanism to match traditional block tracking 
     */
    function clock() public view override returns (uint48) {
        return uint48(block.number);
    }

    /**
     * @dev Overriding standard clock tracking string identity definition
     */
    function CLOCK_MODE() public view override returns (string memory) {
        return "mode=blocknumber";
    }

    /**
     * @dev Core function reading your NFT contract voting engine layout state
     */
    function _getVotes(address account, uint256 timepoint, bytes memory /*params*/) internal view override returns (uint256) {
        return nftVotingToken.getPastVotes(account, timepoint);
    }

    function updateTechnicalConfig(bytes32 configKey, bool status) public onlyRole(MAINTAINER_ROLE) {
        // Technical maintenance logic
    }

    // =========================================================================
    //                           REQUIRED OVERRIDES
    // =========================================================================

    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 /*timepoint*/) public view override returns (uint256) {
        // Simple hardcoded quorum target representing 4 votes/NFT tokens for testing/initial launch phase
        return 4;
    }

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function proposalNeedsQueuing(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _executeOperations(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _queueOperations(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId) public view override(Governor, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

