// SPDX-License-Identifier: MIT
pragma solidity =0.8.24 ^0.8.20;

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// src/ThinStakingLocker.sol

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
