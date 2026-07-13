// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    // Les vrais stablecoins utilisent souvent 6 décimales
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function decimals() override public pure returns (uint8) {
        return 6; 
    }

    // Permet à n'importe qui de générer des jetons pour les tests
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
