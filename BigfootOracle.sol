// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BigfootOracle
 * @notice Part of the Bigfoot Token (BFT) R&D Ecosystem.
 * @dev Hardened Production Infrastructure for Web3 Lab.
 */
contract BigfootOracle is ReentrancyGuard {
    
    // === STRUCTURES DE DONNÉES ===
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 blockNumber;
        address submittedBy;
    }

    struct PoolConfig {
        bool isActive;
        uint256 lastUpdateTime;
    }

    // === ÉTATS ET CONFIGURATIONS ===
    address public owner;
    
    uint256 public constant UPDATE_INTERVAL = 1 hours;
    uint256 public constant STALE_PRICE_THRESHOLD = 2 hours;
    uint256 public constant MIN_PRICE_LIMIT = 10;          
    uint256 public constant MAX_PRICE_LIMIT = 10000000000; 
    uint256 public constant MAX_DEVIATION_BPS = 1500; 

    address public safeVault;
    address public cerebroCore;
    address public priceLensUniswap;

    address[] public activePools;
    mapping(address => PoolConfig) public poolConfigs;
    mapping(address => mapping(uint256 => PriceData)) public priceHistory;
    mapping(address => PriceData) public latestPrice;
    mapping(address => bool) public authorizedUpdaters;

    // === ÉVÉNEMENTS ===
    event PriceUpdated(address indexed pool, uint256 price, uint256 timestamp, address indexed updater);
    event PoolStatusChanged(address indexed pool, bool isActive);
    event UpdaterStatusChanged(address indexed updater, bool isAuthorized);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EcosystemAddressesUpdated(address indexed safeVault, address indexed cerebroCore, address indexed priceLensUniswap);

    // === MODIFIERS ===
    modifier onlyOwner() {
        require(msg.sender == owner || msg.sender == safeVault, "Oracle: Only owner or Safe Vault");
        _;
    }

    modifier onlyUpdater() {
        require(authorizedUpdaters[msg.sender], "Oracle: Not an authorized updater");
        _;
    }

    modifier poolExists(address pool) {
        require(poolConfigs[pool].isActive, "Oracle: Pool is not active");
        _;
    }

    // === CONSTRUCTEUR ===
    /// @notice Initialize the oracle with ecosystem infrastructure addresses.
    /// @param _safeVault Address of the Gnosis Safe.
    /// @param _cerebroCore Address of the Cerebro automation driver.
    /// @param _priceLensUniswap Address of the Uniswap Price Lens.
    constructor(address _safeVault, address _cerebroCore, address _priceLensUniswap) {
        require(_safeVault != address(0), "Oracle: Invalid Safe Vault");
        require(_cerebroCore != address(0), "Oracle: Invalid Cerebro Core");
        require(_priceLensUniswap != address(0), "Oracle: Invalid Price Lens");

        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        safeVault = _safeVault;
        cerebroCore = _cerebroCore;
        priceLensUniswap = _priceLensUniswap;
        emit EcosystemAddressesUpdated(_safeVault, _cerebroCore, _priceLensUniswap);

        authorizedUpdaters[_cerebroCore] = true;
        emit UpdaterStatusChanged(_cerebroCore, true);

        poolConfigs[_priceLensUniswap] = PoolConfig({
            isActive: true,
            lastUpdateTime: 0
        });
        activePools.push(_priceLensUniswap);
        emit PoolStatusChanged(_priceLensUniswap, true);
    }

    // === FONCTIONS D'ADMINISTRATION (GOUVERNANCE) ===

    /// @notice Toggle updater authorization status.
    function setUpdaterStatus(address updater, bool isAuthorized) external onlyOwner {
        require(updater != address(0), "Oracle: Updater cannot be zero address");
        authorizedUpdaters[updater] = isAuthorized;
        emit UpdaterStatusChanged(updater, isAuthorized);
    }

    /// @notice Add a new tracking pool.
    function addPool(address pool) external onlyOwner {
        require(pool != address(0), "Oracle: Pool cannot be zero address");
        require(!poolConfigs[pool].isActive, "Oracle: Pool already active");
        
        poolConfigs[pool] = PoolConfig({
            isActive: true,
            lastUpdateTime: 0
        });
        activePools.push(pool);
        emit PoolStatusChanged(pool, true);
    }

    /// @notice Deactivate an existing pool.
    function deactivatePool(address pool) external onlyOwner poolExists(pool) {
        poolConfigs[pool].isActive = false;
        
        for (uint256 i = 0; i < activePools.length; i++) {
            if (activePools[i] == pool) {
                activePools[i] = activePools[activePools.length - 1];
                activePools.pop();
                break;
            }
        }
        emit PoolStatusChanged(pool, false);
    }

    /// @notice Transfer contract ownership.
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Oracle: New owner is zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice Update infrastructure addresses in case of migration.
    function updateEcosystemAddresses(address _safeVault, address _cerebroCore, address _priceLensUniswap) external onlyOwner {
        require(_safeVault != address(0) && _cerebroCore != address(0) && _priceLensUniswap != address(0), "Oracle: Invalid address");
        
        safeVault = _safeVault;
        cerebroCore = _cerebroCore;
        priceLensUniswap = _priceLensUniswap;
        
        emit EcosystemAddressesUpdated(_safeVault, _cerebroCore, _priceLensUniswap);
    }

    // === FONCTIONS DE MISE À JOUR (ÉCRITURE) ===

    /// @notice Push a new price update for a target pool.
    /* solhint-disable not-rely-on-time */
    function updatePrice(address pool, uint256 price) external onlyUpdater poolExists(pool) nonReentrant {
        PoolConfig storage config = poolConfigs[pool];
        
        require(block.timestamp >= config.lastUpdateTime + UPDATE_INTERVAL, "Oracle: Update too frequent");
        require(price >= MIN_PRICE_LIMIT && price <= MAX_PRICE_LIMIT, "Oracle: Price outlier rejected");
        
        uint256 lastPrice = latestPrice[pool].price;
        if (lastPrice > 0) {
            uint256 deviation;
            if (price > lastPrice) {
                deviation = ((price - lastPrice) * 10000) / lastPrice;
            } else {
                deviation = ((lastPrice - price) * 10000) / lastPrice;
            }
            require(deviation <= MAX_DEVIATION_BPS, "Oracle: Excessive price deviation detected");
        }

        latestPrice[pool] = PriceData({
            price: price,
            timestamp: block.timestamp,
            blockNumber: block.number,
            submittedBy: msg.sender
        });

        uint256 key = block.timestamp / 1 hours;
        priceHistory[pool][key] = latestPrice[pool];
        config.lastUpdateTime = block.timestamp;

        emit PriceUpdated(pool, price, block.timestamp, msg.sender);
    }
    /* solhint-enable not-rely-on-time */

    // === FONCTIONS DE LECTURE (VIEW) ===

    /// @notice Read current price with stale data protection.
    /* solhint-disable not-rely-on-time */
    function getPrice(address pool) external view poolExists(pool) returns (uint256 price, uint256 timestamp, address submittedBy) {
        PriceData memory data = latestPrice[pool];
        require(block.timestamp <= data.timestamp + STALE_PRICE_THRESHOLD, "Oracle: Stale price data detected");
        return (data.price, data.timestamp, data.submittedBy);
    }
    /* solhint-enable not-rely-on-time */

    /// @notice Get historical hourly logged price.
    function getHistoricalPrice(address pool, uint256 hourKey) external view returns (uint256 price, uint256 timestamp) {
        PriceData memory data = priceHistory[pool][hourKey];
        return (data.price, data.timestamp);
    }

    /// @notice Returns list of all active pools.
    function getActivePools() external view returns (address[] memory) { return activePools; }
    
    /// @notice Returns count of active pools.
    function getPoolCount() external view returns (uint256) { return activePools.length; }
    
    /// @notice Returns status of a specific pool.
    function isPoolActive(address pool) external view returns (bool) { return poolConfigs[pool].isActive; }
    
    /// @notice Checks if an address is an authorized updater.
    function isAuthorizedUpdater(address updater) external view returns (bool) { return authorizedUpdaters[updater]; }
}
