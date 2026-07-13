// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BigFootVaultAmoy is ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // 📌 MODIFICATION 1 : L'asset devient dynamique et correspond à votre jeton BFT
    IERC20 public immutable asset; 

    // 📌 MODIFICATION 2 : Adresse de votre mockUSDC sur Amoy pour la sécurité
    address public constant MOCK_USDC = 0xD09Ad70EDB4Fc60D456e2E69E3789c03a12c2C58;

    // 📌 MODIFICATION 3 : Adresse de votre Mock DEX sur Amoy (pour les futures stratégies)
    address public constant MOCK_DEX = 0x54B3802a7796711c8DaACA10664F89F87Bd54317;

    // Mitigation for Inflation Attacks: Virtual Shares/Offset
    uint256 public constant VIRTUAL_OFFSET = 10**3; 

    /**
     * @dev Constructeur modifié pour accepter l'adresse de votre jeton BFT
     * @param _asset Adresse du jeton déposé (votre BFT sur Amoy)
     */
    constructor(address _asset) 
        ERC20("BigFoot Index Amoy", "BFTX-A") 
        Ownable(msg.sender) 
    {
        require(_asset != address(0), "Asset cannot be zero address");
        asset = IERC20(_asset);
    }

    /**
     * @notice Retourne le total des actifs détenus par le vault.
     */
    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /**
     * @notice Calcul des parts (standard ERC-4626 avec offset virtuel)
     */
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        return (assets * (supply + VIRTUAL_OFFSET)) / (totalAssets() + VIRTUAL_OFFSET);
    }

    /**
     * @notice Dépôt sécurisé avec CEI et ReentrancyGuard.
     */
    function deposit(uint256 assets) external nonReentrant {
        require(assets > 0, "Zero assets");

        uint256 shares = convertToShares(assets);
        require(shares > 0, "Rounding error: shares is 0");

        // CEI: Interactions en dernier
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(msg.sender, shares);
    }

    /**
     * @notice Retrait sécurisé.
     */
    function withdraw(uint256 shares) external nonReentrant {
        require(shares > 0 && balanceOf(msg.sender) >= shares, "Invalid shares");

        uint256 assetsToReturn = (shares * totalAssets()) / totalSupply();

        _burn(msg.sender, shares);
        asset.safeTransfer(msg.sender, assetsToReturn);
    }

    /**
     * @notice Fonction de récupération sécurisée (modifiée pour Amoy)
     */
    function recoverUnrelatedTokens(address token) external onlyOwner {
        require(token != address(asset) && token != MOCK_USDC, "Cannot drain core assets");
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(owner(), amount);
    }

    /**
     * @notice NOUVEAU : Fonction pour préparer l'intégration avec le Mock DEX
     * @dev Cette fonction sera appelée par votre agent IA pour exécuter des stratégies
     * @param amount Montant de BFT à utiliser pour la stratégie
     */
    function deployStrategy(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require(asset.balanceOf(address(this)) >= amount, "Insufficient balance in vault");

        // Approve le DEX à dépenser les BFT
        asset.approve(MOCK_DEX, amount);

        // TODO: Appeler la fonction swap du DEX
        // (IMockDEX(MOCK_DEX).swap(address(asset), amount);)
        
        // Pour l'instant, on simule en transférant les BFT vers le DEX
        // Dans une vraie stratégie, vous appelleriez swap() et géreriez les tokens reçus
        asset.safeTransfer(MOCK_DEX, amount);
        
        emit StrategyDeployed(amount, block.timestamp);
    }

    // 📌 NOUVEAU : Events pour le suivi des stratégies
    event StrategyDeployed(uint256 amount, uint256 timestamp);
}
