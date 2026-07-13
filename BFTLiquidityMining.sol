// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

abstract contract ReentrancyGuard {
    uint256 private _status = 1;
    modifier nonReentrant() {
        require(_status != 2, "REENTRANCY_GUARD");
        _status = 2;
        _;
        _status = 1;
    }
}

abstract contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() { owner = msg.sender; }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Adresse invalide");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract BFTLiquidityMining5Years is ReentrancyGuard, Ownable {
    IERC20 public immutable bftToken;            
    IERC721 public immutable uniswapV4PositionManager; 

    uint256 public rewardRate;                   
    uint256 public periodFinish;                 
    uint256 public rewardDuration;               
    uint256 public lastUpdateTime;               
    uint256 public rewardPerLiquidityStored;     

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;  

    mapping(address => uint256) public totalUserLiquidity; 
    uint256 public totalLiquidityInPool;                   
    mapping(uint256 => address) public positionOwners;     

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 tokenId, uint256 liquidityAmount);
    event Withdrawn(address indexed user, uint256 tokenId);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _bftToken, address _uniswapV4PositionManager) {
        bftToken = IERC20(_bftToken);
        uniswapV4PositionManager = IERC721(_uniswapV4PositionManager);
    }

    modifier updateReward(address account) {
        rewardPerLiquidityStored = rewardPerLiquidity();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerLiquidityStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerLiquidity() public view returns (uint256) {
        if (totalLiquidityInPool == 0) {
            return rewardPerLiquidityStored;
        }
        return rewardPerLiquidityStored + (
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalLiquidityInPool
        );
    }

    function earned(address account) public view returns (uint256) {
        return ((totalUserLiquidity[account] * (rewardPerLiquidity() - userRewardPerTokenPaid[account])) / 1e18) + rewards[account];
    }

    function stakePosition(uint256 tokenId, uint256 liquidityAmount) external nonReentrant updateReward(msg.sender) {
        require(liquidityAmount > 0, "La liquidite doit etre superieure a 0");
        uniswapV4PositionManager.transferFrom(msg.sender, address(this), tokenId);
        
        positionOwners[tokenId] = msg.sender;
        totalUserLiquidity[msg.sender] += liquidityAmount;
        totalLiquidityInPool += liquidityAmount;

        emit Staked(msg.sender, tokenId, liquidityAmount);
    }

    function withdrawPosition(uint256 tokenId, uint256 liquidityAmount) external nonReentrant updateReward(msg.sender) {
        require(positionOwners[tokenId] == msg.sender, "Ce NFT ne vous appartient pas");

        totalUserLiquidity[msg.sender] -= liquidityAmount;
        totalLiquidityInPool -= liquidityAmount;
        delete positionOwners[tokenId];

        uniswapV4PositionManager.transferFrom(address(this), msg.sender, tokenId);

        emit Withdrawn(msg.sender, tokenId);
    }

    function claimReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            bftToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /**
     * @notice Lance officiellement la distribution des 24 millions pour 5 ans
     * @param rewardMontant Mettre exactement : 24000000000000000000000000
     * @param _rewardDuration Mettre exactement : 157680000
     */
    function notifyRewardAmount(uint256 rewardMontant, uint256 _rewardDuration) external onlyOwner updateReward(address(0)) {
        require(block.timestamp >= periodFinish, "La session precedente n'est pas terminee");
        require(rewardMontant > 0, "Le montant doit etre superieur a 0");

        rewardDuration = _rewardDuration;
        bftToken.transferFrom(msg.sender, address(this), rewardMontant);

        rewardRate = rewardMontant / rewardDuration;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardDuration;

        emit RewardAdded(rewardMontant);
    }
}

