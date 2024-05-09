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

    uint256 public minQuorumPercent = 25; // Minimum quorum needed for proposal votes
    Proposal[] public proposals;

    event FeesRedirected(uint256 amount, address to);
    event ProposalCreated(uint256 id, string description);
    event Voted(uint256 id, address voter, bool vote, uint256 weight);
    event ProposalExecuted(uint256 id, bool successful, string description);
    event RoleUpdated(bytes32 role, address account, bool isGranted);

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

    function setFeeExemption(address account, bool isExempt) public onlyRole(ADMIN_ROLE) {
        feeExempted[account] = isExempt;
        emit RoleUpdated(ADMIN_ROLE, account, isExempt);
    }

    function createProposal(string memory description) public {
        require(bytes(description).length > 0, "Description cannot be empty");
        proposals.push(Proposal({
            description: description,
            executed: false,
            affirmativeVotes: 0,
            negativeVotes: 0
        }));
        emit ProposalCreated(proposals.length - 1, description);
    }

    function voteOnProposal(uint256 proposalId, bool approve) public {
        require(proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[_msgSender()], "Already voted");
        require(!proposal.executed, "Proposal already executed");

        uint256 weight = balanceOf(_msgSender());
        proposal.hasVoted[_msgSender()] = true;

        if (approve) {
            proposal.affirmativeVotes += weight;
        } else {
            proposal.negativeVotes += weight;
        }
        emit Voted(proposalId, _msgSender(), approve, weight);
    }

    function executeProposal(uint256 proposalId) public {
        require(proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.affirmativeVotes > proposal.negativeVotes, "More votes against than for");
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        uint256 totalVotes = proposal.affirmativeVotes + proposal.negativeVotes;
        require(totalVotes >= (totalSupply() * minQuorumPercent) / 100, "Quorum not met");

        proposal.executed = true;
        emit ProposalExecuted(proposalId, true, proposal.description);
        // Implementation logic based on the proposal's description or id
    }

    function adjustTransactionFee(uint256 newFeeRate) public onlyRole(ADMIN_ROLE) {
        require(newFeeRate <= 100, "Fee rate too high"); // Max 1%
        transactionFeeRate = newFeeRate;
    }
}
