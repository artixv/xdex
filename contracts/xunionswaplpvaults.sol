// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.07.30
// 保存首次mint的lp；

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ilpvaultinfo.sol";

contract xUnionSwapLpVaults{
    //----------------------Persistent Variables ----------------------
    address public lpManager;
    address public setter;
    address newsetter;
    uint public lpTimeLimit;
    mapping (address => uint) public lpInitTime;

    modifier onlyLpSetter() {
        require(msg.sender == setter, 'X SWAP Vaults: Only Lp Manager Use');
        _;
    }

    //----------------------------- event -----------------------------
    event InitialLpRedeem(address _lp,address reseiver,uint _amount);

    //-------------------------- constructor --------------------------
    constructor() {
        setter = msg.sender;
        lpTimeLimit = 604800;// 7 days
    }
    function systemSetup(address _lpManager) external onlyLpSetter{
            lpManager = _lpManager;
    }
    function timeLimitSetup(uint _lpTimeLimit) external onlyLpSetter{
            lpTimeLimit = _lpTimeLimit;
    }

    function transferLpSetter(address _set) external onlyLpSetter{
        newsetter = _set;
    }
    function acceptLpSetter(bool _TorF) external {
        require(msg.sender == newsetter, 'X Swap Lp Vaults: Permission FORBIDDEN');
        if(_TorF){
            setter = newsetter;
        }
        newsetter = address(0);
    }

    function initialTimeLimit(address _lpManager) external onlyLpSetter{
            lpManager = _lpManager;
    }

    function exceptionTransfer(address recipient) external onlyLpSetter{
        require(address(this).balance>0,"X Swap Lp Vaults: Insufficient amount");
        transferCFX(recipient,address(this).balance);
    }
    function transferCFX(address _recipient,uint256 _amount) private {
        require(address(this).balance>=_amount,"X Swap Lp Vaults: Exceed the storage CFX balance");
        address payable receiver = payable(_recipient); // Set receiver
        (bool success, ) = receiver.call{value:_amount}("");
        require(success,"X Swap LpManager: CFX Transfer Failed");
    }

    function setInitTime(address _lp) external {
        require(lpManager == msg.sender,"X SWAP Lp Vaults: msg.sender is NOT the lpManager");
        require(lpInitTime[_lp] == 0,"X SWAP Lp Vaults: lpInitTime have been Initialized ");
        lpInitTime[_lp] = block.timestamp;

    }
    
    function initialLpRedeem(address _lp) external returns(uint _amount){
        require(lpInitTime[_lp] + lpTimeLimit > block.timestamp,"X SWAP Lp Vaults: Time Limit");
        require(iLpVaultInfo(lpManager).initialLpOwner(_lp) == msg.sender,"X SWAP Lp Vaults: msg.sender is NOT the initial LP owner");
        require(IERC20(_lp).balanceOf(address(this))==IERC20(_lp).totalSupply(),"X SWAP Lp Vaults: Other liquidity must be fully redeemed");
        _amount = iLpVaultInfo(lpManager).initLpAmount(_lp);
        IERC20(_lp).transfer(msg.sender,_amount);
        emit InitialLpRedeem( _lp, msg.sender, _amount);
    }

    function initialLpRedeemLimits(address _lp) external onlyLpSetter returns(uint _amount){
        require(lpInitTime[_lp] + lpTimeLimit > block.timestamp,"X SWAP Lp Vaults: Time Limit");
        require(iLpVaultInfo(lpManager).initialLpOwner(_lp) == msg.sender,"X SWAP Lp Vaults: msg.sender is NOT the initial LP owner");
        _amount = iLpVaultInfo(lpManager).initLpAmount(_lp);
        require(IERC20(_lp).balanceOf(address(this))>=_amount,"X SWAP Lp Vaults: liquidity must be adequate");
        IERC20(_lp).transfer(iLpVaultInfo(lpManager).initialLpOwner(_lp),_amount);
        emit InitialLpRedeem( _lp,iLpVaultInfo(lpManager).initialLpOwner(_lp), _amount);
    }
    // ======================== contract base methods =====================
    fallback() external payable {}
    receive() external payable {}
}