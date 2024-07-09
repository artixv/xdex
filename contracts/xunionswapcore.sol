// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.06.30
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/structlibrary.sol";
import "./interfaces/ixvaults.sol";
//Include the core method of xswap
//Stable currency exchange, non stable currency exchange
//The maximum number of exchanges allowed at a time cannot exceed 10% of the total amount of currency in the pool
contract xUnionSwapCore{

    address public vaults;
    address public riskMitigationFund;
    address public slcaddr;

    constructor(address _vaults, address _riskMitigationFund, address _slcaddr) {
        vaults = _vaults;
        riskMitigationFund = _riskMitigationFund;
        slcaddr = _slcaddr;
    }

    //-----------------------------------------------------------------
    function obtainReserves(address _lp)public view returns(structlibrary.reserve memory _lpDetails){
        (_lpDetails.reserve,_lpDetails.priceCumulative, _lpDetails.totalSupply) = ixVaults(vaults).getLpReserve(_lp) ;
        _lpDetails.assetAddr = ixVaults(vaults).getLpPair( _lp);
        (_lpDetails.balanceFee, _lpDetails.a0) = ixVaults(vaults).getLpSettings( _lp);
    }

    // this swapCalculation used for real exchange
    function swapCalculation(address _lp,address _inputToken,uint _inputAmount,uint _i)public view returns (uint _outputAmount,uint[2] memory reserve,uint[2] memory priceCumulative,uint b) {
        structlibrary.reserve memory _lpDetails;
        uint8 j;
        uint pricexy;
        uint pricexyInner;
        uint pd;
        uint k;

        _lpDetails = obtainReserves(_lp);
        uint a = _lpDetails.a0;

        if(_inputToken == _lpDetails.assetAddr[0]){
            j=0;
            if(_i==0) {
                _lpDetails.reserve[0] -= _inputAmount;
            }
        }else if(_inputToken == _lpDetails.assetAddr[1]){
            j=1;
            if(_i==0) {
                _lpDetails.reserve[1] -= _inputAmount;
            }
        }else{
            require(_inputToken == _lpDetails.assetAddr[0],"X SWAP CORE: WRONG Token Input");
        }
        require(_lpDetails.reserve[j] >= _inputAmount*10,"X SWAP CORE: EXCEED  reserve Limits, NEED a smaller amount");
        pricexy = (_lpDetails.priceCumulative[j] * 1 ether) / _lpDetails.priceCumulative[1-j];
        pricexyInner = (_lpDetails.reserve[1-j] * 1 ether) / _lpDetails.reserve[j];

        if(pricexy>pricexyInner){
            pd = (pricexy - pricexyInner)* 1 ether/pricexyInner;
        }else{
            pd = (pricexyInner - pricexy)* 1 ether/pricexy;
        }
        if(a == 0){
            b = 0;
        }else{
            a =  a * 1 ether / (1 ether + pd*pd/1 ether);
            b = (1 ether+a)*_lpDetails.reserve[1-j] / pricexy;
            if(b < _lpDetails.reserve[j]){
                a = a/2;
                b = (1 ether+a)*_lpDetails.reserve[1-j] / pricexy;
                if(b < _lpDetails.reserve[j]){
                    a = 0;
                    b = 0;
                }else{
                    b = b - _lpDetails.reserve[j];
                }
            }else{
                b = b - _lpDetails.reserve[j];
            }
        }
        
        k = (1 ether+a) * _lpDetails.reserve[1-j] /1 ether;
        k = k * (_lpDetails.reserve[j] + b);
        _outputAmount = ((1 ether+a)*_lpDetails.reserve[1-j])/1 ether - k/(_lpDetails.reserve[j] + b + _inputAmount);
        _outputAmount = _outputAmount *(10000-_lpDetails.balanceFee)/10000;//add fee to LP

        reserve[j] = _lpDetails.reserve[j] + _inputAmount;
        reserve[1-j] = _lpDetails.reserve[1-j] - _outputAmount;
        priceCumulative[j] = (1 ether+a)*_lpDetails.reserve[1-j]/1 ether - _outputAmount;
        priceCumulative[1-j] = _lpDetails.reserve[j] + b + _inputAmount;
    }
    // this swapCalculation2 used for estimate
    function swapCalculation2(address _lp,address _inputToken,uint _inputAmount)public view returns (uint _outputAmount,uint[2] memory reserve,uint[2] memory priceCumulative,uint b) {
        structlibrary.reserve memory _lpDetails;
        uint8 j;
        uint pricexy;
        uint pricexyInner;
        uint pd;
        uint k;

        _lpDetails = obtainReserves(_lp);
        uint a = _lpDetails.a0;

        if(_inputToken == _lpDetails.assetAddr[0]){
            j=0;
        }else if(_inputToken == _lpDetails.assetAddr[1]){
            j=1;
        }else{
            require(_inputToken == _lpDetails.assetAddr[0],"X SWAP CORE: WRONG Token Input");
        }
        //require(_lpDetails.reserve[j] >= _inputAmount*10,"X SWAP CORE: EXCEED  reserve Limits, NEED a smaller amount");
        pricexy = (_lpDetails.priceCumulative[j] * 1 ether) / _lpDetails.priceCumulative[1-j];
        pricexyInner = (_lpDetails.reserve[1-j] * 1 ether) / _lpDetails.reserve[j];

        if(pricexy>pricexyInner){
            pd = (pricexy - pricexyInner)* 1 ether/pricexyInner;
        }else{
            pd = (pricexyInner - pricexy)* 1 ether/pricexy;
        }
        if(_lpDetails.a0 == 0){
            b = 0;
        }else{
            a =  _lpDetails.a0 * 1 ether / (1 ether + pd*pd/1 ether);
            b = (1 ether+a)*_lpDetails.reserve[1-j] / pricexy;
            if(b < _lpDetails.reserve[j]){
                a = a/2;
                b = (1 ether+a)*_lpDetails.reserve[1-j] / pricexy;
                if(b < _lpDetails.reserve[j]){
                    a = 0;
                    b = 0;
                }else{
                    b = b - _lpDetails.reserve[j];
                }
            }else{
                b = b - _lpDetails.reserve[j];
            }
        }
        
        k = (1 ether+a) * _lpDetails.reserve[1-j] /1 ether;
        k = k * (_lpDetails.reserve[j] + b);
        _outputAmount = ((1 ether+a)*_lpDetails.reserve[1-j])/1 ether - k/(_lpDetails.reserve[j] + b + _inputAmount);
        _outputAmount = _outputAmount *(10000-_lpDetails.balanceFee)/10000;//add fee to LP

        reserve[j] = _lpDetails.reserve[j] + _inputAmount;
        reserve[1-j] = _lpDetails.reserve[1-j] - _outputAmount;
        priceCumulative[j] = (1 ether+a)*_lpDetails.reserve[1-j]/1 ether - _outputAmount;
        priceCumulative[1-j] =  _lpDetails.reserve[j] + b + _inputAmount;
    }
    
    // this swapCalculation3 used for estimate: here _inputToken is outputToken, _inputAmount is outputAmount
    function swapCalculation3(address _lp,address _inputToken,uint _inputAmount)public view returns (uint _outputAmount,uint[2] memory reserve,uint[2] memory priceCumulative,uint b) {
        structlibrary.reserve memory _lpDetails;
        uint8 j;
        uint pricexy;
        uint pricexyInner;
        uint pd;
        uint k;

        _lpDetails = obtainReserves(_lp);
        uint a = _lpDetails.a0;

        if(_inputToken == _lpDetails.assetAddr[0]){
            j=0;
        }else if(_inputToken == _lpDetails.assetAddr[1]){
            j=1;
        }else{
            require(_inputToken == _lpDetails.assetAddr[0],"X SWAP CORE: WRONG Token Input");
        }
        // require(_lpDetails.reserve[1-j] >= _inputAmount*10,"X SWAP CORE: EXCEED  reserve Limits, NEED a smaller amount");
        pricexy = (_lpDetails.priceCumulative[j] * 1 ether) / _lpDetails.priceCumulative[1-j];
        pricexyInner = (_lpDetails.reserve[1-j] * 1 ether) / _lpDetails.reserve[j];

        if(pricexy>pricexyInner){
            pd = (pricexy - pricexyInner)* 1 ether/pricexyInner;
        }else{
            pd = (pricexyInner - pricexy)* 1 ether/pricexy;
        }
        if(_lpDetails.a0 == 0){
            b = 0;
        }else{
            a =  _lpDetails.a0 * 1 ether / (1 ether + pd*pd/1 ether);
            b = (1 ether+a)*_lpDetails.reserve[1-j] / pricexy;
            if(b < _lpDetails.reserve[j]){
                a = a/2;
                b = (1 ether+a)*_lpDetails.reserve[1-j] / pricexy;
                if(b < _lpDetails.reserve[j]){
                    a = 0;
                    b = 0;
                }else{
                    b = b - _lpDetails.reserve[j];
                }
            }else{
                b = b - _lpDetails.reserve[j];
            }
        }
        
        k = (1 ether+a) * _lpDetails.reserve[1-j] /1 ether;
        k = k * (_lpDetails.reserve[j] + b);
        _inputAmount = _inputAmount *(10000+_lpDetails.balanceFee)/10000;//add fee to LP
        _outputAmount = k/(((1 ether+a)*_lpDetails.reserve[1-j])/1 ether - _inputAmount) - _lpDetails.reserve[j] - b;

        reserve[j] = _lpDetails.reserve[j] + _outputAmount;
        reserve[1-j] = _lpDetails.reserve[1-j] - _inputAmount;
        priceCumulative[j] = (1 ether+a)*_lpDetails.reserve[1-j]/1 ether - _inputAmount;
        priceCumulative[1-j] =  _lpDetails.reserve[j] + b + _outputAmount;
    }

    // vaults :: for exchange estimate
    function xExchangeEstimateInput(address[] memory tokens,uint amountIn) internal view returns(uint output) {
        uint[4] memory inputAmount;
        uint[4] memory outputAmount;
        address[] memory _lp = new address[](tokens.length);
        uint i;
        uint[2] memory priceCumulative;
        uint[3] memory priceImpactAndFees;

        require(tokens.length>1&&tokens.length<=5,"X CORE: exceed MAX path lengh:2~5");
        outputAmount[0] = amountIn;
        require( outputAmount[0] > 0,"X CORE: Input need > 0");
        
        priceImpactAndFees[1] = 10000;
        priceImpactAndFees[2] = 10000;
        for(i=0;i<tokens.length-1;i++){
            if(i==0){
                inputAmount[i] = outputAmount[i];
                
            }else{
                inputAmount[i] = outputAmount[i-1];
            }
            
            _lp[i]=ixVaults(vaults).getPair(tokens[i], tokens[i+1]);
            (output,) = ixVaults(vaults).getLpSettings(_lp[i]);// public view returns(uint32 balanceFee, uint a0);
            priceImpactAndFees[0] += output;

            (outputAmount[i],,priceCumulative,) = 
            swapCalculation2(_lp[i],tokens[i],inputAmount[i]);//external view returns
            priceImpactAndFees[1] = priceImpactAndFees[1] * priceCumulative[0] / priceCumulative[1];
            priceImpactAndFees[2] = priceImpactAndFees[2] * ixVaults(vaults).getLpPrice(_lp[i]) / 1 ether;
            }
        output = outputAmount[tokens.length-2];
    }


    function afterSwap(structlibrary.exVaults memory _exVaults,uint a,uint b) public returns(bool ToF, structlibrary.exVaults memory _toUesd){
        // uint k = _exVaults.tokens.length;
        // uint out;
        // uint amountIn ;
        // if(a != 0 && b == 0){
        //     amountIn = _exVaults.amountIn;
        // }else{
        //     amountIn = _exVaults.amountIn/4;
        // }
        // if(k == 2){
        //     if(_exVaults.tokens[0]!=slcaddr && _exVaults.tokens[1]!=slcaddr){
        //         ToF = false;
        //         return;
        //     }
        //     uint tokens = new address[](4);
        //     tokens[0] = _exVaults.tokens[0];
        //     tokens[1] = slcaddr;
        //     tokens[2] = _exVaults.tokens[1];
        //     tokens[3] = _exVaults.tokens[0];
        //     out = xExchangeEstimateInput(tokens, amountIn) ;
        //     if (out > amountIn + 10000){
        //         _toUesd.tokens = tokens;
        //         _toUesd.amountIn = amountIn;
        //         _toUesd.amountOut = amountIn;
        //     }

        // }else if(k ==3){

        // }else if(k > 3){
        //     ToF = false;
        //     return;
        // }

    }
    function afterSwap2(structlibrary.exVaults memory _exVaults,uint a,uint b) public  {

    }

    function afterSwap3(structlibrary.exVaults memory _exVaults,uint a,uint b) public  {}

    
}