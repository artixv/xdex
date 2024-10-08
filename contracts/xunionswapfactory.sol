// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2024.09.30
pragma solidity 0.8.6;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import './xunionswappair.sol';
import "./libraries/structlibrary.sol";
import "./interfaces/iRewardMini.sol";

contract xUnionSwapFactory  {
    //----------------------Persistent Variables ----------------------
    address public setPermissionAddress;
    address newPermissionAddress;
    address public vaults;//All states are stored in the vault
    address public slc;// Super Libra Coin
    address public lpManager;
    address public rewardContract;
    uint    public rewardType;
    mapping(address => mapping(address => address)) public getPair;
    mapping(address => address) public getCoinToStableLpPair;
    mapping(address => structlibrary.reserve) public lpdetails;
    address[] public allLpPairs;

    //-------------------------- constructor --------------------------
    constructor(address _setPermissionAddress) {
        setPermissionAddress = _setPermissionAddress;
    }
    //----------------------------modifier ----------------------------
    modifier onlyPermissionAddress() {
        require(setPermissionAddress == msg.sender, 'Coin Factory: Permission FORBIDDEN');
        _;
    }

    //----------------------------- event -----------------------------
    event LpResetup(address indexed lpAddr, address rewardContract);
    event RewardTypeSetup(address indexed factoryAddr, uint newType);
    event Settings( address _vault,
                    address _slc,
                    address _lpManager,
                    address _rewardContract);
    event SetPA(address newPermissionAddress);
    event AcceptPA(bool _TorF);
    event Resetuplp(address _lp,address _vaults,address _lpManager);

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    event PairCreatedX(address indexed token0, address indexed token1, address pair, uint sortPosition,uint8 category);
    //----------------------------- functions -----------------------------
        
    function name(address token) public view returns (string memory) {
        return string(ERC20(token).name());
    }
    function allLpPairsLength() external view returns (uint) {
        return (allLpPairs.length);
    }
    function getLpPairsDetails(address pair) external view returns (address[2] memory,uint8) {
        return (lpdetails[pair].assetAddr,lpdetails[pair].category);
    }

    function createPair(address tokenA,address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'X Swap Factory: IDENTICAL_ADDRESSES');
        uint8 lpCategory; 
        address token0;
        address token1;
        if((tokenA != slc)&&(tokenB != slc)){
            require((getPair[tokenA][slc] != address(0))&&(getPair[tokenB][slc] != address(0)),"X SWAP Factory: NEED BASE Pair!");
            (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
            lpCategory = 2;
        }else{
            if(tokenA == slc){
                (token0, token1) = (tokenB, tokenA);
            }else{
                (token0, token1) = (tokenA, tokenB);
            }
            lpCategory = 1;
        }

        require(token0 != address(0), 'X Swap Factory: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'X Swap Factory: PAIR_EXISTS'); // single check is sufficient
        require(vaults != address(0), 'X Swap Factory: Vaults NOT Set');
        bytes32 _salt = keccak256(abi.encodePacked(token0, token1));
        //Only ERC20 Tokens Can creat pairs
        pair = address(new xUnionSwapPair{salt: _salt}(strConcat(strConcat(string(ERC20(token0).symbol()),"&"),strConcat(string(ERC20(token1).symbol()), " Liquidity Provider")),strConcat(strConcat(string(ERC20(tokenA).symbol()),"&"),strConcat(string(ERC20(tokenB).symbol()), " LP"))));  //
        xUnionSwapPair(pair).initialize(token0, token1, vaults, slc, lpManager, rewardContract);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        lpdetails[pair].assetAddr[0] =  token0;
        lpdetails[pair].assetAddr[1] =  token1;
        lpdetails[pair].category = lpCategory;
        allLpPairs.push(pair);
        if(lpCategory == 1){
            if(tokenA == slc){
                getCoinToStableLpPair[tokenB] = pair;
            }else{
                getCoinToStableLpPair[tokenA] = pair;
            }
        }

        iRewardMini(rewardContract).factoryUsedRegist(pair, rewardType);

        emit PairCreated(token0, token1, pair, allLpPairs.length);
        emit PairCreatedX(token0, token1, pair, allLpPairs.length,lpCategory);
    }

    //--------------------------- Internal functions --------------------------

    function strConcat(string memory _str1, string memory _str2) internal pure returns (string memory) {
        return string(abi.encodePacked(_str1, _str2));
    }

    //--------------------------- Setup functions --------------------------
    
    function lpResetup(address _rewardContract,address lpAddr) external onlyPermissionAddress{
        xUnionSwapPair(lpAddr).rewardContractSetup(_rewardContract);
        emit LpResetup(lpAddr, rewardContract);
    }

    function rewardTypeSetup(uint _rewardType) external onlyPermissionAddress{
        rewardType = _rewardType;
        emit RewardTypeSetup(address(this),  _rewardType);
    }

    function settings(address _vault,
                      address _slc,
                      address _lpManager,
                      address _rewardContract) external onlyPermissionAddress{
        vaults = _vault;
        slc = _slc;
        lpManager = _lpManager;
        rewardContract = _rewardContract;
        emit Settings( _vault,
                       _slc,
                       _lpManager,
                       _rewardContract);
    }

    function setPA(address _setPermissionAddress) external onlyPermissionAddress{
        newPermissionAddress = _setPermissionAddress;
        emit SetPA(_setPermissionAddress);
    }
    function acceptPA(bool _TorF) external {
        require(msg.sender == newPermissionAddress, 'X Swap Factory: Permission FORBIDDEN');
        if(_TorF){
            setPermissionAddress = newPermissionAddress;
        }
        newPermissionAddress = address(0);
        emit AcceptPA(_TorF);
    }
    function resetuplp(address _lp,address _vaults,address _lpManager) external onlyPermissionAddress{
        xUnionSwapPair(_lp).resetup( _vaults, _lpManager);
        emit Resetuplp(_lp, _vaults, _lpManager);
    }

}
