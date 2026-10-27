// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ThinLPLocker
 * @notice Trustless, non-custodial time-lock for Uniswap V2 LP tokens with zero protocol fees.
 * Strictly extend-only; lock duration can never be decreased once set.
 */
contract ThinLPLocker is ReentrancyGuard {
    struct Lock {
        address lpToken;
        address beneficiary;
        uint256 amount;
        uint256 unlockTimestamp;
        bool withdrawn;
    }

    uint256 public lockCount;
    mapping(uint256 => Lock) public locks;
    mapping(address => uint256[]) public userLockIds;

    event Locked(uint256 indexed lockId, address indexed lpToken, address indexed beneficiary, uint256 amount, uint256 unlockTimestamp);
    event LockExtended(uint256 indexed lockId, uint256 oldUnlockTimestamp, uint256 newUnlockTimestamp);
    event Withdrawn(uint256 indexed lockId, address indexed beneficiary, uint256 amount);

    error LockNotExpired(uint256 unlockTimestamp, uint256 currentTimestamp);
    error AlreadyWithdrawn();
    error NotBeneficiary();
    error ZeroAmount();
    error InvalidDuration();
    error UnlockMustIncrease();

    function lock(address lpToken, uint256 amount, uint256 durationSeconds) external nonReentrant returns (uint256 lockId) {
        if (amount == 0) revert ZeroAmount();
        if (durationSeconds == 0) revert InvalidDuration();

        uint256 unlockTimestamp = block.timestamp + durationSeconds;
        lockId = ++lockCount;

        locks[lockId] = Lock({
            lpToken: lpToken,
            beneficiary: msg.sender,
            amount: amount,
            unlockTimestamp: unlockTimestamp,
            withdrawn: false
        });

        userLockIds[msg.sender].push(lockId);

        require(IERC20(lpToken).transferFrom(msg.sender, address(this), amount), "LP transfer failed");

        emit Locked(lockId, lpToken, msg.sender, amount, unlockTimestamp);
    }

    function extendLock(uint256 lockId, uint256 newUnlockTimestamp) external {
        Lock storage userLock = locks[lockId];
        if (msg.sender != userLock.beneficiary) revert NotBeneficiary();
        if (userLock.withdrawn) revert AlreadyWithdrawn();
        if (newUnlockTimestamp <= userLock.unlockTimestamp) revert UnlockMustIncrease();

        uint256 oldUnlock = userLock.unlockTimestamp;
        userLock.unlockTimestamp = newUnlockTimestamp;

        emit LockExtended(lockId, oldUnlock, newUnlockTimestamp);
    }

    function withdraw(uint256 lockId) external nonReentrant {
        Lock storage userLock = locks[lockId];
        if (msg.sender != userLock.beneficiary) revert NotBeneficiary();
        if (userLock.withdrawn) revert AlreadyWithdrawn();
        if (block.timestamp < userLock.unlockTimestamp) {
            revert LockNotExpired(userLock.unlockTimestamp, block.timestamp);
        }

        userLock.withdrawn = true;
        require(IERC20(userLock.lpToken).transfer(userLock.beneficiary, userLock.amount), "LP withdraw failed");

        emit Withdrawn(lockId, userLock.beneficiary, userLock.amount);
    }

    function isUnlockable(uint256 lockId) external view returns (bool) {
        Lock storage userLock = locks[lockId];
        return (!userLock.withdrawn && block.timestamp >= userLock.unlockTimestamp);
    }

    function timeRemaining(uint256 lockId) external view returns (uint256) {
        Lock storage userLock = locks[lockId];
        if (userLock.withdrawn || block.timestamp >= userLock.unlockTimestamp) return 0;
        return userLock.unlockTimestamp - block.timestamp;
    }
}
