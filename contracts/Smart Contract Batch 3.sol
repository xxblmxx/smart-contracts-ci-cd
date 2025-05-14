// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// ------------------------------
/// 11. DAO Voting Contract
/// ------------------------------
contract DAO {
    struct Proposal {
        string description;
        uint voteCount;
        bool executed;
    }

    address public chairperson;
    mapping(address => bool) public voters;
    Proposal[] public proposals;

    constructor() {
        chairperson = msg.sender;
        voters[msg.sender] = true;
    }

    function addVoter(address voter) external {
        require(msg.sender == chairperson, "Not chairperson");
        voters[voter] = true;
    }

    function createProposal(string memory description) public {
        require(voters[msg.sender], "Not authorized");
        proposals.push(Proposal(description, 0, false));
    }

    function vote(uint proposalIndex) public {
        require(voters[msg.sender], "Not authorized");
        proposals[proposalIndex].voteCount++;
    }

    function executeProposal(uint proposalIndex) public {
        require(proposals[proposalIndex].voteCount > 2, "Not enough votes");
        proposals[proposalIndex].executed = true;
        // Simulate execution logic here
    }
}

/// ------------------------------
/// 12. On-Chain Will / Inheritance Contract
/// ------------------------------
contract Will {
    address public owner;
    address public heir;
    uint public lastPing;
    uint public timeout = 30 days;

    constructor(address _heir) payable {
        owner = msg.sender;
        heir = _heir;
        lastPing = block.timestamp;
    }

    function ping() external {
        require(msg.sender == owner);
        lastPing = block.timestamp;
    }

    function claimInheritance() external {
        require(block.timestamp > lastPing + timeout, "Owner is still alive");
        require(msg.sender == heir, "Not heir");
        payable(heir).transfer(address(this).balance);
    }
}

/// ------------------------------
/// 13. Decentralized Payroll
/// ------------------------------
contract Payroll {
    address public admin;
    mapping(address => uint) public salaries;
    mapping(address => uint) public lastPaid;

    constructor() {
        admin = msg.sender;
    }

    function setSalary(address employee, uint salary) external {
        require(msg.sender == admin);
        salaries[employee] = salary;
    }

    function pay(address employee) external {
        require(block.timestamp > lastPaid[employee] + 30 days, "Already paid this month");
        lastPaid[employee] = block.timestamp;
        payable(employee).transfer(salaries[employee]);
    }

    receive() external payable {}
}

/// ------------------------------
/// 14. E-Signature Contract Registry
/// ------------------------------
contract SignatureRegistry {
    mapping(bytes32 => address) public documentSigner;

    function signDocument(string memory docHash) public {
        bytes32 hash = keccak256(abi.encodePacked(docHash));
        require(documentSigner[hash] == address(0), "Already signed");
        documentSigner[hash] = msg.sender;
    }

    function verifySignature(string memory docHash, address expectedSigner) public view returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(docHash));
        return documentSigner[hash] == expectedSigner;
    }
}

/// ------------------------------
/// 15. Smart Legal Arbitration
/// ------------------------------
contract LegalArbitration {
    address public initiator;
    address public respondent;
    address public arbitrator;
    string public caseSummary;
    bool public caseClosed;
    string public decision;

    constructor(address _respondent, address _arbitrator, string memory _summary) {
        initiator = msg.sender;
        respondent = _respondent;
        arbitrator = _arbitrator;
        caseSummary = _summary;
    }

    function closeCase(string memory _decision) public {
        require(msg.sender == arbitrator, "Only arbitrator");
        caseClosed = true;
        decision = _decision;
    }
}
