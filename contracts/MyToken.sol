// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RingoToken is ERC20, Ownable, ReentrancyGuard {
    uint256 public initialSupply = 1000000 * (10 ** 18); // 1 million tokens with 18 decimal places
    uint256 public transactionFeeRate = 25; // Initial transaction fee rate: 0.25%
    mapping(address => bool) public feeExempted; // Addresses that are exempt from transaction fees

    struct Proposal {
        string description;
        bool executed;
        uint256 affirmativeVotes;
        uint256 negativeVotes;
        mapping(address => bool) hasVoted;
    }

    Proposal[] public proposals;

    event FeesWithdrawn(uint256 amount, address to);
    event ProposalCreated(uint256 id, string description);
    event Voted(uint256 id, address voter, bool vote, uint256 weight);
    event ProposalExecuted(uint256 id, bool successful, string description);

    constructor() ERC20("RingoToken", "RNG") {
        _mint(msg.sender, initialSupply);
        feeExempted[msg.sender] = true;
    }

    // Override to include ReentrancyGuard
    function transfer(address recipient, uint256 amount) public override nonReentrant returns (bool) {
        uint256 fee = calculateFee(amount);
        uint256 amountAfterFee = amount - fee;
        
        _transfer(_msgSender(), recipient, amountAfterFee);
        if (fee > 0 && !feeExempted[_msgSender()]) {
            _transfer(_msgSender(), address(this), fee);
            _burn(address(this), fee); // Burn the fees to prevent circulation increase
        }
        return true;
    }

    function calculateFee(uint256 amount) public view returns (uint256) {
        if (feeExempted[_msgSender()]) {
            return 0;
        }
        return (amount * transactionFeeRate) / 10000;
    }

    // Withdraw fees as tokens instead of ETH
    function withdrawFees(address to) public onlyOwner {
        uint256 fees = balanceOf(address(this));
        _transfer(address(this), to, fees);
        emit FeesWithdrawn(fees, to);
    }

    function createProposal(string memory description) public onlyOwner {
        proposals.push(Proposal({
            description: description,
            executed: false,
            affirmativeVotes: 0,
            negativeVotes: 0
        }));
        emit ProposalCreated(proposals.length - 1, description);
    }

    // Allow voting against proposals
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

    function executeProposal(uint256 proposalId) public onlyOwner {
        require(proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.affirmativeVotes > proposal.negativeVotes, "More votes against than for");

        proposal.executed = true;
        // Implementation logic based on the proposal's description or id
        emit ProposalExecuted(proposalId, true, proposal.description);
    }

    function adjustTransactionFee(uint256 newFeeRate) public onlyOwner {
        require(newFeeRate <= 100, "Fee rate too high"); // Max 1%
        transactionFeeRate = newFeeRate;
    }
}
