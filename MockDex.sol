// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract MockDex {
    IERC20Metadata public tokenA; // Votre Jeton (souvent 18 décimales)
    IERC20Metadata public tokenB; // Mock USDC (6 décimales)

    uint256 public reserveA;
    uint256 public reserveB;

    event LiquidityAdded(uint256 amountA, uint256 amountB);
    event Swapped(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20Metadata(_tokenA);
        tokenB = IERC20Metadata(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(amountA, amountB);
    }

    function swap(address tokenIn, uint256 amountIn) external {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");
        
        bool isTokenA = tokenIn == address(tokenA);
        IERC20Metadata tIn = isTokenA ? tokenA : tokenB;
        IERC20Metadata tOut = isTokenA ? tokenB : tokenA;
        uint256 rIn = isTokenA ? reserveA : reserveB;
        uint256 rOut = isTokenA ? reserveB : reserveA;

        tIn.transferFrom(msg.sender, address(this), amountIn);

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * rOut;
        uint256 denominator = (rIn * 1000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        tOut.transfer(msg.sender, amountOut);

        if (isTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        emit Swapped(msg.sender, tokenIn, amountIn, amountOut);
    }

    // Renvoie le prix avec une précision à 18 décimales (Format standard de Oracle)
    function getPrice(address token) external view returns (uint256) {
        require(reserveA > 0 && reserveB > 0, "No liquidity");
        uint256 decA = 10**tokenA.decimals();
        uint256 decB = 10**tokenB.decimals();

        if (token == address(tokenA)) {
            // Calcule le prix de A exprimé en B (ex: combien de mUSDC par Jeton)
            return (reserveB * decA * 1e18) / (reserveA * decB);
        } else {
            // Calcule le prix de B exprimé en A
            return (reserveA * decB * 1e18) / (reserveB * decA);
        }
    }
}
