// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.09.30
pragma solidity 0.8.6;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface ixUnionSwapPair is IERC20{

    function mintXLp(address _account,uint256 _value) external ;
    function burnXLp(address _account,uint256 _value) external ;
    // --------------------- Info function ---------------------
    function sync() external;

}
