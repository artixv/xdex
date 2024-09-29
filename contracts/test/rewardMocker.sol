// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract rewardMocker{
    struct userUpdateInfo{
        uint latestTimeStamp;             
        uint userSelectedTypesAcountValue;    
    }

    // address1 is user address;
    // address2 is coin/contract address;
    // userUpdateInfo is the updated info of user in this coin/contract address
    mapping(address => mapping(address => userUpdateInfo)) public userSelectedTypesAcountInfo;//
    mapping(address => mapping(uint => uint)) public selectedTypesAcountInfoSum;//
    mapping(uint => uint) public selectedTypesSum;//
    mapping(address => uint) public tokenOrVaultType;

    function recordUpdate(address _userAccount,uint _value) external returns(bool){
        // only msg.sender == record address
        if(tokenOrVaultType[msg.sender] > 0){
            selectedTypesAcountInfoSum[msg.sender][tokenOrVaultType[msg.sender]] = selectedTypesAcountInfoSum[msg.sender][tokenOrVaultType[msg.sender]]
                                                                                 - userSelectedTypesAcountInfo[_userAccount][msg.sender].userSelectedTypesAcountValue
                                                                                 + _value;
            selectedTypesSum[tokenOrVaultType[msg.sender]] = selectedTypesSum[tokenOrVaultType[msg.sender]]
                                                           - userSelectedTypesAcountInfo[_userAccount][msg.sender].userSelectedTypesAcountValue
                                                           + _value;
            userSelectedTypesAcountInfo[_userAccount][msg.sender].userSelectedTypesAcountValue = _value;
            userSelectedTypesAcountInfo[_userAccount][msg.sender].latestTimeStamp = block.timestamp;
        }
        
        return true;
    }
    function factoryUsedRegist(address _token, uint256 _type) external returns(bool){
        //only factory or administrators
        tokenOrVaultType[_token] = _type;
        return true;
    }
}
