// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./YesNo.sol";

contract Marketplace {
    struct YesNoContractInfo {
        YesNo contractInstance;
        bool isArchived;
        uint endTime;
    }

    mapping(address => YesNoContractInfo[]) public ownerToYesNoContract;
    mapping(uint => YesNo) public yesNoContracts; // Map YesNo contract addresses to a unique identifier

    uint public nextContractId = 1;

    constructor() {}

    function createYesNoContract(uint endTime) external {
        YesNo newYesNoContract = new YesNo();
        ownerToYesNoContract[msg.sender].push(
            YesNoContractInfo(newYesNoContract, false, endTime)
        );
        yesNoContracts[nextContractId] = newYesNoContract;
        nextContractId++;
    }

    function archiveYesNoContract(uint contractId) external {
        require(
            ownerToYesNoContract[msg.sender].length > contractId,
            "Invalid contractId"
        );
        YesNoContractInfo storage contractInfo = ownerToYesNoContract[
            msg.sender
        ][contractId];
        require(
            block.timestamp >= contractInfo.endTime,
            "Contract not ended yet"
        );
        require(
            msg.sender == contractInfo.contractInstance.owner_address(),
            "Only owner can archive"
        );
        contractInfo.isArchived = true;
    }

    // Additional functions for marketplace interactions can be added here
}
