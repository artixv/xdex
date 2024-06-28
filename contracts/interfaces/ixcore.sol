// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

pragma solidity ^0.8.0;
interface ixCore{
    function swapCalculation2(address _lp,address _inputToken,uint _inputAmount)external view returns (uint _outputAmount,uint[2] memory reserve,uint[2] memory priceCumulative,uint b);
    function swapCalculation3(address _lp,address _inputToken,uint _inputAmount)external view returns (uint _outputAmount,uint[2] memory reserve,uint[2] memory priceCumulative,uint b);
}