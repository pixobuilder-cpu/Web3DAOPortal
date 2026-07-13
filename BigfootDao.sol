// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BigfootDAO {
    struct Proposal {
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
    }

    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    constructor() {
        // On crée une première proposition pour le Lab au déploiement
        proposals.push(Proposal("Deployer le portail Web3 de la DAO sur Polygon", 0, 0, false));
    }

    function proposalCount() external view returns (uint256) {
        return proposals.length;
    }

    function vote(uint256 _proposalId, bool _support) external {
        require(_proposalId < proposals.length, "Proposition inexistante");
        require(!hasVoted[_proposalId][msg.sender], "Deja vote");

        hasVoted[_proposalId][msg.sender] = true;

        if (_support) {
            proposals[_proposalId].votesFor += 1; // Remplacer par le solde de BFT pour un vote pondéré
        } else {
            proposals[_proposalId].votesAgainst += 1;
        }
    }
}
