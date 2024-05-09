// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RingoToken is ERC20, Ownable, ReentrancyGuard, AccessControl {
    uint256 public initialSupply = 1000000 * (10 ** 18); // 1 million tokens with 18 decimal places
    uint256 public transactionFeeRate = 25; // Initial transaction fee rate: 0.25%
    address public treasuryAddress; // Treasury address for storing fees
    mapping(address => bool) public feeExempted; // Addresses that are exempt from transaction fees
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Proposal {
        string description;
        bool executed;
        uint256 affirmativeVotes;
        uint256 negativeVotes;
        mapping(address => bool) hasVoted;
    }

    Proposal[] public proposals;

    event FeesRedirected(uint256 amount, address to);
    event ProposalCreated(uint256 id, string description);
    event Voted(uint256 id, address voter, bool vote, uint256 weight);
    event ProposalExecuted(uint256 id, bool successful, string description);
    event TransactionFeeAdjusted(uint256 newFeeRate);
    event TreasuryAddressUpdated(address newAddress);
    event RoleGranted(bytes32 role, address account);
    event RoleRevoked(bytes32 role, address account);

    constructor(address _treasuryAddress) ERC20("RingoToken", "RNG") {
        _mint(msg.sender, initialSupply);
        treasuryAddress = _treasuryAddress;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        feeExempted[msg.sender] = true; // Owner is exempted by default
    }

    function transfer(address recipient, uint256 amount) public override nonReentrant returns (bool) {
        uint256 fee = calculateFee(amount);
        uint256 amountAfterFee = amount - fee;
        
        _transfer(_msgSender(), recipient, amountAfterFee);
        if (fee > 0 && !feeExempted[_msgSender()]) {
            _transfer(_msgSender(), treasuryAddress, fee);
            emit FeesRedirected(fee, treasuryAddress);
        }
        return true;
    }

    function calculateFee(uint256 amount) public view returns (uint256) {
        if (feeExempted[_msgSender()]) {
            return 0;
        }
        return (amount * transactionFeeRate) / 10000;
    }

    function adjustTransactionFee(uint256 newFeeRate) public onlyRole(ADMIN_ROLE) {
        require(newFeeRate <= 100, "Fee rate too high"); // Max 1%
        transactionFeeRate = newFeeRate;
        emit TransactionFeeAdjusted(newFeeRate);
    }

    function updateTreasuryAddress(address newAddress) public onlyRole(ADMIN_ROLE) {
        require(newAddress != address(0), "Invalid address");
        treasuryAddress = newAddress;
        emit TreasuryAddressUpdated(newAddress);
    }

    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        super.grantRole(role, account);
        emit RoleGranted(role, account);
    }

    function revokeRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        super.revokeRole(role, account);
        emit RoleRevoked(role, account);
    }

    // Additional functions and modifiers can be implemented as needed
}
