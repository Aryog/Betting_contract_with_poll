// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// This file may contain the file for doing

contract Bank {
    mapping(address => uint256) public balances;

    address private bankOwner;
    address private marketplaceAddress = address(0);

    event Deposit(address indexed _from, uint256 _value);
    event Withdraw(address indexed _to, uint256 _value);

    constructor() {
        bankOwner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == bankOwner, "You are not owner of the bank.");
        _;
    }
    modifier onlyMarketplace(address _marketAddress) {
        require(marketplaceAddress != address(0), "Marketplace not yet set.");
        require(
            _marketAddress == marketplaceAddress,
            "You are not marketplace."
        );
        _;
    }

    // Set the marketplace with the bank
    function setMarketplace(address _marketAddress) public onlyOwner {
        marketplaceAddress = _marketAddress;
    }

    // Deposit credits into the bank
    function depositFromYesNo(
        address _receiver,
        address _marketAddress
    ) public payable onlyMarketplace(_marketAddress) {
        balances[_receiver] += msg.value;
        emit Deposit(_receiver, msg.value);
    }

    // Withdraw credits from the bank
    // Function to withdraw funds by a specified recipient
    function withdrawFromYesNo(
        address payable _depositor,
        uint256 amount,
        address _marketAddress
    ) public payable onlyMarketplace(_marketAddress) {
        require(balances[_depositor] >= amount, "Insufficient balance");
        balances[_depositor] -= amount;
        payable(msg.sender).transfer(amount);
        // _depositor.transfer(amount);
    }

    function deposit() public payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    // Get the balance of an account
    function balanceOf(address _account) public view returns (uint256) {
        return balances[_account];
    }

    function myCreditBalance() public view returns (uint256) {
        return balances[msg.sender];
    }
}
