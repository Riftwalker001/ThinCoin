// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/ThinPoWToken.sol";
import "../src/ThinStakingLocker.sol";
import "../src/ThinLPLocker.sol";

contract ThinPoWTokenTest is Test {
    ThinPoWToken token;
    ThinStakingLocker stakingLocker;
    ThinLPLocker lpLocker;

    address dev = address(0x1B34DC6d765a8de0a6B63100B7De449757275D67);
    address miner1 = address(0x435763844FE1fed9eA3514C611817a2a792731ba);
    address miner2 = address(0x900537d4ce2C5cdB59EBa423041c4A40C2d821c4);

    function setUp() public {
        token = new ThinPoWToken(dev, 100_000 ether); // 100,000 THIN Genesis
        stakingLocker = new ThinStakingLocker(address(token), dev);
        lpLocker = new ThinLPLocker();
    }

    function test_GenesisParameters() public view {
        assertEq(token.balanceOf(dev), 100_000 ether);
        assertEq(token.totalSupply(), 100_000 ether);
        assertEq(token.DEV_MINING_BPS(), 90); // 0.90% dev fee
        assertEq(token.MINER_REWARD_BPS(), 9410); // 94.10% miner reward
        assertEq(token.STAKER_MINING_BPS(), 350); // 3.50% stakers
        assertEq(token.JACKPOT_MINING_BPS(), 150); // 1.50% jackpot
    }

    function test_DevStakingLocker_Workflow() public {
        vm.startPrank(dev);
        token.approve(address(stakingLocker), 20_000 ether);

        // Lock 20,000 THIN for 30 days
        uint256 duration = 30 days;
        stakingLocker.lockAndStake(20_000 ether, duration);

        assertEq(stakingLocker.lockedPrincipal(), 20_000 ether);
        assertEq(token.stakedBalance(address(stakingLocker)), 20_000 ether);
        assertFalse(stakingLocker.isUnlockable());
        assertGt(stakingLocker.timeRemaining(), 0);

        // Cannot unstake early
        vm.expectRevert();
        stakingLocker.unstakeAndWithdraw();

        // Warp 31 days into future
        vm.warp(block.timestamp + 31 days);
        assertTrue(stakingLocker.isUnlockable());
        assertEq(stakingLocker.timeRemaining(), 0);

        // Unstake successfully
        stakingLocker.unstakeAndWithdraw();
        assertEq(token.balanceOf(dev), 100_000 ether);
        assertEq(stakingLocker.lockedPrincipal(), 0);
        vm.stopPrank();
    }

    function test_MiningAndCooldown() public {
        bytes32 challenge = token.challengeNumber();
        uint256 target = token.effectiveTarget();

        // Find a valid nonce for miner1
        uint256 validNonce;
        bool found = false;
        for (uint256 n = 0; n < 2000; n++) {
            bytes32 digest = token.computeDigest(challenge, miner1, n);
            if (uint256(digest) <= target) {
                validNonce = n;
                found = true;
                break;
            }
        }
        assertTrue(found, "Should find nonce within initial easy target");

        // Mine block
        vm.prank(miner1);
        token.mine(validNonce);
        assertEq(token.epochCount(), 1);
        assertGt(token.balanceOf(miner1), 0);

        // Attempting to mine consecutively in same epoch window should revert for miner1
        vm.prank(miner1);
        vm.expectRevert();
        token.mine(validNonce + 1);
    }
}
