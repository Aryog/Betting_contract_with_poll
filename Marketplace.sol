// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./YesNo.sol";

contract Marketplace {
    enum Winner {
        YES,
        NO,
        DRAW
    }

    struct YesNoContractInfo {
        YesNo contractInstance;
        bool isArchived;
        uint endTime;
        Winner winner;
    }

    mapping(address => YesNoContractInfo[]) public ownerToYesNoContract;
    mapping(uint => YesNo) public yesNoContracts; // Map YesNo contract addresses to a unique identifier

    uint public nextContractId = 1;

    constructor() {}

    function createYesNoContract(uint endTime) external {
        YesNo newYesNoContract = new YesNo();
        ownerToYesNoContract[msg.sender].push(
            YesNoContractInfo(newYesNoContract, false, endTime, Winner.YES)
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

        // Calculate the winner using the GetWinner function from the YesNo contract
        string memory winnerString = contractInfo.contractInstance.GetWinner(
            block.number / BLOCK_DIV
        );
        Winner winner;
        if (
            keccak256(abi.encodePacked((winnerString))) ==
            keccak256(abi.encodePacked(("YES")))
        ) {
            winner = Winner.YES;
        } else if (
            keccak256(abi.encodePacked((winnerString))) ==
            keccak256(abi.encodePacked(("NO")))
        ) {
            winner = Winner.NO;
        } else {
            winner = Winner.DRAW;
        }

        // Update the winner information in the YesNoContractInfo struct
        contractInfo.winner = winner;
        contractInfo.isArchived = true;
    }

    // Additional functions for marketplace interactions can be added here
}
