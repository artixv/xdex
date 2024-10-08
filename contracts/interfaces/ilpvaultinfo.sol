// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.09.30
pragma solidity 0.8.6;

interface iLpVaultInfo{

     function initialLpOwner(address lp) external view returns (address);
     function initLpAmount(address lp) external view returns (uint);

}
