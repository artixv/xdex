// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;

interface ixLpVaults{
    function setInitTime(address _lp) external ;
    function initialLpRedeem(address _lp) external returns(uint _amount);
}