// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title SimbiToken
 * @notice A token with study group staking and reward mechanics
 * @dev Replaces ERC20Snapshot with ERC20Votes checkpointing
 */
contract SimbiToken is ERC20, ERC20Permit, ERC20Votes, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Max participants
    uint256 public constant MAX_PARTICIPANTS = 50;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");

    // Token reward parameters
    uint256 public signupReward = 50 ether;
    uint256 public loginReward = 40 ether;
    uint256 public maxBalance = 200 ether;
    mapping(address => uint256) public lastFunded;

    // Timelock
    uint256 public constant TIMELOCK_PERIOD = 2 days;
    mapping(bytes32 => uint256) public timelockSchedule;

    enum SessionState { Active, Ended, Cancelled }

    struct Participant {
        uint256 stake;
        bool completed;
        bool rewardClaimed;
    }

    struct StudySession {
        EnumerableSet.AddressSet participantSet;
        mapping(address => Participant) participants;
        uint256 deadline;
        uint256 totalStake;
        SessionState state;
        uint256 snapshotBlock;
        address[] winners;
        uint256 rewardPerWinner;
    }

    mapping(uint256 => StudySession) private sessions;

    function getSession(uint256 id) external view returns (
        address[] memory participants,
        uint256 deadline,
        uint256 totalStake,
        SessionState state,
        uint256 snapshotBlock,
        address[] memory winners,
        uint256 rewardPerWinner
    ) {
        StudySession storage s = sessions[id];
        participants = this.getSessionParticipants(id);
        deadline = s.deadline;
        totalStake = s.totalStake;
        state = s.state;
        snapshotBlock = s.snapshotBlock;
        winners = s.winners;
        rewardPerWinner = s.rewardPerWinner;
    }
    uint256 public sessionCount;

    // Events
    event UserFunded(address indexed user, uint256 amount);
    event SessionCreated(uint256 indexed sessionId, address[] participants, uint256[] stakes, uint256 deadline, uint256 snapshotBlock);
    event SessionCompleted(uint256 indexed sessionId, address[] winners);
    event SessionCancelled(uint256 indexed sessionId);
    event ParticipantCompleted(uint256 indexed sessionId, address indexed participant);
    event ParticipantMarkedComplete(uint256 indexed sessionId, address indexed participant);
    event RewardClaimed(uint256 indexed sessionId, address indexed participant, uint256 amount);
    event StakeWithdrawn(uint256 indexed sessionId, address indexed participant, uint256 amount);
    event TimelockScheduled(bytes32 indexed operationId, uint256 executeTime);
    event TimelockExecuted(bytes32 indexed operationId);
    event SignupRewardUpdated(uint256 oldValue, uint256 newValue);
    event LoginRewardUpdated(uint256 oldValue, uint256 newValue);
    event MaxBalanceUpdated(uint256 oldValue, uint256 newValue);

    // Modifiers
    modifier onlyActiveSession(uint256 id) {
        require(sessions[id].state == SessionState.Active, "Session not active");
        _;
    }
    modifier onlyEndedSession(uint256 id) {
        StudySession storage s = sessions[id];
        require(
            s.state == SessionState.Ended ||
            (s.state == SessionState.Active && block.timestamp >= s.deadline),
            "Session not ended"
        );
        _;
    }
    modifier onlyParticipant(uint256 id) {
        require(
            sessions[id].participantSet.contains(msg.sender),
            "Not a session participant"
        );
        _;
    }
    modifier nonZero(address a) {
        require(a != address(0), "Zero address");
        _;
    }

    constructor() ERC20("Simbi Token", "SIMBI") ERC20Permit("Simbi Token") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(REWARD_MANAGER_ROLE, msg.sender);
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    // ===== ERC20Votes overrides =====
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }
    function _mint(address to, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }
    function _burn(address from, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._burn(from, amount);
    }

    // ===== Token Rewards =====

    function fundNewUser(address user)
        external nonReentrant nonZero(user)
    {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(MODERATOR_ROLE, msg.sender),
            "Not authorized"
        );
        require(balanceOf(user) == 0, "Already funded");
        _mint(user, signupReward);
        lastFunded[user] = block.timestamp;
        emit UserFunded(user, signupReward);
    }

    function fundLoginReward(address user)
        external nonReentrant nonZero(user)
    {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(MODERATOR_ROLE, msg.sender),
            "Not authorized"
        );
        require(block.timestamp >= lastFunded[user] + 1 days, "24h not passed");
        uint256 bal = balanceOf(user);
        if (bal < maxBalance) {
            uint256 reward = maxBalance - bal < loginReward ? maxBalance - bal : loginReward;
            _mint(user, reward);
            lastFunded[user] = block.timestamp;
            emit UserFunded(user, reward);
        }
    }

    function batchFundLoginReward(address[] calldata users) external nonReentrant {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(MODERATOR_ROLE, msg.sender),
            "Not authorized"
        );
        for (uint256 i; i < users.length; i++) {
            address u = users[i];
            if (u != address(0) && block.timestamp >= lastFunded[u] + 1 days) {
                uint256 bal = balanceOf(u);
                if (bal < maxBalance) {
                    uint256 reward = maxBalance - bal < loginReward ? maxBalance - bal : loginReward;
                    _mint(u, reward);
                    lastFunded[u] = block.timestamp;
                    emit UserFunded(u, reward);
                }
            }
        }
    }

    // ===== Study Group Staking =====

    function createSession(
        address[] calldata participants,
        uint256[] calldata stakes,
        uint256 duration
    ) external nonReentrant {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller not admin");
        require(
            participants.length == stakes.length &&
            participants.length > 0 &&
            participants.length <= MAX_PARTICIPANTS,
            "Invalid input"
        );
        require(duration > 0, "Invalid duration");

        uint256 id = sessionCount++;
        StudySession storage s = sessions[id];
        s.deadline = block.timestamp + duration;
        s.state = SessionState.Active;
        s.snapshotBlock = block.number;

        uint256 total;
        address[] memory validP = new address[](participants.length);
        uint256[] memory validS = new uint256[](stakes.length);
        uint256 vc;

        for (uint256 i; i < participants.length; i++) {
            address p = participants[i];
            uint256 st = stakes[i];
            require(p != address(0) && st > 0, "Invalid data");
            if (s.participantSet.add(p)) {
                s.participants[p] = Participant(st, false, false);
                total += st;
                IERC20(address(this)).safeTransferFrom(p, address(this), st);
                validP[vc] = p;
                validS[vc] = st;
                vc++;
            }
        }
        // adjust arrays via assembly if vc < length
        s.totalStake = total;
        emit SessionCreated(id, validP, validS, s.deadline, s.snapshotBlock);
    }

    function markCompleted(uint256 id, address[] calldata done)
        external nonReentrant onlyActiveSession(id)
    {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(MODERATOR_ROLE, msg.sender),
            "Not authorized"
        );
        StudySession storage s = sessions[id];
        for (uint256 i; i < done.length; i++) {
            address p = done[i];
            if (
                p != address(0) &&
                s.participantSet.contains(p) &&
                !s.participants[p].completed
            ) {
                s.participants[p].completed = true;
                emit ParticipantCompleted(id, p);
            }
        }
    }

    function markSelfCompleted(uint256 id)
        external nonReentrant onlyActiveSession(id) onlyParticipant(id)
    {
        StudySession storage s = sessions[id];
        require(!s.participants[msg.sender].completed, "Already done");
        s.participants[msg.sender].completed = true;
        emit ParticipantMarkedComplete(id, msg.sender);
    }

    function endSession(uint256 id)
        public nonReentrant onlyActiveSession(id)
    {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller not admin");
        StudySession storage s = sessions[id];
        require(block.timestamp >= s.deadline, "Not ended yet");
        s.state = SessionState.Ended;

        uint256 count = s.participantSet.length();
        address[] memory wins = new address[](count);
        uint256 wc;
        for (uint256 i; i < count; i++) {
            address p = s.participantSet.at(i);
            if (s.participants[p].completed) {
                wins[wc] = p;
                wc++;
            }
        }
        assembly { mstore(wins, wc) }
        s.winners = wins;
        if (wc > 0) {
            s.rewardPerWinner = s.totalStake / wc;
        }
        emit SessionCompleted(id, wins);
    }

    function scheduleCancelSession(uint256 id)
        external onlyActiveSession(id)
    {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller not admin");
        bytes32 op = keccak256(abi.encodePacked("cancelSession", id));
        if (timelockSchedule[op] == 0) {
            timelockSchedule[op] = block.timestamp + TIMELOCK_PERIOD;
            emit TimelockScheduled(op, timelockSchedule[op]);
        }
    }

    function cancelSession(uint256 id)
        external nonReentrant onlyActiveSession(id)
    {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller not admin");
        bytes32 op = keccak256(abi.encodePacked("cancelSession", id));
        require(timelockSchedule[op] > 0, "Not scheduled");
        require(block.timestamp >= timelockSchedule[op], "Timelock not passed");
        delete timelockSchedule[op];
        sessions[id].state = SessionState.Cancelled;
        emit TimelockExecuted(op);
        emit SessionCancelled(id);
    }

    function withdrawFromCancelledSession(uint256 id)
        external nonReentrant
    {
        StudySession storage s = sessions[id];
        require(s.state == SessionState.Cancelled, "Not cancelled");
        require(s.participantSet.contains(msg.sender), "Not a participant");
        Participant storage p = s.participants[msg.sender];
        uint256 amt = p.stake;
        require(amt > 0, "Nothing to withdraw");
        p.stake = 0;
        IERC20(address(this)).safeTransfer(msg.sender, amt);
        emit StakeWithdrawn(id, msg.sender, amt);
    }

    function claimReward(uint256 id)
        external nonReentrant onlyEndedSession(id)
    {
        StudySession storage s = sessions[id];
        if (s.state == SessionState.Active && block.timestamp >= s.deadline) {
            s.state = SessionState.Ended;
        }
        require(s.participantSet.contains(msg.sender), "Not a participant");
        Participant storage p = s.participants[msg.sender];
        require(p.completed, "Did not complete");
        require(!p.rewardClaimed, "Already claimed");
        if (s.winners.length == 0) {
            endSession(id);
        }
        require(s.rewardPerWinner > 0, "No reward set");
        p.rewardClaimed = true;
        IERC20(address(this)).safeTransfer(msg.sender, s.rewardPerWinner);
        emit RewardClaimed(id, msg.sender, s.rewardPerWinner);
    }

    function batchClaimRewards(uint256[] calldata ids)
        external nonReentrant
    {
        for (uint256 i; i < ids.length; i++) {
            uint256 id = ids[i];
            StudySession storage s = sessions[id];
            if (!(s.state == SessionState.Ended || (s.state == SessionState.Active && block.timestamp >= s.deadline))) {
                continue;
            }
            if (s.state == SessionState.Active) s.state = SessionState.Ended;
            if (!s.participantSet.contains(msg.sender)) continue;
            Participant storage p = s.participants[msg.sender];
            if (!p.completed || p.rewardClaimed) continue;
            if (s.winners.length == 0) endSession(id);
            if (s.rewardPerWinner == 0) continue;
            p.rewardClaimed = true;
            IERC20(address(this)).safeTransfer(msg.sender, s.rewardPerWinner);
            emit RewardClaimed(id, msg.sender, s.rewardPerWinner);
        }
    }

    // ===== Admin reward updates with timelock =====
    function scheduleUpdateSignupReward(uint256 nv) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(REWARD_MANAGER_ROLE, msg.sender),
            "Not authorized"
        );
        bytes32 op = keccak256(abi.encodePacked("updateSignupReward", nv));
        if (timelockSchedule[op] == 0) {
            timelockSchedule[op] = block.timestamp + TIMELOCK_PERIOD;
            emit TimelockScheduled(op, timelockSchedule[op]);
        }
    }
    function updateSignupReward(uint256 nv) external nonReentrant {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(REWARD_MANAGER_ROLE, msg.sender),
            "Not authorized"
        );
        bytes32 op = keccak256(abi.encodePacked("updateSignupReward", nv));
        require(timelockSchedule[op] > 0 && block.timestamp >= timelockSchedule[op], "Timelock");
        delete timelockSchedule[op];
        uint256 old = signupReward;
        signupReward = nv;
        emit TimelockExecuted(op);
        emit SignupRewardUpdated(old, nv);
    }
    function scheduleUpdateLoginReward(uint256 nv) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(REWARD_MANAGER_ROLE, msg.sender),
            "Not authorized"
        );
        bytes32 op = keccak256(abi.encodePacked("updateLoginReward", nv));
        if (timelockSchedule[op] == 0) {
            timelockSchedule[op] = block.timestamp + TIMELOCK_PERIOD;
            emit TimelockScheduled(op, timelockSchedule[op]);
        }
    }
    function updateLoginReward(uint256 nv) external nonReentrant {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(REWARD_MANAGER_ROLE, msg.sender),
            "Not authorized"
        );
        bytes32 op = keccak256(abi.encodePacked("updateLoginReward", nv));
        require(timelockSchedule[op] > 0 && block.timestamp >= timelockSchedule[op], "Timelock");
        delete timelockSchedule[op];
        uint256 old = loginReward;
        loginReward = nv;
        emit TimelockExecuted(op);
        emit LoginRewardUpdated(old, nv);
    }
    function scheduleUpdateMaxBalance(uint256 nv) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(REWARD_MANAGER_ROLE, msg.sender),
            "Not authorized"
        );
        bytes32 op = keccak256(abi.encodePacked("updateMaxBalance", nv));
        if (timelockSchedule[op] == 0) {
            timelockSchedule[op] = block.timestamp + TIMELOCK_PERIOD;
            emit TimelockScheduled(op, timelockSchedule[op]);
        }
    }
    function updateMaxBalance(uint256 nv) external nonReentrant {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(REWARD_MANAGER_ROLE, msg.sender),
            "Not authorized"
        );
        bytes32 op = keccak256(abi.encodePacked("updateMaxBalance", nv));
        require(timelockSchedule[op] > 0 && block.timestamp >= timelockSchedule[op], "Timelock");
        delete timelockSchedule[op];
        uint256 old = maxBalance;
        maxBalance = nv;
        emit TimelockExecuted(op);
        emit MaxBalanceUpdated(old, nv);
    }

    function grantRole(bytes32 role, address account)
        public override nonZero(account)
    {
        super.grantRole(role, account);
    }

    // ===== View Helpers =====
    function getSessionParticipants(uint256 id) external view returns (address[] memory) {
        StudySession storage s = sessions[id];
        uint256 l = s.participantSet.length();
        address[] memory arr = new address[](l);
        for (uint256 i; i < l; i++) arr[i] = s.participantSet.at(i);
        return arr;
    }
    function getParticipantStake(uint256 id, address p) external view returns (uint256) {
        return sessions[id].participants[p].stake;
    }
    function hasCompleted(uint256 id, address p) external view returns (bool) {
        return sessions[id].participants[p].completed;
    }
    function getSessionState(uint256 id) external view returns (SessionState) {
        StudySession storage s = sessions[id];
        if (s.state == SessionState.Active && block.timestamp >= s.deadline) {
            return SessionState.Ended;
        }
        return s.state;
    }
    function getSessionWinners(uint256 id) external view returns (address[] memory) {
        StudySession storage s = sessions[id];
        if (s.winners.length > 0) return s.winners;
        if (!(s.state == SessionState.Ended || (s.state == SessionState.Active && block.timestamp >= s.deadline))) {
            return new address[](0);
        }
        uint256 l = s.participantSet.length();
        address[] memory arr = new address[](l);
        uint256 c;
        for (uint256 i; i < l; i++) {
            address p = s.participantSet.at(i);
            if (s.participants[p].completed) {
                arr[c++] = p;
            }
        }
        assembly { mstore(arr, c) }
        return arr;
    }
}