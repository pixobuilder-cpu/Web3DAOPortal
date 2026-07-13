// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MonJetonSidechain is ERC20 {
    // Le constructeur crée 1 million de jetons pour le déployeur
    constructor() ERC20("Mon Jeton Sidechain", "MJS") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}
