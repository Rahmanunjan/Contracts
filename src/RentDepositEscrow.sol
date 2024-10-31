// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract RentalEscrow {
    address public landlord;
    address public renter;
    uint256 public deposit;
    bool public tenancyEnded;
    
    address[6] public signers;
    mapping(address => bool) public isSigner;
    mapping(address => bool) public hasSigned;
    uint256 public signatureCount;
    
    event DepositPaid(address renter, uint256 amount);
    event DepositWithdrawn(address recipient, uint256 amount);
    event TenancyEnded();

    constructor(address _landlord, address _renter, address[6] memory _signers) {
        landlord = _landlord;
        renter = _renter;
        signers = _signers;
        for (uint i = 0; i < 6; i++) {
            isSigner[_signers[i]] = true;
        }
    }

    modifier onlyLandlord() {
        require(msg.sender == landlord, "Only the landlord can call this function");
        _;
    }

    modifier onlyRenter() {
        require(msg.sender == renter, "Only the renter can call this function");
        _;
    }

    modifier tenancyNotEnded() {
        require(!tenancyEnded, "The tenancy has already ended");
        _;
    }

    function payDeposit() external payable onlyRenter tenancyNotEnded {
        require(deposit == 0, "Deposit has already been paid");
        deposit = msg.value;
        emit DepositPaid(renter, msg.value);
    }

    function signForWithdrawal() external tenancyNotEnded {
        require(isSigner[msg.sender], "Not authorized to sign");
        require(!hasSigned[msg.sender], "Already signed");

        hasSigned[msg.sender] = true;
        signatureCount++;
    }

    function withdrawWithMultisig(address payable recipient) external tenancyNotEnded {
        require(signatureCount >= 4, "Not enough signatures");
        require(deposit > 0, "No funds to withdraw");

        uint256 amount = deposit;
        deposit = 0;
        signatureCount = 0;
        for (uint i = 0; i < 6; i++) {
            hasSigned[signers[i]] = false;
        }

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");

        emit DepositWithdrawn(recipient, amount);
    }

    function endTenancy() external onlyLandlord {
        require(!tenancyEnded, "Tenancy has already ended");
        tenancyEnded = true;
        emit TenancyEnded();
    }

    function withdrawAsLandlord() external onlyLandlord {
        require(tenancyEnded, "Tenancy has not ended yet");
        require(deposit > 0, "No funds to withdraw");

        uint256 amount = deposit;
        deposit = 0;

        (bool success, ) = landlord.call{value: amount}("");
        require(success, "Transfer failed");

        emit DepositWithdrawn(landlord, amount);
    }
}