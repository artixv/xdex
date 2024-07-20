// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

// Save all assets and enter and exit assets by calling the core's algorithm swap 
// or increasing||decreasing lp through lpmanager;
// All information of the currency pairs is also saved in this contract
// Asset prices save the latest and old prices of the current block, 
// restrict calls to the same block except for interface contracts to prevent general lightning loan attacks

pragma solidity ^0.8.0;
import "./libraries/structlibrary.sol";
import "./interfaces/ixunionswappair.sol";
import "./interfaces/ixunionfactory.sol";
import "./xunionswapcore.sol";

contract xUnionSwapVaults{
    //----------------------Persistent Variables ----------------------
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    
    address public slc;
    address public lpManager;
    address public factory;
    address public core;
    address public setter;
    address newsetter;
    mapping (address=>bool) public xInterface;

    mapping (address=>structlibrary.reserve) public reserves;
    mapping (address=>uint) public relativeTokenUpperLimit;//init is 1 ether

    mapping (address => mapping(address => address)) public getPair;
    mapping (address => address) public getCoinToStableLpPair;
    address[] public allPairsInVault;

    uint latestBlockNumber;

    //----------------------------modifier ----------------------------
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'X SWAP Vaults: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    modifier onlyLpManager() {
        require(msg.sender == lpManager, 'X SWAP Vaults: Only Lp Manager Use');
        _;
    }
    modifier onlyLpSetter() {
        require(msg.sender == setter, 'X SWAP Vaults: Only Lp setter Use');
        _;
    }
    modifier onlyCoreAddress() {
        require(core == msg.sender, 'X Swap Vaults: Permission FORBIDDEN');
        _;
    }
    

    //-------------------------- constructor --------------------------
    constructor() {
        setter = msg.sender;
    }
    //----------------------------- event -----------------------------
    event XUnionExchange(address indexed inputToken, address indexed outputToken,uint inputAmount,uint outputAmount);
    //----------------------------- ----- -----------------------------

    function systemSetup(address _slc,address _lpManager,address _factory,address _core) external onlyLpSetter{
            slc = _slc;
            lpManager = _lpManager;
            factory = _factory;
            core = _core;
    }

    function xInterfacesetting(address _xInterface, bool _ToF)external onlyLpSetter{
        xInterface[_xInterface] = _ToF;
    }

    function transferLpSetter(address _set) external onlyLpSetter{
        newsetter = _set;
    }
    function acceptLpSetter(bool _TorF) external {
        require(msg.sender == newsetter, 'X Swap Vaults: Permission FORBIDDEN');
        if(_TorF){
            setter = newsetter;
        }
        newsetter = address(0);
    }
    function exceptionTransfer(address recipient) external onlyLpSetter{
        require(address(this).balance>0,"X Swap Vaults: Insufficient amount");
        transferCFX(recipient,address(this).balance);
    }
    function transferCFX(address _recipient,uint256 _amount) private {
        require(address(this).balance>=_amount,"X Swap Vaults: Exceed the storage CFX balance");
        address payable receiver = payable(_recipient); // Set receiver
        (bool success, ) = receiver.call{value:_amount}("");
        require(success,"X Swap Vaults: CFX Transfer Failed");
    }
    //----------------------------------------onlyLpManager Use Function------------------------------
    function creatLpVault(address _lp,address[2] memory _tokens,uint8 lpCategory) external onlyLpManager{
        require(reserves[_lp].assetAddr[0] == address(0),"X Swap Vaults: Already Have the Lp");

        reserves[_lp].assetAddr[0] = _tokens[0];
        reserves[_lp].assetAddr[1] = _tokens[1];
        reserves[_lp].category = lpCategory;
        IERC20(_tokens[0]).approve(lpManager, 99999999999999999999999999999999999999 ether);
        IERC20(_tokens[1]).approve(lpManager, 99999999999999999999999999999999999999 ether);
        allPairsInVault.push(_lp);
        getPair[_tokens[0]][_tokens[1]] = _lp;
        getPair[_tokens[1]][_tokens[0]] = _lp;
        if(lpCategory == 1){
            getCoinToStableLpPair[_tokens[0]]  = _lp;
        }
    }

    function increaseLpAmount(address _lp,uint[2] memory _reserveIn,uint _lpAdd) external onlyLpManager{
        require(reserves[_lp].assetAddr[0] != address(0),"X Swap Vaults: Cant be Zero Tokens");
        address[2] memory reserveAddr = getLpPair( _lp) ;

        uint[2] memory totalTokenInVaults;
        totalTokenInVaults[0] = IERC20(reserveAddr[0]).balanceOf(address(this)) - _reserveIn[0];
        totalTokenInVaults[1] = IERC20(reserveAddr[1]).balanceOf(address(this)) - _reserveIn[1];

        if(reserves[_lp].reserve[0]==0 && reserves[_lp].reserve[1]==0){
            if(relativeTokenUpperLimit[reserveAddr[0]] == 0){
                reserves[_lp].reserve[0] = 1 ether;
                relativeTokenUpperLimit[reserveAddr[0]] = 1 ether;
            }else {
                // require(totalTokenInVaults[0]>0, "X Swap Vaults:totalTokenInVaults need >0");
                reserves[_lp].reserve[0] += _reserveIn[0] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
                relativeTokenUpperLimit[reserveAddr[0]] += _reserveIn[0] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            }
            if(relativeTokenUpperLimit[reserveAddr[1]] == 0){
                reserves[_lp].reserve[1] = 1 ether;
                relativeTokenUpperLimit[reserveAddr[1]] = 1 ether;
            }else{
                // require(totalTokenInVaults[1]>0, "X Swap Vaults:totalTokenInVaults need >0");
                reserves[_lp].reserve[1] += _reserveIn[1] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
                relativeTokenUpperLimit[reserveAddr[1]] += _reserveIn[1] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            }
            
            reserves[_lp].totalSupply = _lpAdd;
            reserves[_lp].priceCumulative[0] = _reserveIn[1];
            reserves[_lp].priceCumulative[1] = _reserveIn[0];

        }else{// this mode priceCumulative not change
            require(totalTokenInVaults[0]>0 && totalTokenInVaults[1]>0,"X Swap Vaults: total Token In Vaults Need > 0");
            reserves[_lp].reserve[0] += _reserveIn[0] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            reserves[_lp].reserve[1] += _reserveIn[1] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            relativeTokenUpperLimit[reserveAddr[0]] += _reserveIn[0] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            relativeTokenUpperLimit[reserveAddr[1]] += _reserveIn[1] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            reserves[_lp].totalSupply += _lpAdd;
        }
        
    }
    function dereaseLpAmount(address _lp,uint[2] memory _reserveOut,uint _lpDel) external onlyLpManager{
        address[2] memory reserveAddr = getLpPair( _lp) ;
        uint[2] memory totalTokenInVaults;
        totalTokenInVaults[0] = IERC20(reserveAddr[0]).balanceOf(address(this)) + _reserveOut[0];//getLpTokenSum( _lp);//
        totalTokenInVaults[1] = IERC20(reserveAddr[1]).balanceOf(address(this)) + _reserveOut[1];
        require(totalTokenInVaults[0]>0&&totalTokenInVaults[1]>0,"X Swap Vaults: Vaults have NO reserve");
        reserves[_lp].reserve[0] -= _reserveOut[0] * relativeTokenUpperLimit[reserveAddr[0]]/totalTokenInVaults[0];
        reserves[_lp].reserve[1] -= _reserveOut[1] * relativeTokenUpperLimit[reserveAddr[1]]/totalTokenInVaults[1];
        relativeTokenUpperLimit[reserveAddr[0]] -= _reserveOut[0] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
        relativeTokenUpperLimit[reserveAddr[1]] -= _reserveOut[1] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
        reserves[_lp].totalSupply -= _lpDel;
    }
    function lpSettings(address _lp, uint32 _balanceFee, uint _a0) external onlyLpManager{
        require(_balanceFee <= 500,"X Swap Vaults: balance fee cant > 5%");
        reserves[_lp].balanceFee =_balanceFee;
        reserves[_lp].a0 = _a0;
    }
    function addTokenApproveToLpManager(address _token) external onlyLpManager{     
        IERC20(_token).approve(lpManager, 99999999999999999999999999999999999999 ether);
    }
    //----------------------------------------Parameters Function------------------------------

    function lengthOfPairsInVault() external view returns (uint) {
        return (allPairsInVault.length);
    }
    function getLpReserve(address _lp) external view returns (uint[2] memory ,uint[2] memory, uint ) {
        require(_lp!=address(0),"X Swap Vaults: cant be 0 address");
        address[2] memory reserveAddr = getLpPair( _lp) ;
        uint[2] memory TokenInVaults;
        if(reserveAddr[0]==address(0)){
            return (TokenInVaults, reserves[_lp].priceCumulative, reserves[_lp].totalSupply);
        }
        if(relativeTokenUpperLimit[reserveAddr[0]] == 0){
            TokenInVaults[0] = 0;
            TokenInVaults[1] = 0;
        }else{
            TokenInVaults[0] = reserves[_lp].reserve[0] * IERC20(reserveAddr[0]).balanceOf(address(this)) / relativeTokenUpperLimit[reserveAddr[0]];
            TokenInVaults[1] = reserves[_lp].reserve[1] * IERC20(reserveAddr[1]).balanceOf(address(this)) / relativeTokenUpperLimit[reserveAddr[1]];
        }
                
        return (TokenInVaults, reserves[_lp].priceCumulative, reserves[_lp].totalSupply);
    }

    function getLpTokenSum(address _lp) public view returns (uint[2] memory totalTokenInVaults){
        address[2] memory reserveAddr = getLpPair( _lp) ;
        totalTokenInVaults[0] = IERC20(reserveAddr[0]).balanceOf(address(this));
        totalTokenInVaults[1] = IERC20(reserveAddr[1]).balanceOf(address(this));
    }

    function getLpPrice(address _lp) external view returns (uint price){
        require(_lp!=address(0),"X Swap Vaults: cant be 0 address");
        if(reserves[_lp].priceCumulative[1] == 0){
            price = 0;
        }else{
            price = reserves[_lp].priceCumulative[0]* 1 ether/reserves[_lp].priceCumulative[1];
        }
    }
    function getLpPair(address _lp) public view returns (address[2] memory){
        return reserves[_lp].assetAddr;
    }
    function getLpInputTokenSlot(address _lp,address _inputToken) public view returns (bool slot){
        if(_inputToken == reserves[_lp].assetAddr[0]){
            slot = true;
        }else{
            slot = false;
        }
    }
    function getLpSettings(address _lp) external view returns(uint32 balanceFee, uint a0){
        balanceFee = reserves[_lp].balanceFee;
        a0 = reserves[_lp].a0;
    }
    //----------------------------------------Exchange Function------------------------------
    function xexchange(address[] memory tokens,uint amountIn,uint amountOut,uint limits,uint deadline) external returns(uint){
        structlibrary.exVaults memory _exVaults;
        _exVaults.tokens = tokens;
        _exVaults.amountIn = amountIn;
        _exVaults.amountOut = amountOut;
        _exVaults.Limits = limits;
        return exchange(_exVaults,deadline);
    }

    function exchange(structlibrary.exVaults memory _exVaults,uint deadline) public lock returns(uint){
        if(xInterface[msg.sender] == false){
            require(latestBlockNumber < block.number,"X Swap Vaults: Same block can't have Two exchange");
        }
        latestBlockNumber = block.number;
        require(block.timestamp <= deadline,"X Swap Vaults: deadline exceed");
        uint[4] memory b;
        uint[4] memory inputAmount;
        uint[4] memory outputAmount;
        uint[2] memory tempReserve;
        address[] memory _lp = new address[](_exVaults.tokens.length);
        // uint[2] memory totalTokenInVaults;
        // address[2] memory reserveAddr;// = getLpPair( _lp) ;
        uint i;
        
        require(_exVaults.tokens.length>1&&_exVaults.tokens.length<=5,"X Swap Vaults: exceed MAX path lengh:2~5");
        inputAmount[0] = IERC20(_exVaults.tokens[0]).balanceOf(address(this));
        IERC20(_exVaults.tokens[0]).transferFrom(msg.sender,address(this),_exVaults.amountIn);
        outputAmount[0] = IERC20(_exVaults.tokens[0]).balanceOf(address(this)) - inputAmount[0];
        require( outputAmount[0] > 0,"X Swap Vaults: Input need > 0");
        for(i=0;i<_exVaults.tokens.length-1;i++){
            if(i==0){
                inputAmount[i] = outputAmount[i];
            }else{
                inputAmount[i] = outputAmount[i-1];
            }
            
            _lp[i]=iXunionFactory(factory).getPair(_exVaults.tokens[i], _exVaults.tokens[i+1]);
            (outputAmount[i],tempReserve,reserves[_lp[i]].priceCumulative,b[i]) = 
            xUnionSwapCore(core).swapCalculation(_lp[i],_exVaults.tokens[i],inputAmount[i],i); //external view returns
            amountToReserves( _exVaults.tokens[i],  _lp[i], inputAmount[i], outputAmount[i], i) ;
            // totalTokenInVaults = getLpTokenSum( _lp[i]);
            // reserveAddr = getLpPair( _lp[i]) ;
            // if(getLpInputTokenSlot(_lp[i],_exVaults.tokens[i])){
            //     if(i==0){
            //         totalTokenInVaults[0] -= inputAmount[i];
            //     }
            //     reserves[_lp[i]].reserve[0] += inputAmount[i] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            //     relativeTokenUpperLimit[reserveAddr[0]] += inputAmount[i] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            //     reserves[_lp[i]].reserve[1] -= outputAmount[i] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            //     relativeTokenUpperLimit[reserveAddr[1]] -= outputAmount[i] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            // }else{
            //     if(i==0){
            //         totalTokenInVaults[1] -= inputAmount[i];
            //     }
            //     reserves[_lp[i]].reserve[1] += inputAmount[i] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            //     relativeTokenUpperLimit[reserveAddr[1]] += inputAmount[i] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            //     reserves[_lp[i]].reserve[0] -= outputAmount[i] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            //     relativeTokenUpperLimit[reserveAddr[0]] -= outputAmount[i] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            // }

            emit XUnionExchange(_exVaults.tokens[i], _exVaults.tokens[i+1], inputAmount[i], outputAmount[i]);  
        }
        if(outputAmount[_exVaults.tokens.length-2] >= _exVaults.amountOut){
            require(outputAmount[_exVaults.tokens.length-2] <= _exVaults.amountOut + _exVaults.Limits,"X Swap Vaults: exceed user setting Limits");
        }else{
            require(outputAmount[_exVaults.tokens.length-2] + _exVaults.Limits >= _exVaults.amountOut,"X Swap Vaults: exceed user setting Limits");
        }

        // xUnionSwapCore(core).afterSwap(_exVaults,b);
        
        IERC20(_exVaults.tokens[_exVaults.tokens.length-1]).transfer(msg.sender,outputAmount[_exVaults.tokens.length-2]);
        return outputAmount[_exVaults.tokens.length-2];
        // xUnionSwapCore(core).afterSwap2(_exVaults,a,b);
        
    }

    function amountToReserves(address token, address _lp, uint inputAmount, uint outputAmount, uint i) internal {
        uint[2] memory totalTokenInVaults;
        address[2] memory reserveAddr;// = getLpPair( _lp) ;
        totalTokenInVaults = getLpTokenSum( _lp);
        reserveAddr = getLpPair( _lp) ;
        if(getLpInputTokenSlot(_lp,token)){
            if(i==0){
                totalTokenInVaults[0] -= inputAmount;
            }
            reserves[_lp].reserve[0] += inputAmount * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            relativeTokenUpperLimit[reserveAddr[0]] += inputAmount * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            reserves[_lp].reserve[1] -= outputAmount * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            relativeTokenUpperLimit[reserveAddr[1]] -= outputAmount * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
        }else{
            if(i==0){
                totalTokenInVaults[1] -= inputAmount;
            }
            reserves[_lp].reserve[1] += inputAmount * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            relativeTokenUpperLimit[reserveAddr[1]] += inputAmount * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            reserves[_lp].reserve[0] -= outputAmount * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            relativeTokenUpperLimit[reserveAddr[0]] -= outputAmount * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
        }
    }

    // ======================== contract base methods =====================
    
    fallback() external payable {}
    receive() external payable {}

}