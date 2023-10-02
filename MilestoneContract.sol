// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MilestoneContract {
    enum MilestoneStatus { Created, Submitted, Approved, Rejected }

    struct Milestone {
        uint256 id;
        uint256 projectId;
        address employer;
        address freelancer;
        string description;
        uint256 deadline;
        uint256 amount;
        MilestoneStatus status;
    }

    struct MilestoneProposal {
        uint256 milestoneId;
        address freelancer;
        string workProof;
        string comments;
    }

    struct Dispute {
        uint256 disputeId;
        uint256 milestoneId;
        address initiator; // Either employer or freelancer
        string evidence;
        bool resolved;
    }

    Milestone[] public milestones;
    MilestoneProposal[] public milestoneProposals;
    Dispute[] public disputes;

    uint256 public milestoneCounter;
    uint256 public disputeCounter;
    uint256 public decisionPeriod; // Define the decision-making period in seconds (e.g., 7 days).

    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event MilestoneCreated(uint256 indexed milestoneId, uint256 indexed projectId);
    event MilestoneSubmitted(uint256 indexed milestoneId);
    event MilestoneApproved(uint256 indexed milestoneId);
    event MilestoneRejected(uint256 indexed milestoneId);
    event MilestoneProposalSubmitted(uint256 indexed milestoneId, address indexed freelancer);
    event MilestoneDisputeInitiated(uint256 indexed milestoneId, address indexed initiator);
    event MilestoneDisputeResolved(uint256 indexed disputeId, address indexed arbitrator, bool decision);

    modifier onlyEmployer(uint256 milestoneId) {
        require(msg.sender == milestones[milestoneId].employer, "Only the employer can call this function.");
        _;
    }

    modifier onlyFreelancer(uint256 milestoneId) {
        require(msg.sender == milestones[milestoneId].freelancer, "Only the freelancer can call this function.");
        _;
    }

    modifier onlyParticipant(uint256 milestoneId) {
        require(
            msg.sender == milestones[milestoneId].employer || msg.sender == milestones[milestoneId].freelancer,
            "Only the employer or freelancer can call this function."
        );
        _;
    }

    constructor() {
        milestoneCounter = 1; // Initialize milestone counter at 1 (assuming milestone IDs start from 1).
        disputeCounter = 1;
        decisionPeriod = 7 days; // Set the decision-making period to 7 days (adjust as needed).
    }

    function createMilestone(uint256 _projectId, string memory _description, uint256 _deadline, uint256 _amount) external {
        milestones.push(Milestone(milestoneCounter, _projectId, msg.sender, address(0), _description, _deadline, _amount, MilestoneStatus.Created));
        emit MilestoneCreated(milestoneCounter, _projectId);
        milestoneCounter++;
    }

    function submitMilestone(uint256 _milestoneId, string memory _workProof, string memory _comments) external onlyFreelancer(_milestoneId) {
        require(milestones[_milestoneId].status == MilestoneStatus.Created, "Milestone has already been submitted or processed.");
        milestones[_milestoneId].status = MilestoneStatus.Submitted;
        milestones[_milestoneId].freelancer = msg.sender;
        emit MilestoneSubmitted(_milestoneId);
        milestoneProposals.push(MilestoneProposal(_milestoneId, msg.sender, _workProof, _comments));
        emit MilestoneProposalSubmitted(_milestoneId, msg.sender);
    }

    function approveMilestone(uint256 _milestoneId) external onlyEmployer(_milestoneId) {
        require(milestones[_milestoneId].status == MilestoneStatus.Submitted, "Milestone is not in the Submitted state.");
        require(block.timestamp <= milestones[_milestoneId].deadline + decisionPeriod, "Decision period has passed.");
        
        milestones[_milestoneId].status = MilestoneStatus.Approved;
        uint256 amountToRelease = milestones[_milestoneId].amount;
        payable(milestones[_milestoneId].freelancer).transfer(amountToRelease);
        emit MilestoneApproved(_milestoneId);
    }

    function rejectMilestone(uint256 _milestoneId, string memory _reason) external onlyEmployer(_milestoneId) {
        require(milestones[_milestoneId].status == MilestoneStatus.Submitted, "Milestone is not in the Submitted state.");
        milestones[_milestoneId].status = MilestoneStatus.Rejected;
        emit MilestoneRejected(_milestoneId);
        initiateDispute(_milestoneId, _reason);
    }

    function initiateDispute(uint256 _milestoneId, string memory _evidence) public onlyParticipant(_milestoneId) {
        require(milestones[_milestoneId].status == MilestoneStatus.Rejected, "Dispute can only be initiated for rejected milestones.");
        disputes.push(Dispute(disputeCounter, _milestoneId, msg.sender, _evidence, false));
        emit MilestoneDisputeInitiated(_milestoneId, msg.sender);
        disputeCounter++;
    }

    function resolveDispute(uint256 _disputeId, bool _decision) external {
        require(!disputes[_disputeId].resolved, "Dispute has already been resolved.");
        disputes[_disputeId].resolved = true;
        emit MilestoneDisputeResolved(_disputeId, msg.sender, _decision);
        if (_decision) {
            uint256 milestoneId = disputes[_disputeId].milestoneId;
            uint256 amountToRelease = milestones[milestoneId].amount;
            payable(milestones[milestoneId].freelancer).transfer(amountToRelease);
        }
    }

    // Function to automatically approve the milestone if the decision period has passed.
    function autoApproveMilestone(uint256 _milestoneId) external {
        require(milestones[_milestoneId].status == MilestoneStatus.Submitted, "Milestone is not in the Submitted state.");
        require(block.timestamp > milestones[_milestoneId].deadline + decisionPeriod, "Decision period has not passed.");

        milestones[_milestoneId].status = MilestoneStatus.Approved;
        uint256 amountToRelease = milestones[_milestoneId].amount;
        payable(milestones[_milestoneId].freelancer).transfer(amountToRelease);
        emit MilestoneApproved(_milestoneId);
    }

    function getMilestone(uint256 _milestoneId) external view returns (
        uint256 id,
        uint256 projectId,
        address employer,
        address freelancer,
        string memory description,
        uint256 deadline,
        uint256 amount,
        MilestoneStatus status
    ) {
        Milestone storage milestone = milestones[_milestoneId];
        return (
            milestone.id,
            milestone.projectId,
            milestone.employer,
            milestone.freelancer,
            milestone.description,
            milestone.deadline,
            milestone.amount,
            milestone.status
        );
    }

    function getMilestoneProposal(uint256 _milestoneId) external view returns (
        uint256 milestoneId,
        address freelancer,
        string memory workProof,
        string memory comments
    ) {
        MilestoneProposal memory proposal;
        for (uint256 i = 0; i < milestoneProposals.length; i++) {
            if (milestoneProposals[i].milestoneId == _milestoneId) {
                proposal = milestoneProposals[i];
                break;
            }
        }
        return (
            proposal.milestoneId,
            proposal.freelancer,
            proposal.workProof,
            proposal.comments
        );
    }

    function getDispute(uint256 _disputeId) external view returns (
        uint256 disputeId,
        uint256 milestoneId,
        address initiator,
        string memory evidence,
        bool resolved
    ) {
        Dispute storage dispute = disputes[_disputeId];
        return (
            dispute.disputeId,
            dispute.milestoneId,
            dispute.initiator,
            dispute.evidence,
            dispute.resolved
        );
    }
}
