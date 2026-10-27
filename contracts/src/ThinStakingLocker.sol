// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IThinPoWToken is IERC20 {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function claimRewards() external returns (uint256 reward);
    function pendingRewards(address user) external view returns (uint256);
    function stakedBalance(address user) external view returns (uint256);
}

/**
 * @title ThinStakingLocker
 * @notice Verifiable, extend-only TimeLock smart contract for Dev / Community Loyalty Pool Staking.
 * Guarantees on-chain that staked THIN tokens cannot be unstaked or dumped until unlockTimestamp.
 */
contract ThinStakingLocker is ReentrancyGuard {
    IThinPoWToken public immutable token;
    address public immutable beneficiary;

    uint256 public unlockTimestamp;
    uint256 public lockedPrincipal;
    uint256 public totalYieldHarvested;

    error LockActive(uint256 unlockTimestamp, uint256 currentTimestamp);
    error Unauthorized();
    error ZeroAmount();
    error InvalidDuration();
    error DurationMustIncrease();

    event StakeLocked(address indexed beneficiary, uint256 amount, uint256 unlockTimestamp);
    event LockExtended(uint256 oldUnlockTimestamp, uint256 newUnlockTimestamp);
    event YieldClaimed(address indexed beneficiary, uint256 amount);
    event StakeWithdrawn(address indexed beneficiary, uint256 amount);

    modifier onlyBeneficiary() {
        if (msg.sender != beneficiary) revert Unauthorized();
        _;
    }

    constructor(address _token, address _beneficiary) {
        require(_token != address(0), "Invalid token");
        require(_beneficiary != address(0), "Invalid beneficiary");
        token = IThinPoWToken(_token);
        beneficiary = _beneficiary;
    }

    /**
     * @notice Locks THIN tokens into the Loyalty Pool until block.timestamp + duration.
     * @param amount The quantity of THIN to stake and lock.
     * @param durationSeconds Seconds to lock.
     */
    function lockAndStake(uint256 amount, uint256 durationSeconds) external onlyBeneficiary nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (durationSeconds == 0) revert InvalidDuration();

        uint256 proposedUnlock = block.timestamp + durationSeconds;
        if (proposedUnlock <= unlockTimestamp) revert DurationMustIncrease();

        unlockTimestamp = proposedUnlock;
        lockedPrincipal += amount;

        // Pull tokens from beneficiary to this contract
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Stake into ThinPoWToken loyalty pool
        token.approve(address(token), amount);
        token.stake(amount);

        emit StakeLocked(beneficiary, amount, unlockTimestamp);
    }

    /**
     * @notice Extends the existing lock duration. Strictly extend-only.
     * @param additionalSeconds Additional seconds to add to unlockTimestamp.
     */
    function extendLock(uint256 additionalSeconds) external onlyBeneficiary {
        if (additionalSeconds == 0) revert InvalidDuration();
        uint256 oldUnlock = unlockTimestamp;
        unlockTimestamp += additionalSeconds;
        emit LockExtended(oldUnlock, unlockTimestamp);
    }

    /**
     * @notice Allows beneficiary to claim accrued loyalty staking yields without unlocking principal.
     */
    function claimYield() external onlyBeneficiary nonReentrant returns (uint256 yieldAmount) {
        yieldAmount = token.claimRewards();
        if (yieldAmount > 0) {
            totalYieldHarvested += yieldAmount;
            require(token.transfer(beneficiary, yieldAmount), "Yield transfer failed");
            emit YieldClaimed(beneficiary, yieldAmount);
        }
    }

    /**
     * @notice Unstakes principal and returns tokens to beneficiary once lock timer expires.
     */
    function unstakeAndWithdraw() external onlyBeneficiary nonReentrant {
        if (block.timestamp < unlockTimestamp) {
            revert LockActive(unlockTimestamp, block.timestamp);
        }

        uint256 amount = lockedPrincipal;
        if (amount == 0) revert ZeroAmount();

        lockedPrincipal = 0;

        // Unstake from ThinPoWToken
        token.unstake(amount);

        // Also claim any final remaining rewards
        try token.claimRewards() returns (uint256 yieldAmount) {
            if (yieldAmount > 0) {
                totalYieldHarvested += yieldAmount;
                token.transfer(beneficiary, yieldAmount);
            }
        } catch {}

        require(token.transfer(beneficiary, amount), "Withdraw transfer failed");
        emit StakeWithdrawn(beneficiary, amount);
    }

    // -------------------------------------------------------------------------
    // Public Audit & View Helpers
    // -------------------------------------------------------------------------

    function isUnlockable() external view returns (bool) {
        return block.timestamp >= unlockTimestamp && lockedPrincipal > 0;
    }

    function timeRemaining() external view returns (uint256) {
        if (block.timestamp >= unlockTimestamp) return 0;
        return unlockTimestamp - block.timestamp;
    }

    function currentStakedPrincipal() external view returns (uint256) {
        return lockedPrincipal;
    }

    function pendingLoyaltyRewards() external view returns (uint256) {
        return token.pendingRewards(address(this));
    }
}
