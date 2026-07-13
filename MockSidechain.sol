// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockSidechainToken is ERC20 {
    // Utilisez 18 décimales si votre vrai jeton de sidechain en utilise 18
    constructor() ERC20("Mock Sidechain Token", "mSIDE") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
