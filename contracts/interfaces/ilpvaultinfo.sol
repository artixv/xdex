// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30
pragma solidity ^0.8.0;

interface iLpVaultInfo{

     function initialLpOwner(address lp) external view returns (address);
     function initLpAmount(address lp) external view returns (uint);

}
