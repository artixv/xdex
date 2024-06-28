// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../xunionswappair.sol';

contract mockerc20 is ERC20 {
    constructor(uint _totalSupply,string memory name,string memory symbol) ERC20(name,symbol) {
        _mint(msg.sender, _totalSupply);
    }
}
