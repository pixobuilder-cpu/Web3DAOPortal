// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title OpenZeppelin & Custom Safe Integrations
 * @dev Fully independent implementations of SafeERC20 and Address primitives to maximize security.
 */
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IBigfootRegistry {
    function hasRole(bytes32 role, address account) external view returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(token.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: low-level transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SafeERC20: low-level transferFrom failed");
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title CEREBRO CORE: ENTERPRISE GRADE AI AUTOMATION ENGINE
 * @notice Secured automation hub featuring zero-address guards, SafeERC20 compliance, and explicit execution limits.
 */
contract CerebroCore is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- Access Control Identifiers ---
    bytes32 public constant CEREBRO_AI_EXECUTOR = keccak256("CEREBRO_AI_EXECUTOR");
    bytes32 public constant CEREBRO_GOVERNOR = keccak256("CEREBRO_GOVERNOR");

    // --- Core Architecture Configurations ---
    IBigfootRegistry public immutable registry;
    IERC20 public immutable bft;
    IERC20 public immutable wbft;
    address public immutable safeVault;

    // --- Storage Matrix ---
    struct UserAccount {
        uint256 balanceBFT;
        uint256 balanceWBFT;
        uint256 totalPaidForAI;
    }

    struct AIService {
        uint256 costInBFT;
        uint256 costInWBFT;
        bool isAvailable;
    }

    mapping(address => UserAccount) private _userAccounts;
    mapping(string => AIService) private _aiServices;
    mapping(address => bool) private _whitelistedTargetContracts;

    // --- Events ---
    event FundsDeposited(address indexed user, address indexed token, uint256 amount);
    event FundsWithdrawn(address indexed user, address indexed token, uint256 amount);
    event AIServiceTriggered(address indexed user, string indexed serviceKey, uint256 costPaid, bool isWBFT);
    event AIServiceConfigured(string indexed serviceKey, uint256 costBFT, uint256 costWBFT, bool status);
    event AIAutomatedActionExecuted(string indexed actionType, address indexed targetContract);
    event TargetWhitelistUpdated(address indexed target, bool status);

    // --- Definitive Access Gateways ---
    modifier onlyAI() {
        require(registry.hasRole(CEREBRO_AI_EXECUTOR, msg.sender), "Cerebro: Caller is not an authorized AI Agent");
        _;
    }

    modifier onlyGovernor() {
        require(registry.hasRole(CEREBRO_GOVERNOR, msg.sender) || msg.sender == safeVault, "Cerebro: Unauthorized Governor");
        _;
    }

    constructor(address _registry, address _bft, address _wbft, address _safeVault) {
        require(_registry != address(0), "Cerebro: Registry cannot be the zero address");
        require(_bft != address(0), "Cerebro: BFT token cannot be the zero address");
        require(_wbft != address(0), "Cerebro: WBFT token cannot be the zero address");
        require(_safeVault != address(0), "Cerebro: Gnosis Safe vault cannot be the zero address");
        
        registry = IBigfootRegistry(_registry);
        bft = IERC20(_bft);
        wbft = IERC20(_wbft);
        safeVault = _safeVault;
    }

    // =========================================================================
    // PART 1: SECURED USER LEDGER SYSTEM (WITH SAFEEPCOUNTERS)
    // =========================================================================

    function depositFunds(uint256 amount, bool useWBFT) external nonReentrant {
        require(amount > 0, "Cerebro: Deposit amount must be greater than zero");
        
        if (useWBFT) {
            _userAccounts[msg.sender].balanceWBFT += amount;
            emit FundsDeposited(msg.sender, address(wbft), amount);
            wbft.safeTransferFrom(msg.sender, address(this), amount); // Handles non-standard returns safely
        } else {
            _userAccounts[msg.sender].balanceBFT += amount;
            emit FundsDeposited(msg.sender, address(bft), amount);
            bft.safeTransferFrom(msg.sender, address(this), amount); 
        }
    }

    function withdrawFunds(uint256 amount, bool useWBFT) external nonReentrant {
        require(amount > 0, "Cerebro: Withdrawal amount must be greater than zero");
        
        if (useWBFT) {
            require(_userAccounts[msg.sender].balanceWBFT >= amount, "Cerebro: Insufficient ledger balance");
            _userAccounts[msg.sender].balanceWBFT -= amount;
            emit FundsWithdrawn(msg.sender, address(wbft), amount);
            wbft.safeTransfer(msg.sender, amount);
        } else {
            require(_userAccounts[msg.sender].balanceBFT >= amount, "Cerebro: Insufficient ledger balance");
            _userAccounts[msg.sender].balanceBFT -= amount;
            emit FundsWithdrawn(msg.sender, address(bft), amount);
            bft.safeTransfer(msg.sender, amount);
        }
    }

    function billUserForAI(address user, string calldata serviceKey, bool chargeInWBFT) external onlyAI nonReentrant {
        require(user != address(0), "Cerebro: Target consumer account cannot be the zero address");
        require(bytes(serviceKey).length > 0, "Cerebro: Service key identifier cannot be empty");
        
        AIService memory service = _aiServices[serviceKey];
        require(service.isAvailable, "Cerebro: Requested automated service is offline");

        if (chargeInWBFT) {
            require(service.costInWBFT > 0, "Cerebro: AI Service cost cannot be zero");
            require(_userAccounts[user].balanceWBFT >= service.costInWBFT, "Cerebro: Insufficient billing assets available");
            
            _userAccounts[user].balanceWBFT -= service.costInWBFT;
            _userAccounts[user].totalPaidForAI += service.costInWBFT;
            
            emit AIServiceTriggered(user, serviceKey, service.costInWBFT, true);
            wbft.safeTransfer(safeVault, service.costInWBFT);
        } else {
            require(service.costInBFT > 0, "Cerebro: AI Service cost cannot be zero");
            require(_userAccounts[user].balanceBFT >= service.costInBFT, "Cerebro: Insufficient billing assets available");
            
            _userAccounts[user].balanceBFT -= service.costInBFT;
            _userAccounts[user].totalPaidForAI += service.costInBFT;
            
            emit AIServiceTriggered(user, serviceKey, service.costInBFT, false);
            bft.safeTransfer(safeVault, service.costInBFT);
        }
    }

    // =========================================================================
    // PART 2: ARBITRARY CALL MITIGATION FRAMEWORKS
    // =========================================================================

    function updateTargetWhitelist(address target, bool status) external onlyGovernor {
        require(target != address(0), "Cerebro: Whitelist targets cannot be zero address configurations");
        _whitelistedTargetContracts[target] = status;
        emit TargetWhitelistUpdated(target, status);
    }

    function executeAutonomousRebalance(
        address targetLiquidStaking, 
        bytes calldata transactionPayload
    ) external onlyAI nonReentrant {
        require(_whitelistedTargetContracts[targetLiquidStaking], "Cerebro: Targeted context contract unverified");
        
        // Strictly bounds execution down to exactly 500k gas units protecting state transition frameworks
        (bool success, bytes memory returnData) = targetLiquidStaking.call{gas: 500000}(transactionPayload);
        
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returndata_size := mload(returnData)
                    revert(add(32, returnData), returndata_size)
                }
            } else {
                revert("Cerebro: Internal external protocol interaction execution reverted");
            }
        }
        
        emit AIAutomatedActionExecuted("REBALANCE_LIQUIDITY", targetLiquidStaking);
    }

    function triggerAIProtectionCircuit(address contractToPause) external onlyAI nonReentrant {
        require(_whitelistedTargetContracts[contractToPause], "Cerebro: Protection execution target unverified");
        
        (bool success, bytes memory returnData) = contractToPause.call{gas: 100000}(abi.encodeWithSignature("pause()"));
        
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returndata_size := mload(returnData)
                    revert(add(32, returnData), returndata_size)
                }
            } else {
                revert("Cerebro: Emergency protective circuit activation reverted");
            }
        }
        emit AIAutomatedActionExecuted("EMERGENCY_PAUSE", contractToPause);
    }

    function configureAIService(string calldata serviceKey, uint256 costBFT, uint256 costWBFT, bool status) external onlyGovernor {
        require(bytes(serviceKey).length > 0, "Cerebro: Configured string service key cannot be empty");
        _aiServices[serviceKey] = AIService({
            costInBFT: costBFT,
            costInWBFT: costWBFT,
            isAvailable: status
        });
        emit AIServiceConfigured(serviceKey, costBFT, costWBFT, status);
    }

    // --- View Implementations ---

    function getUserAccount(address user) external view returns (uint256 balanceBFT, uint256 balanceWBFT, uint256 totalPaid) {
        UserAccount memory account = _userAccounts[user];
        return (account.balanceBFT, account.balanceWBFT, account.totalPaidForAI);
    }

    function isWhitelisted(address target) external view returns (bool) {
        return _whitelistedTargetContracts[target];
    }
}


