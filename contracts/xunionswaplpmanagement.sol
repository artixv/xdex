// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.09.30
/* Function:
1. Operate the casting and destruction of LP;
2. Inject the corresponding currency and quantity into the vault while destroying the LP casting;
3. Basic LP currency record, extended LP must have both basic currencies before casting
4. The first subscription of currency lp will be saved in lpvaults when it is created, 
   and the value of the paired lp currency needs to be no less than 1000 SLC
*/   
pragma solidity 0.8.6;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/structlibrary.sol";
import "./interfaces/ixunionswappair.sol";
import "./interfaces/ixunionfactory.sol";
import "./interfaces/ixvaults.sol";
import "./interfaces/ixlpvaults.sol";

contract xUnionSwapLpManager{
    using SafeERC20 for IERC20;

    //----------------------Persistent Variables ----------------------
    address public setPermissionAddress;
    address newPermissionAddress;
    address public factory;
    address public lpVault;
    address public xVaults;
    mapping(address => address) public  initialLpOwner;// lp--->owner
    mapping(address => uint) public initLpAmount;      // lp--->amount
    uint public minLpLimit;   //  1,000 

    //-------------------------- constructor --------------------------
    constructor(address _setPermissionAddress) {
        minLpLimit = 1000;
        setPermissionAddress = _setPermissionAddress;
    }
    //----------------------------modifier ----------------------------
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'X SWAP LpManager: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    modifier onlyPermissionAddress() {
        require(setPermissionAddress == msg.sender, 'X Swap LpManager: Permission FORBIDDEN');
        _;
    }
    //----------------------------- event -----------------------------
    event Settings(address _factory,address _vault,address _lpVault);
    event SettingMinLpLimit(uint _minLpLimit);
    event SetPA(address _setPermissionAddress);
    event AcceptPA(bool _TorF);
    event Subscribe(address indexed lp, address subscribeAddress, uint lpAmount);
    event Redeem(address indexed lp, address redeemAddress, uint lpAmount);
    event LpInfoSettings(address indexed lp, uint balanceFee, uint a0);
    //--------------------------- Setup functions --------------------------

    function settings(address _factory,address _vault,address _lpVault) external onlyPermissionAddress{
        factory = _factory;
        xVaults = _vault;
        lpVault = _lpVault;
        emit Settings(_factory, _vault, _lpVault);
    }
    function settingMinLpLimit(uint _minLpLimit) external onlyPermissionAddress{
        minLpLimit = _minLpLimit;
        emit SettingMinLpLimit( _minLpLimit);
    }

    function xLpInfoSettings(address _lp,uint32 _balanceFee, uint _a0) external onlyPermissionAddress{
         ixVaults(xVaults).lpSettings(_lp, _balanceFee, _a0) ;
         emit LpInfoSettings( _lp, _balanceFee, _a0);
    }
    function setPA(address _setPermissionAddress) external onlyPermissionAddress{
        newPermissionAddress = _setPermissionAddress;
        emit SetPA(_setPermissionAddress);
    }
    function acceptPA(bool _TorF) external {
        require(msg.sender == newPermissionAddress, 'X Swap LpManager: Permission FORBIDDEN');
        if(_TorF){
            setPermissionAddress = newPermissionAddress;
        }
        newPermissionAddress = address(0);
        emit AcceptPA(_TorF);
    }

    function addTokenApproveToLpManager(address _token) external onlyPermissionAddress{
       ixVaults(xVaults).addTokenApproveToLpManager(_token);
    }

    function exceptionTransfer(address recipient) external onlyPermissionAddress{
        require(address(this).balance>0,"X Swap LpManager: Insufficient amount");
        transferCFX(recipient,address(this).balance);
    }
    function transferCFX(address _recipient,uint256 _amount) private {
        require(address(this).balance>=_amount,"X Swap LpManager: Exceed the storage CFX balance");
        address payable receiver = payable(_recipient); // Set receiver
        (bool success, ) = receiver.call{value:_amount}("");
        require(success,"X Swap LpManager: CFX Transfer Failed");
    }

    //--------------------------- x Lp Subscribe & Redeem functions --------------------------

    function xLpSubscribe(address _lp,uint[2] memory _amountEstimated) external lock returns(uint[2] memory _amountActual,uint _amountLp){
        // structlibrary.reserve memory _lpDetails = ixVaults(xVaults).reserves(_lp);
        address[2] memory assetAddr;
        uint8 category;
        uint[2] memory reserve;           
        uint[2] memory priceCumulative;
        uint totalSupply;
        (assetAddr,category) = iXunionFactory(factory).getLpPairsDetails( _lp);
        (reserve,priceCumulative,totalSupply) = ixVaults(xVaults).getLpReserve( _lp);

        require(assetAddr[0] != address(0),"X SWAP LpManager: assetAddr can't be address(0) ");
        require(assetAddr[1] != address(0),"X SWAP LpManager: assetAddr can't be address(0) ");

        if(reserve[0]==0){// First LP, will transfer to LpVault, can redeem when on other Lps; 
            ixLpVaults(lpVault).setInitTime(_lp);
            require(reserve[1]==0,"X SWAP LpManager: two reserve MUST be ZERO");//first Lp, need a 1000 xusd amount
            if(category==1){
                require(_amountEstimated[1] >= minLpLimit * 1 ether,"X SWAP LpManager: First Lp need init SLC");
                require(_amountEstimated[0] >= 1000000,"X SWAP LpManager: Cant Be a too small amount");
                _amountLp = _amountEstimated[1];
                _amountActual[0] = _amountEstimated[0];
                _amountActual[1] = _amountEstimated[1];
            }else if(category==2) {

                _amountActual[0] = _amountEstimated[0] * ixVaults(xVaults).getLpPrice(iXunionFactory(factory).getCoinToStableLpPair(assetAddr[0]))/ 1 ether;

                _amountActual[1] = _amountEstimated[1] * ixVaults(xVaults).getLpPrice(iXunionFactory(factory).getCoinToStableLpPair(assetAddr[1]))/ 1 ether;

                require(_amountActual[0] >= minLpLimit * 1 ether && _amountActual[1] >= minLpLimit * 1 ether,"X SWAP LpManager: First Lp need init SLC Value");
                if(_amountActual[0]>=_amountActual[1]){
                    _amountLp = _amountActual[1];
                    _amountActual[0] = _amountActual[1] * 1 ether / ixVaults(xVaults).getLpPrice(iXunionFactory(factory).getCoinToStableLpPair(assetAddr[0]));
                    _amountActual[1] = _amountEstimated[1];
                }else{
                    _amountLp = _amountActual[0];
                    _amountActual[1] = _amountActual[0] * 1 ether / ixVaults(xVaults).getLpPrice(iXunionFactory(factory).getCoinToStableLpPair(assetAddr[1]));
                    _amountActual[0] = _amountEstimated[0];
                }
            }
            ixVaults(xVaults).lpSettings(_lp, 30, 0);
            ixVaults(xVaults).creatLpVault(_lp,assetAddr,category);//
        }else{// Subsequent LP addition, Lp will transfer to msg.sender; 
            _amountActual[0] = _amountEstimated[1]*reserve[0]/reserve[1];
            if(_amountActual[0]<=_amountEstimated[0]){
                _amountActual[1] = _amountEstimated[1];
            }else{
                _amountActual[0] = _amountEstimated[0];
                _amountActual[1] = _amountEstimated[0]*reserve[1]/reserve[0];
            }
            _amountLp = _amountActual[0] * totalSupply / reserve[0];
        }
        //here need add info change
        uint[2] memory totalTokenInVaults;
        totalTokenInVaults[0] = IERC20(assetAddr[0]).balanceOf(xVaults);
        totalTokenInVaults[1] = IERC20(assetAddr[1]).balanceOf(xVaults);

        IERC20(assetAddr[0]).safeTransferFrom(msg.sender,xVaults,_amountActual[0]);
        IERC20(assetAddr[1]).safeTransferFrom(msg.sender,xVaults,_amountActual[1]);

        require(_amountActual[0] == IERC20(assetAddr[0]).balanceOf(xVaults) - totalTokenInVaults[0],"X SWAP LpManager: Cannot compatible with tokens with transaction fees");
        require(_amountActual[1] == IERC20(assetAddr[1]).balanceOf(xVaults) - totalTokenInVaults[1],"X SWAP LpManager: Cannot compatible with tokens with transaction fees");

        ixVaults(xVaults).increaseLpAmount(_lp, _amountActual,_amountLp);
        
        if(reserve[0]==0){
            initialLpOwner[_lp] = msg.sender;
            initLpAmount[_lp] = _amountLp;
            ixUnionSwapPair(_lp).mintXLp(lpVault, _amountLp);
        }else{
            ixUnionSwapPair(_lp).mintXLp(msg.sender, _amountLp);
        }
        emit Subscribe(_lp, msg.sender, _amountLp);
        
    }

    function xLpRedeem(address _lp,uint _amountLp) external lock returns(uint[2] memory _amount){
        require(_lp != address(0),"X SWAP LpManager: _lp can't be address(0) ");
        require(_amountLp > 0,"X SWAP LpManager: _amountLp must > 0");
        address[2] memory assetAddr;
        uint8 category;
        uint[2] memory reserve;           
        uint totalSupply;
        (assetAddr,category) = iXunionFactory(factory).getLpPairsDetails( _lp);
        (reserve,,totalSupply) = ixVaults(xVaults).getLpReserve( _lp);
        IERC20(_lp).safeTransferFrom(msg.sender,address(this),_amountLp);
        ixUnionSwapPair(_lp).burnXLp(address(this), _amountLp);
        _amount[0] = reserve[0] * _amountLp /totalSupply;
        _amount[1] = reserve[1] * _amountLp /totalSupply;
        
        IERC20(assetAddr[0]).safeTransferFrom(xVaults,msg.sender,_amount[0]);
        IERC20(assetAddr[1]).safeTransferFrom(xVaults,msg.sender,_amount[1]);
        // resolved when Subscribe liquility, so here can omit this
        // require(reserve[0] == IERC20(assetAddr[0]).balanceOf(xVaults) + _amount[0],"X SWAP LpManager: Cannot compatible with tokens with transaction fees");
        // require(reserve[1] == IERC20(assetAddr[1]).balanceOf(xVaults) + _amount[1],"X SWAP LpManager: Cannot compatible with tokens with transaction fees");

        //here need add info change
        ixVaults(xVaults).dereaseLpAmount(_lp, _amount,_amountLp);
        emit Redeem(_lp, msg.sender, _amountLp);
    }
    // ======================== contract base methods =====================
    fallback() external payable {}
    receive() external payable {}
}