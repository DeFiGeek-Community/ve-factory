// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/veToken.sol";
import "../src/test/SampleToken.sol";

contract VeTokenTest is Test {
    veToken public veTokenContract;
    SampleToken public token;

    function calculateExpectedVotingPower(
        uint256 lockAmount,
        uint256 unlockTime
    ) internal view returns (uint256) {
        uint256 unlockTimeRounded = (unlockTime / 1 weeks) * 1 weeks; // 週単位で丸める
        uint256 lockDuration = unlockTimeRounded - block.timestamp;
        uint256 maxLockDuration = 4 * 365 days; // 仮定: 最大ロック期間は4年

        uint256 expectedVotingPower = (lockAmount * lockDuration) /
            maxLockDuration;

        return expectedVotingPower;
    }

    function assertApproxEqual(
        uint256 actual,
        uint256 expected,
        uint256 tolerance,
        string memory message
    ) internal pure {
        if (actual > expected) {
            require(actual - expected <= tolerance, message);
        } else {
            require(expected - actual <= tolerance, message);
        }
    }

    function setUp() public {
        token = new SampleToken(1e20); // トークンの初期供給量を設定
        veTokenContract = new veToken(address(token), "veToken", "veTKN");
        token.transfer(address(this), 1e20);
        token.approve(address(veTokenContract), 1e20);
    }

    function testCreateLock() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 4 weeks; // 4週間後に設定
        uint256 unlockTimeRounded = (unlockTime / 1 weeks) * 1 weeks; // 週単位で丸める
        veTokenContract.createLock(lockAmount, unlockTime);
        assertEq(
            veTokenContract.lockedEnd(address(this)),
            unlockTimeRounded,
            "Unlock time mismatch"
        );
    }

    function testVotingPower() public {
        uint256 lockAmount = 1e18; // 1トークンをロック
        uint256 unlockTime = block.timestamp + 4 weeks; // 4週間後に設定
        veTokenContract.createLock(lockAmount, unlockTime);

        uint256 expectedVotingPower = calculateExpectedVotingPower(
            lockAmount,
            unlockTime
        );
        uint256 actualVotingPower = veTokenContract.balanceOf(address(this));

        assertApproxEqual(
            actualVotingPower,
            expectedVotingPower,
            1e8,
            "Voting power should match the expected value within the tolerance range"
        );
    }

    function testIncreaseUnlockTime() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 4 weeks;
        veTokenContract.createLock(lockAmount, unlockTime);
        uint256 newUnlockTime = unlockTime + 4 weeks;
        uint256 unlockTimeRounded = (newUnlockTime / 1 weeks) * 1 weeks; // 週単位で丸める
        veTokenContract.increaseUnlockTime(newUnlockTime);
        assertEq(
            veTokenContract.lockedEnd(address(this)),
            unlockTimeRounded,
            "Unlock time did not increase"
        );
    }

    function testWithdraw() public {
        uint256 lockAmount = 1e20;
        uint256 unlockTime = block.timestamp + 4 weeks;
        veTokenContract.createLock(lockAmount, unlockTime);
        // ブロックタイムをシミュレートしてロック期間を終了させる
        vm.warp(unlockTime + 1);
        veTokenContract.withdraw();
        assertEq(
            token.balanceOf(address(this)),
            lockAmount,
            "Failed to withdraw tokens"
        );
    }

    function testIncreaseAmount() public {
        uint256 initialLockAmount = 1e18;
        uint256 additionalAmount = 5e17; // 追加するトークンの量
        uint256 unlockTime = block.timestamp + 4 weeks; // ロック期間を設定

        // トークンをロックする
        veTokenContract.createLock(initialLockAmount, unlockTime);

        // ロックされたトークンの量を増やす
        veTokenContract.increaseAmount(additionalAmount);

        uint256 expectedVotingPower = calculateExpectedVotingPower(
            initialLockAmount + additionalAmount,
            unlockTime
        );
        uint256 actualVotingPower = veTokenContract.balanceOf(address(this));

        assertApproxEqual(
            actualVotingPower,
            expectedVotingPower,
            1e8,
            "Locked amount did not increase as expected"
        );
    }

}
