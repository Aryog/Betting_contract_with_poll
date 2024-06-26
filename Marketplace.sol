// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./YesNo.sol";

contract Marketplace {
    enum Winner {
        YETNOTCONFIRMED,
        YES,
        NO,
        DRAW
    }

    struct YesNoContractInfo {
        uint256 contractId;
        address contractInstance;
        bool isArchived;
        uint256 endTime;
        Winner winner;
    }

    mapping(address => YesNoContractInfo[]) public ownerToYesNoContract;
    mapping(uint256 => YesNo) public yesNoContracts; // Map YesNo contract addresses to a unique identifier
    address payable private bankAddress;
    uint256 private nextContractId = 1;

    constructor(address payable _bankAddress) {
        bankAddress = _bankAddress;
    }

    function createYesNoContract(uint256 endTime) external payable {
        YesNo newYesNoContract = (new YesNo{value: msg.value})(
            endTime,
            msg.sender,
            bankAddress
        );
        ownerToYesNoContract[msg.sender].push(
            YesNoContractInfo(
                nextContractId,
                address(newYesNoContract),
                false,
                endTime,
                Winner.YETNOTCONFIRMED
            )
        );
        yesNoContracts[nextContractId] = newYesNoContract;
        nextContractId++;
    }

    function archiveYesNoContract(uint256 contractId) external {
        require(
            ownerToYesNoContract[msg.sender].length > contractId,
            "Invalid contractId"
        );

        YesNoContractInfo storage contractInfo = ownerToYesNoContract[
            msg.sender
        ][contractId];
        require(!contractInfo.isArchived, "Contract is already archived");
        require(
            block.timestamp >= contractInfo.endTime,
            "Contract has not ended yet"
        );

        YesNo contractInstance = YesNo(payable(contractInfo.contractInstance));
        require(
            msg.sender == contractInstance.getOwner(),
            "Only owner can archive"
        );

        // Get the winner from the Yes/No contract
        string memory winnerString = contractInstance.GetWinner();
        Winner winner;
        if (
            keccak256(abi.encodePacked(winnerString)) ==
            keccak256(abi.encodePacked("YES"))
        ) {
            winner = Winner.YES;
        } else if (
            keccak256(abi.encodePacked(winnerString)) ==
            keccak256(abi.encodePacked("NO"))
        ) {
            winner = Winner.NO;
        } else {
            winner = Winner.DRAW;
        }

        // Update contract info
        contractInfo.winner = winner;
        contractInfo.isArchived = true;
    }

    // Additional functions for marketplace interactions can be added here

    // Function to get YesNo contract addresses owned by the caller
    function getUserSpecificContractAddress()
        public
        view
        returns (address[] memory)
    {
        uint256 length = ownerToYesNoContract[msg.sender].length;
        address[] memory allContracts = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            allContracts[i] = address(
                ownerToYesNoContract[msg.sender][i].contractInstance
            );
        }
        return allContracts;
    }

    function getUserSpecificContractId()
        public
        view
        returns (uint256[] memory)
    {
        uint256 length = ownerToYesNoContract[msg.sender].length;
        uint256[] memory allContractIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            allContractIds[i] = ownerToYesNoContract[msg.sender][i].contractId;
        }
        return allContractIds;
    }

    // Get user specific contract details as YesNoContractInfo[]
    function getUserSpecificContractDetails()
        public
        view
        returns (YesNoContractInfo[] memory)
    {
        return ownerToYesNoContract[msg.sender];
    }
}
