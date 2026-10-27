// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ThinPoWToken (THIN)
 * @notice High-fairness Sequential-64 Keccak-256 Proof-of-Work token on Base Mainnet.
 * Features:
 *  1. Bitcoin-style 21,000,000 THIN maximum supply with 210,000-epoch halving.
 *  2. 64-step Serial Dependency Proof-of-Work algorithm (anti-ASIC / anti-GPU).
 *  3. 300-second consecutive block cooldown (Old-PC fairness window).
 *  4. Emergency Difficulty Decay (auto-decay prevents chain stall).
 *  5. Built-in Loyalty Staking Pool (3.50% drip) with `mineAndStake()` 1-tx auto-compounding.
 *  6. Golden Block 1-in-64 Rollover Jackpot (1.50% allocation).
 *  7. Dev ecosystem contribution lowered to 0.90% (94.10% goes directly to miner).
 */
contract ThinPoWToken is ERC20, ReentrancyGuard {
    uint256 public constant MAX_SUPPLY = 21_000_000 ether;
    uint256 public constant MAX_GENESIS_SUPPLY = 2_100_000 ether; // Max 10%
    uint256 public constant INITIAL_REWARD = 50 ether;
    uint256 public constant HALVING_INTERVAL = 210_000;
    uint256 public constant TARGET_EPOCH_TIME = 300; // 5 minutes
    uint256 public constant ADJUSTMENT_INTERVAL = 10; // Retarget every 10 epochs
    uint256 public constant SEQUENTIAL_STEPS = 64; // Serial dependency chain depth

    // Fee & Distribution Splits (10,000 BPS = 100%)
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MINER_REWARD_BPS = 9_410; // 94.10% to Miner
    uint256 public constant STAKER_MINING_BPS = 350;  // 3.50% to Loyalty Staking Pool
    uint256 public constant JACKPOT_MINING_BPS = 150; // 1.50% to Golden Block Jackpot
    uint256 public constant DEV_MINING_BPS = 90;      // 0.90% to Dev Wallet

    // Golden Block Mask: bottom 6 bits == 0x3F (exact 1-in-64 chance on valid PoW)
    uint256 public constant GOLDEN_BLOCK_MASK = 0x3F;
    uint256 public constant JACKPOT_WIN_BPS = 8_000; // 80% payout / 20% rollover

    uint256 private constant ACC_PRECISION = 1e18;

    uint256 public constant MAX_TARGET = type(uint256).max >> 7;
    uint256 public constant INITIAL_TARGET = type(uint256).max >> 8;
    uint256 public constant MIN_TARGET = 1 << 160;

    address public immutable devWallet;

    bytes32 public challengeNumber;
    uint256 public miningTarget;
    uint256 public epochCount;
    uint256 public lastEpochTime;
    uint256 public intervalStartTime;
    address public lastMiner;

    // Staking & Jackpot State
    uint256 public totalStaked;
    uint256 public accRewardPerShare;
    uint256 public unallocatedRewards;
    uint256 public jackpotPot;
    uint256 public goldenBlocksMined;
    address public lastGoldenWinner;
    uint256 public lastGoldenPayout;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public claimableRewards;
    mapping(address => uint256) public lastMinedEpoch;
    mapping(address => uint256) public blocksMinedBy;
    mapping(address => uint256) public goldenBlocksWonBy;

    error GenesisSupplyTooHigh();
    error MaxSupplyReached();
    error ConsecutiveEpochCooldown(uint256 unlockTime);
    error InvalidProofOfWork(uint256 digest, uint256 target);
    error ZeroAmount();
    error InsufficientStake();

    event EpochMined(
        uint256 indexed epoch,
        address indexed miner,
        uint256 totalMinerPayout,
        uint256 jackpotWon,
        bool autoStaked,
        uint256 nonce,
        bytes32 digest,
        bytes32 newChallenge
    );
    event GoldenBlockWon(
        uint256 indexed epoch,
        address indexed winner,
        uint256 jackpotAmount,
        bytes32 digest
    );
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    constructor(address genesisRecipient, uint256 genesisSupply) ERC20("Thin PoW Coin", "THIN") {
        if (genesisSupply > MAX_GENESIS_SUPPLY) revert GenesisSupplyTooHigh();
        devWallet = genesisRecipient != address(0) ? genesisRecipient : msg.sender;

        if (genesisSupply > 0 && genesisRecipient != address(0)) {
            _mint(genesisRecipient, genesisSupply);
        }

        miningTarget = INITIAL_TARGET;
        lastEpochTime = block.timestamp;
        intervalStartTime = block.timestamp;
        bytes32 prevHash = block.number > 0 ? blockhash(block.number - 1) : bytes32(0);
        challengeNumber = keccak256(abi.encodePacked(prevHash, block.prevrandao, address(this), block.timestamp));
    }

    /// @notice Computes 64-step sequential digest for challenge, miner, and nonce.
    function computeDigest(bytes32 challenge, address miner, uint256 nonce) public pure returns (bytes32 digest) {
        digest = keccak256(abi.encodePacked(challenge, miner, nonce));
        for (uint256 i = 1; i < SEQUENTIAL_STEPS; ) {
            digest = keccak256(abi.encodePacked(digest, challenge, i));
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Checks if valid PoW digest satisfies the 1-in-64 Golden Block jackpot mask.
    function isGoldenDigest(bytes32 digest) public pure returns (bool) {
        return (uint256(digest) & GOLDEN_BLOCK_MASK) == GOLDEN_BLOCK_MASK;
    }

    /// @notice Returns active target incorporating Emergency Difficulty Decay if elapsed time > 10m.
    function effectiveTarget() public view returns (uint256 target) {
        target = miningTarget;
        uint256 elapsed = block.timestamp > lastEpochTime ? block.timestamp - lastEpochTime : 0;
        if (elapsed > TARGET_EPOCH_TIME * 2) {
            uint256 missedWindows = (elapsed / TARGET_EPOCH_TIME) - 1;
            if (missedWindows >= 244) {
                return MAX_TARGET;
            }
            uint256 decayed = target << missedWindows;
            if (decayed < target || decayed > MAX_TARGET) {
                return MAX_TARGET;
            }
            return decayed;
        }
    }

    /// @notice Current epoch block reward with halving schedule.
    function currentReward() public view returns (uint256) {
        if (totalSupply() >= MAX_SUPPLY) return 0;
        uint256 halvings = epochCount / HALVING_INTERVAL;
        if (halvings >= 64) return 0;
        uint256 reward = INITIAL_REWARD >> halvings;
        uint256 remaining = MAX_SUPPLY - totalSupply();
        return reward > remaining ? remaining : reward;
    }

    /// @notice Standard liquid mining call.
    function mine(uint256 nonce) external returns (uint256 totalMinerPayout) {
        return _mineCore(msg.sender, nonce, false);
    }

    /// @notice Auto-compounding 1-tx mine and stake.
    function mineAndStake(uint256 nonce) external returns (uint256 totalMinerPayout) {
        return _mineCore(msg.sender, nonce, true);
    }

    function _mineCore(address miner, uint256 nonce, bool autoStake) internal returns (uint256 totalMinerPayout) {
        uint256 totalEpochReward = currentReward();
        if (totalEpochReward == 0) revert MaxSupplyReached();

        // 300s consecutive-block cooldown for fairness
        if (miner == lastMiner && epochCount > 0 && block.timestamp < lastEpochTime + TARGET_EPOCH_TIME) {
            revert ConsecutiveEpochCooldown(lastEpochTime + TARGET_EPOCH_TIME);
        }

        uint256 activeTarget = effectiveTarget();
        bytes32 digest = computeDigest(challengeNumber, miner, nonce);
        if (uint256(digest) > activeTarget) {
            revert InvalidProofOfWork(uint256(digest), activeTarget);
        }

        if (activeTarget > miningTarget) {
            miningTarget = activeTarget;
        }

        unchecked {
            ++epochCount;
            ++blocksMinedBy[miner];
        }
        lastMiner = miner;
        lastMinedEpoch[miner] = epochCount;
        lastEpochTime = block.timestamp;

        if (epochCount % ADJUSTMENT_INTERVAL == 0) {
            _retarget();
        }

        challengeNumber = keccak256(abi.encodePacked(challengeNumber, digest, miner, block.timestamp));

        (uint256 payout, uint256 jackpotWon) = _processEpochRewards(miner, totalEpochReward, digest, autoStake);
        totalMinerPayout = payout;

        emit EpochMined(epochCount, miner, totalMinerPayout, jackpotWon, autoStake, nonce, digest, challengeNumber);
    }

    function _processEpochRewards(
        address miner,
        uint256 totalEpochReward,
        bytes32 digest,
        bool autoStake
    ) internal returns (uint256 totalMinerPayout, uint256 jackpotWon) {
        uint256 stakerReward = (totalEpochReward * STAKER_MINING_BPS) / BPS_DENOMINATOR;
        uint256 jackpotContribution = (totalEpochReward * JACKPOT_MINING_BPS) / BPS_DENOMINATOR;
        uint256 devReward = (totalEpochReward * DEV_MINING_BPS) / BPS_DENOMINATOR; // 0.90%
        uint256 baseMinerReward = totalEpochReward - stakerReward - jackpotContribution - devReward; // 94.10%

        if (devReward > 0) {
            _mint(devWallet, devReward);
        }

        uint256 contractMint = stakerReward + jackpotContribution;
        if (contractMint > 0) {
            _mint(address(this), contractMint);
        }
        jackpotPot += jackpotContribution;

        if (isGoldenDigest(digest) && jackpotPot > 0) {
            jackpotWon = (jackpotPot * JACKPOT_WIN_BPS) / BPS_DENOMINATOR;
            jackpotPot -= jackpotWon;
            unchecked {
                ++goldenBlocksMined;
                ++goldenBlocksWonBy[miner];
            }
            lastGoldenWinner = miner;
            lastGoldenPayout = jackpotWon;
            emit GoldenBlockWon(epochCount, miner, jackpotWon, digest);
        }

        totalMinerPayout = baseMinerReward + jackpotWon;

        if (autoStake) {
            _harvest(miner);
            if (baseMinerReward > 0) {
                _mint(address(this), baseMinerReward);
            }
            stakedBalance[miner] += totalMinerPayout;
            totalStaked += totalMinerPayout;
            if (unallocatedRewards > 0) {
                uint256 toDistribute = unallocatedRewards;
                unallocatedRewards = 0;
                accRewardPerShare += (toDistribute * ACC_PRECISION) / totalStaked;
            }
            rewardDebt[miner] = (stakedBalance[miner] * accRewardPerShare) / ACC_PRECISION;
            emit Staked(miner, totalMinerPayout);
        } else {
            if (baseMinerReward > 0) {
                _mint(miner, baseMinerReward);
            }
            if (jackpotWon > 0) {
                _transfer(address(this), miner, jackpotWon);
            }
        }

        if (stakerReward > 0) {
            _distributeStakerRewards(stakerReward);
        }
    }

    function _harvest(address user) internal {
        if (totalStaked > 0 && unallocatedRewards > 0) {
            uint256 toDistribute = unallocatedRewards;
            unallocatedRewards = 0;
            accRewardPerShare += (toDistribute * ACC_PRECISION) / totalStaked;
        }
        uint256 userStake = stakedBalance[user];
        if (userStake > 0) {
            uint256 accrued = (userStake * accRewardPerShare) / ACC_PRECISION - rewardDebt[user];
            if (accrued > 0) {
                claimableRewards[user] += accrued;
            }
        }
    }

    function _distributeStakerRewards(uint256 amount) internal {
        if (amount == 0) return;
        if (totalStaked == 0) {
            unallocatedRewards += amount;
        } else {
            uint256 totalToDistribute = amount + unallocatedRewards;
            if (unallocatedRewards > 0) {
                unallocatedRewards = 0;
            }
            accRewardPerShare += (totalToDistribute * ACC_PRECISION) / totalStaked;
        }
    }

    function _retarget() internal {
        uint256 actualTime = block.timestamp > intervalStartTime ? block.timestamp - intervalStartTime : 1;
        uint256 idealTime = TARGET_EPOCH_TIME * ADJUSTMENT_INTERVAL;

        if (actualTime < idealTime / 4) {
            actualTime = idealTime / 4;
        } else if (actualTime > idealTime * 4) {
            actualTime = idealTime * 4;
        }

        uint256 newTarget = (miningTarget / idealTime) * actualTime;
        if (newTarget < MIN_TARGET) {
            newTarget = MIN_TARGET;
        } else if (newTarget > MAX_TARGET) {
            newTarget = MAX_TARGET;
        }

        miningTarget = newTarget;
        intervalStartTime = block.timestamp;
    }

    // -------------------------------------------------------------------------
    // Public Staking & Yield Portal
    // -------------------------------------------------------------------------

    function pendingRewards(address user) external view returns (uint256) {
        uint256 userStake = stakedBalance[user];
        uint256 currentAcc = accRewardPerShare;
        if (totalStaked > 0 && unallocatedRewards > 0) {
            currentAcc += (unallocatedRewards * ACC_PRECISION) / totalStaked;
        }
        uint256 newlyAccrued = (userStake * currentAcc) / ACC_PRECISION - rewardDebt[user];
        return claimableRewards[user] + newlyAccrued;
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _harvest(msg.sender);

        _transfer(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        if (unallocatedRewards > 0) {
            uint256 toDistribute = unallocatedRewards;
            unallocatedRewards = 0;
            accRewardPerShare += (toDistribute * ACC_PRECISION) / totalStaked;
        }

        rewardDebt[msg.sender] = (stakedBalance[msg.sender] * accRewardPerShare) / ACC_PRECISION;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientStake();
        _harvest(msg.sender);

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        rewardDebt[msg.sender] = (stakedBalance[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        _transfer(address(this), msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external nonReentrant returns (uint256 reward) {
        _harvest(msg.sender);
        reward = claimableRewards[msg.sender];
        if (reward == 0) revert ZeroAmount();

        claimableRewards[msg.sender] = 0;
        rewardDebt[msg.sender] = (stakedBalance[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        _transfer(address(this), msg.sender, reward);
        emit RewardsClaimed(msg.sender, reward);
    }
}
