// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30

// Perform redemption operations and interact with vault and core

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ixunionfactory.sol";
import "./interfaces/ixvaults.sol";
import "./interfaces/ixlpvaults.sol";
import "./interfaces/ilpvaultinfo.sol";
import "./interfaces/ixlpmanager.sol";
import "./interfaces/ixcore.sol";
import "./interfaces/iwxcfx.sol";

pragma solidity ^0.8.0;

contract xUnionSwapUserInterface{
    address public xfactory;
    address public xvaults;
    address public xlpvaults;
    address public xlpmanager;
    address public xCore;

    address public wCFX;
    address public CFXMock;

    address public setter;
    address newsetter;

    mapping(address => address) public  initialLpOwner;// lp--->owner

    mapping(address => uint) public  UserLatestBlockNumber;//User can only have ONE exchange in one block


    //----------------------------modifier ----------------------------
    modifier onlyLpSetter() {
        require(msg.sender == setter, 'X SWAP Interface: Only Lp Manager Use');
        _;
    }

    constructor() {
        setter = msg.sender;
        CFXMock = address(0x0000000000000000000000000000000000000Cf0);
    }
    //----------------------------- ----- -----------------------------

    
    function systemSetup(address _factory,address _vaults,address _lpvaults,address _lpManager,address _xCore,address _wCFX) external onlyLpSetter{
            xfactory = _factory;
            xvaults = _vaults;
            xlpvaults = _lpvaults;
            xlpmanager = _lpManager;
            xCore = _xCore;
            wCFX = _wCFX;
    }

    function transferLpSetter(address _set) external onlyLpSetter{
        newsetter = _set;
    }
    function acceptLpSetter(bool _TorF) external {
        require(msg.sender == newsetter, 'X Swap Interface: Permission FORBIDDEN');
        if(_TorF){
            setter = newsetter;
        }
        newsetter = address(0);
    }

    // Operation function
    // Including 4 aspects:
    //   1. Create lp : interact with the factory
    //   2. Add or reduce lp : interact with lpmanager
    //   3. Exchange : interact with vaults
    //   4. Redemption of initial LP : interaction with LPvaults

    // factory
    function createPair(address tokenA,address tokenB) public returns (address) {
       return iXunionFactory(xfactory).createPair(tokenA, tokenB);
    }

    // lp manager
    function xLpSubscribe(address _lp,uint[2] memory _amountEstimated) public returns(uint[2] memory _amountActual,uint _amountLp) {
        uint[2] memory TokensAmount;
        (TokensAmount,, )= getLpReserve(_lp);
        if(TokensAmount[0]==0){
            initialLpOwner[_lp] = msg.sender;
        }
        address[2] memory TokensAddr;
        TokensAddr = getLpPair( _lp) ;

        IERC20(TokensAddr[0]).transferFrom(msg.sender,address(this),_amountEstimated[0]);
        IERC20(TokensAddr[1]).transferFrom(msg.sender,address(this),_amountEstimated[1]);
        IERC20(TokensAddr[0]).approve(xlpmanager, _amountEstimated[0]);
        IERC20(TokensAddr[1]).approve(xlpmanager, _amountEstimated[1]);
        (_amountActual,_amountLp) = ixLpManager(xlpmanager).xLpSubscribe(_lp,_amountEstimated);
        IERC20(_lp).transfer(msg.sender,IERC20(_lp).balanceOf(address(this)));
        if(IERC20(TokensAddr[0]).balanceOf(address(this))>0){
            IERC20(TokensAddr[0]).transfer(msg.sender,IERC20(TokensAddr[0]).balanceOf(address(this)));
        }
        if(IERC20(TokensAddr[1]).balanceOf(address(this))>0){
            IERC20(TokensAddr[1]).transfer(msg.sender,IERC20(TokensAddr[1]).balanceOf(address(this)));
        }
    }

    function xLpRedeem(address _lp,uint _amountLp) public returns(uint[2] memory _amount) {
        address[2] memory TokensAddr;
        TokensAddr = getLpPair( _lp) ;
        IERC20(_lp).transferFrom(msg.sender,address(this),_amountLp);
        IERC20(_lp).approve(xlpmanager, _amountLp);
        _amount = ixLpManager(xlpmanager).xLpRedeem(_lp,_amountLp);
        IERC20(TokensAddr[0]).transfer(msg.sender,IERC20(TokensAddr[0]).balanceOf(address(this)));
        IERC20(TokensAddr[1]).transfer(msg.sender,IERC20(TokensAddr[1]).balanceOf(address(this)));
    }
    // vaults
    function xexchange(address[] memory tokens,uint amountIn,uint amountOut,uint limits,uint deadline) public returns(uint output) {
        require(UserLatestBlockNumber[msg.sender] < block.number,"X SWAP Interface: Cant Have Two exchange in one Block");
        UserLatestBlockNumber[msg.sender] = block.number;
        uint tokenLength = tokens.length;
        IERC20(tokens[0]).transferFrom(msg.sender,address(this),amountIn);
        IERC20(tokens[0]).approve(xvaults, amountIn);
        amountIn = IERC20(tokens[0]).balanceOf(address(this));
        output = ixVaults(xvaults).xexchange(tokens, amountIn, amountOut, limits, deadline);
        IERC20(tokens[tokenLength-1]).transfer(msg.sender,IERC20(tokens[tokenLength-1]).balanceOf(address(this)));
    }
    function xLpSubscribeCFX(address _lp,uint[2] memory _amountEstimated) public payable returns(uint[2] memory _amountActual,uint _amountLp) {
        uint[2] memory TokensAmount;
        (TokensAmount,, )= getLpReserve(_lp);
        
        if(TokensAmount[0]==0){
            initialLpOwner[_lp] = msg.sender;
        }
        address[2] memory TokensAddr;
        uint8 j;
        TokensAddr = getLpPair( _lp) ;
        if(TokensAddr[0] != wCFX){
            require(TokensAddr[1] == wCFX,"X SWAP Interface: Not CFX lp pair!");
            j = 1;
        }
        // address payable receiver = payable(this);
        // (bool success, ) = receiver.call{value:msg.value}("");
        // require(success,"X SWAP Interface: CFX Transfer Failed");
        iwxCFX(wCFX).deposit{value:_amountEstimated[0]}();
        if(j==0){
            IERC20(TokensAddr[1]).transferFrom(msg.sender,address(this),_amountEstimated[1]);
            IERC20(TokensAddr[0]).approve(xlpmanager, _amountEstimated[0]);
            IERC20(TokensAddr[1]).approve(xlpmanager, _amountEstimated[1]);
        }else{
            IERC20(TokensAddr[0]).transferFrom(msg.sender,address(this),_amountEstimated[0]);
            IERC20(TokensAddr[0]).approve(xlpmanager, _amountEstimated[0]);
            IERC20(TokensAddr[1]).approve(xlpmanager, _amountEstimated[1]);
        }
 
        (_amountActual,_amountLp) = ixLpManager(xlpmanager).xLpSubscribe(_lp,_amountEstimated);
        IERC20(_lp).transfer(msg.sender,IERC20(_lp).balanceOf(address(this)));

        iwxCFX(wCFX).withdraw(IERC20(wCFX).balanceOf(address(this)));
        if(address(this).balance>0){
            address payable receiver = payable(msg.sender); // Set receiver
            (bool success, ) = receiver.call{value:address(this).balance}("");
            require(success,"X SWAP Interface: CFX Transfer Failed");
        }

        if(IERC20(TokensAddr[0]).balanceOf(address(this))>0){
            IERC20(TokensAddr[0]).transfer(msg.sender,IERC20(TokensAddr[0]).balanceOf(address(this)));
        }
        if(IERC20(TokensAddr[1]).balanceOf(address(this))>0){
            IERC20(TokensAddr[1]).transfer(msg.sender,IERC20(TokensAddr[1]).balanceOf(address(this)));
        }
    }
    
    function xLpRedeemCFX(address _lp,uint _amountLp) public returns(uint[2] memory _amount) {
        address[2] memory TokensAddr;
        TokensAddr = getLpPair( _lp) ;
        uint8 j;
        if(TokensAddr[0] != wCFX){
            require(TokensAddr[1] == wCFX,"X SWAP Interface: Not CFX lp pair!");
            j = 1;
        }
        IERC20(_lp).transferFrom(msg.sender,address(this),_amountLp);
        IERC20(_lp).approve(xlpmanager, _amountLp);
        _amount = ixLpManager(xlpmanager).xLpRedeem(_lp,_amountLp);
        iwxCFX(wCFX).withdraw(IERC20(wCFX).balanceOf(address(this)));

        address payable receiver = payable(msg.sender); // Set receiver
        (bool success, ) = receiver.call{value:address(this).balance}("");
        require(success,"X SWAP Interface: CFX Transfer Failed");
        if(j==0){
            IERC20(TokensAddr[1]).transfer(msg.sender,IERC20(TokensAddr[1]).balanceOf(address(this)));
        }else{
            IERC20(TokensAddr[0]).transfer(msg.sender,IERC20(TokensAddr[0]).balanceOf(address(this)));
        }
    }
    
    function xLpSubscribe2(address _lp,uint[2] memory _amountEstimated) public payable returns(uint[2] memory _amountActual,uint _amountLp) {
        address[2] memory TokensAddr;
        TokensAddr = getLpPair( _lp) ;
        if(TokensAddr[0] == wCFX || TokensAddr[0] == wCFX){
            return xLpSubscribeCFX(_lp, _amountEstimated);
        }else{
            return xLpSubscribe(_lp, _amountEstimated);
        }
    }
    function xLpRedeem2(address _lp,uint _amountLp) public returns(uint[2] memory _amount){
        address[2] memory TokensAddr;
        TokensAddr = getLpPair( _lp) ;
        if(TokensAddr[0] == wCFX || TokensAddr[0] == wCFX){
            return xLpRedeemCFX(_lp, _amountLp);
        }else{
            return xLpRedeem(_lp, _amountLp);
        }
    }
    function xexchange2(address[] memory tokens,uint amountIn,uint amountOut,uint limits,uint deadline) public payable returns(uint output) {
        require(UserLatestBlockNumber[msg.sender] < block.number,"X SWAP Interface: Cant Have Two exchange in one Block");
        UserLatestBlockNumber[msg.sender] = block.number;
        uint tokenLength = tokens.length;
        if(tokens[0]==CFXMock){
            // address payable receiver = payable(this);
            // (bool success, ) = receiver.call{value:msg.value}("");
            // require(success,"X SWAP Interface: CFX Transfer Failed");
            iwxCFX(wCFX).deposit{value: amountIn}();
            tokens[0] = wCFX;
        }else{
            IERC20(tokens[0]).transferFrom(msg.sender,address(this),amountIn);
        }
        uint j;
        if(tokens[tokenLength-1]==CFXMock){
            j = 1;
            tokens[tokenLength-1] = wCFX;
        }
        
        IERC20(tokens[0]).approve(xvaults, amountIn);
        amountIn = IERC20(tokens[0]).balanceOf(address(this));
        output = ixVaults(xvaults).xexchange(tokens, amountIn, amountOut, limits, deadline);
        
        if(j==1){
            iwxCFX(wCFX).withdraw(IERC20(tokens[tokenLength-1]).balanceOf(address(this)));
            
        }else{
            IERC20(tokens[tokenLength-1]).transfer(msg.sender,IERC20(tokens[tokenLength-1]).balanceOf(address(this)));
        }
        if(address(this).balance>0){
            address payable receiver = payable(msg.sender); // Set receiver
            (bool success, ) = receiver.call{value:address(this).balance}("");
            require(success,"X SWAP Interface: CFX Transfer Failed");
        }
    }
    // vaults :: for exchange estimate
    function xExchangeEstimateInput(address[] memory tokens,uint amountIn) external  view returns(uint output, uint[3] memory priceImpactAndFees, uint b) {
        uint[4] memory inputAmount;
        uint[4] memory outputAmount;
        address[] memory _lp = new address[](tokens.length);
        uint i;
        uint[2] memory priceCumulative;

        require(tokens.length>1&&tokens.length<=5,"X SWAP Interface: exceed MAX path lengh:2~5");
        outputAmount[0] = amountIn;
        require( outputAmount[0] > 0,"X SWAP Interface: Input need > 0");
        
        priceImpactAndFees[1] = 10000;
        priceImpactAndFees[2] = 10000;
        for(i=0;i<tokens.length-1;i++){
            if(i==0){
                inputAmount[i] = outputAmount[i];
                
            }else{
                inputAmount[i] = outputAmount[i-1];
            }
            
            _lp[i]=iXunionFactory(xfactory).getPair(tokens[i], tokens[i+1]);
            (output,) = getLpSettings(_lp[i]);// public view returns(uint32 balanceFee, uint a0);
            priceImpactAndFees[0] += output;

            (outputAmount[i],,priceCumulative,b) = 
            ixCore(xCore).swapCalculation2(_lp[i],tokens[i],inputAmount[i]);//external view returns
            priceImpactAndFees[1] = priceImpactAndFees[1] * priceCumulative[0] / priceCumulative[1];
            priceImpactAndFees[2] = priceImpactAndFees[2] * getLpPrice(_lp[i]) / 1 ether;
            }
        output = outputAmount[tokens.length-2];
    }
    function xExchangeEstimateOutput(address[] memory tokens,uint amountOut) external view returns(uint input, uint[3] memory priceImpactAndFees, uint b) {
        uint[4] memory inputAmount;
        uint[4] memory outputAmount;
        address[] memory _lp = new address[](tokens.length);
        uint i;
        uint[2] memory priceCumulative;

        require(tokens.length>1&&tokens.length<=5,"X SWAP Interface: exceed MAX path lengh:2~5");
        outputAmount[tokens.length-1] = amountOut;
        require( amountOut > 0,"X SWAP Interface: Input need > 0");

        priceImpactAndFees[1] = 10000;
        priceImpactAndFees[2] = 10000;
        for(i=tokens.length-1;i>0;i--){
            _lp[i]=iXunionFactory(xfactory).getPair(tokens[i], tokens[i-1]);
            (input,) = getLpSettings(_lp[i]);// public view returns(uint32 balanceFee, uint a0);
            priceImpactAndFees[0] += input;
            (inputAmount[i],,priceCumulative,b) = 
            ixCore(xCore).swapCalculation3(_lp[i],tokens[i-1],outputAmount[i]);//external view returns
            outputAmount[i-1] = inputAmount[i];
            priceImpactAndFees[1] = priceImpactAndFees[1] * priceCumulative[0] / priceCumulative[1];
            priceImpactAndFees[2] = priceImpactAndFees[2] * getLpPrice(_lp[i]) / 1 ether;
            }
        input = inputAmount[1];
    }

    // lp vaults
    function initialLpRedeem(address _lp) public returns(uint _amount) {
        _amount = ixLpVaults(xlpvaults).initialLpRedeem(_lp);
        IERC20(_lp).transfer(msg.sender,IERC20(_lp).balanceOf(address(this)));
    }

    // Query function
    // Overall parameter query
    // Including 8 aspects:
    // 1. Check how many currency pairs are currently available;
    // 2. Check if there are currency pairs corresponding to two currencies, and if so, what is the address;
    // 3. Query which two currencies are the currency pairs for a certain address
    // 4. Query whether a stable currency pair has been created for a certain currency
    // 5. Query the creator's address for a certain currency
    // 6. Query the initial number of LP created for a certain currency
    // 7. Obtain details of a certain coin pair
    // 8. Obtain the current parameter settings for a certain coin pair
    // 9. Obtain the exchange quantity of a given currency for the current given quantity
    // factory
    function allPairs(uint _num) public view returns (address pair) {
        return iXunionFactory(xfactory).allLpPairs(_num);
    }
    function allPairsLength() public view returns (uint) {
        return iXunionFactory(xfactory).allLpPairsLength();
    }
    function getPair(address tokenA, address tokenB) public view returns (address pair) {
        return iXunionFactory(xfactory).getPair(tokenA, tokenB);
    }
    function getCoinToStableLpPair(address tokenA) public view returns (address pair) {
        return iXunionFactory(xfactory).getCoinToStableLpPair(tokenA);
    }
    // vaults
    function getLpPrice(address _lp) public view returns (uint ) {
        return ixVaults(xvaults).getLpPrice(_lp);
    }
    function getLpReserve(address _lp) public view returns (uint[2] memory ,uint[2] memory, uint) {
        return ixVaults(xvaults).getLpReserve(_lp);
    }
    function getLpPair(address _lp) public view returns (address[2] memory pair) {
        (pair,)  = iXunionFactory(xfactory).getLpPairsDetails(_lp);
        // return ixVaults(xvaults).getLpPair(_lp);
    }
    function getLpSettings(address _lp) public view returns(uint32 balanceFee, uint a0) {
        return ixVaults(xvaults).getLpSettings(_lp);
    }
    // lpvaults 
    function getInitialLpOwner(address lp) public view returns (address) {
        return iLpVaultInfo(xlpvaults).initialLpOwner(lp);
    }
    function getInitLpAmount(address lp) public view returns (uint) {
        return iLpVaultInfo(xlpvaults).initLpAmount(lp);
    }
    // ERC20
    function getCoinOrLpTotalAmount(address lpOrCoin) public view returns (uint){
        return IERC20(lpOrCoin).totalSupply();
    }

    // Personal parameter query
    // 1. Query the number of users holding a certain currency or LP
    // 2. Query the number of corresponding two types of reserves held by the user for a certain LP

    function getUserCoinOrLpAmount(address lpOrCoin,address _user) public view returns (uint){
        return IERC20(lpOrCoin).balanceOf(_user);
    }

    function getUserLpReservesAmount(address _lp,address _user) external view returns (address[2] memory TokensAdd,uint[2] memory TokensAmount){
        uint userCurve = getUserCoinOrLpAmount( _lp, _user) * 1 ether / getCoinOrLpTotalAmount( _lp);
        TokensAdd = getLpPair(_lp);
        (TokensAmount,, )= getLpReserve(_lp);
        TokensAmount[0] = userCurve * TokensAmount[0] / 1 ether; 
        TokensAmount[1] = userCurve * TokensAmount[1] / 1 ether; 
    }
    // ======================== contract base methods =====================
    fallback() external payable {}
    receive() external payable {}

}