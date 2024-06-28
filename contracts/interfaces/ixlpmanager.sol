// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;

interface ixLpManager{
    function xLpSubscribe(address _lp,uint[2] memory _amountEstimated) external returns(uint[2] memory _amountActual,uint _amountLp);
    function xLpRedeem(address _lp,uint _amountLp) external returns(uint[2] memory _amount);
}