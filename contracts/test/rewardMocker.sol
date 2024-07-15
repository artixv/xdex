// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract rewardMocker{
    struct userUpdateInfo{
        uint latestTimeStamp;             
        uint userSelectedTypesAcountValue;    
    }
    mapping(address => mapping(uint => userUpdateInfo)) public userSelectedTypesAcountInfo;
    mapping(address => uint) public tokenOrVaultType;

    function recordUpdate(address _userAccount,uint _value) external returns(bool){
        // only msg.sender == record address
        userSelectedTypesAcountInfo[_userAccount][tokenOrVaultType[msg.sender]].userSelectedTypesAcountValue = _value;
        userSelectedTypesAcountInfo[_userAccount][tokenOrVaultType[msg.sender]].latestTimeStamp = block.timestamp;
        return true;
    }
    function factoryUsedRegist(address _token, uint256 _type) external returns(bool){
        //only factory or administrators
        tokenOrVaultType[_token] = _type;
        return true;
    }
}
