// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RingoToken is ERC20, Ownable, ReentrancyGuard, AccessControl {
    uint256 public initialSupply = 1000000 * (10 ** 18);
    uint256 public transactionFeeRate = 25;
    address public treasuryAddress;
    mapping(address => bool) public feeExempted;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event FeeExemptionChanged(address indexed account, bool isExempt);
    event TreasuryAddressChanged(address oldAddress, address newAddress);

    constructor(address _treasuryAddress) ERC20("RingoToken", "RNG") {
        _mint(msg.sender, initialSupply);
        treasuryAddress = _treasuryAddress;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        feeExempted[msg.sender] = true;
    }

    function transfer(address recipient, uint256 amount) public override nonReentrant returns (bool) {
        uint256 fee = calculateFee(amount);
        uint256 amountAfterFee = amount - fee;
        _transfer(_msgSender(), recipient, amountAfterFee);
        if (fee > 0 && !feeExempted[_msgSender()]) {
            _transfer(_msgSender(), treasuryAddress, fee);
        }
        return true;
    }

    function calculateFee(uint256 amount) public view returns (uint256) {
        if (feeExempted[_msgSender()]) {
            return 0;
        }
        return (amount * transactionFeeRate) / 10000;
    }

    function setFeeExemption(address account, bool isExempt) public onlyRole(ADMIN_ROLE) {
        feeExempted[account] = isExempt;
        emit FeeExemptionChanged(account, isExempt);
    }

    function updateTreasuryAddress(address newAddress) public onlyRole(ADMIN_ROLE) {
        require(newAddress != address(0), "Invalid address");
        emit TreasuryAddressChanged(treasuryAddress, newAddress);
        treasuryAddress = newAddress;
    }

    // Additional robustness, checks, and features should be implemented based on specific needs.
}
