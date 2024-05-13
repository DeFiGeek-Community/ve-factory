// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/veToken.sol";
import "../src/test/SampleToken.sol";

contract VeTokenError is Test {
    veToken public veTokenContract;
    SampleToken public token;

    function setUp() public {
        token = new SampleToken(1e20); // トークンの初期供給量を設定
        veTokenContract = new veToken(address(token), "veToken", "veTKN");
        token.transfer(address(this), 1e20);
        token.approve(address(veTokenContract), 1e20);
    }

    function testCreateLockWithZeroAmount() public {
        uint256 lockAmount = 0;
        uint256 unlockTime = block.timestamp + 4 weeks;
        vm.expectRevert("Need non-zero value");
        veTokenContract.createLock(lockAmount, unlockTime);
    }

    function testCreateLockWhenAlreadyLocked() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 4 weeks;
        veTokenContract.createLock(lockAmount, unlockTime);
        vm.expectRevert("Withdraw old tokens first");
        veTokenContract.createLock(lockAmount, unlockTime);
    }

    function testCreateLockWithPastUnlockTime() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp - 1; // 過去の時間
        vm.expectRevert("Can only lock until time in the future");
        veTokenContract.createLock(lockAmount, unlockTime);
    }

    function testCreateLockWithExceedingMaxTime() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 4 * 365 days + 1 weeks; // 最大期間を超える
        vm.expectRevert("Voting lock can be 4 years max");
        veTokenContract.createLock(lockAmount, unlockTime);
    }

    // `increaseAmount`関数のエラーテスト
    function testIncreaseAmountWithZero() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 4 weeks;
        veTokenContract.createLock(lockAmount, unlockTime);
        vm.expectRevert("Need non-zero value");
        veTokenContract.increaseAmount(0);
    }

    function testIncreaseAmountWithoutLock() public {
        vm.expectRevert("No existing lock found");
        veTokenContract.increaseAmount(1e18);
    }

    // `increaseAmount`関数のエラーテスト: "Cannot add to expired lock. Withdraw"
    function testIncreaseAmountWithExpiredLock() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 1 weeks;
        veTokenContract.createLock(lockAmount, unlockTime);

        vm.warp(block.timestamp + 2 weeks);

        uint256 increaseAmount = 1e18;
        vm.expectRevert("Cannot add to expired lock. Withdraw");
        veTokenContract.increaseAmount(increaseAmount);
    }

    // `increaseUnlockTime`関数のエラーテスト: "Lock expired"
    function testIncreaseUnlockTimeWithExpiredLock() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 1 weeks;
        veTokenContract.createLock(lockAmount, unlockTime);

        vm.warp(block.timestamp + 2 weeks);

        uint256 newUnlockTime = block.timestamp + 4 weeks;
        vm.expectRevert("Lock expired");
        veTokenContract.increaseUnlockTime(newUnlockTime);
    }

    // `increaseUnlockTime`関数のエラーテスト
    function testIncreaseUnlockTimeToPast() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 4 weeks;
        veTokenContract.createLock(lockAmount, unlockTime);
        vm.expectRevert("Can only increase lock duration");
        veTokenContract.increaseUnlockTime(block.timestamp);
    }

    // `increaseUnlockTime`関数のエラーテスト: "Voting lock can be 4 years max"
    function testIncreaseUnlockTimeBeyondMax() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 4 * 365 days - 1 weeks;
        veTokenContract.createLock(lockAmount, unlockTime);

        uint256 newUnlockTime = block.timestamp + 4 * 365 days + 2 weeks;
        vm.expectRevert("Voting lock can be 4 years max");
        veTokenContract.increaseUnlockTime(newUnlockTime);
    }

    // `withdraw`関数のエラーテスト
    function testWithdrawBeforeLockExpires() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 4 weeks;
        veTokenContract.createLock(lockAmount, unlockTime);
        vm.expectRevert("The lock didn't expire");
        veTokenContract.withdraw();
    }

    // `depositFor`関数のエラーテスト
    function testDepositForWithExpiredLock() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 4 weeks;
        veTokenContract.createLock(lockAmount, unlockTime);

        // 時間を進めてロックを期限切れにする
        vm.warp(block.timestamp + 4 weeks + 1);

        uint256 depositAmount = 1e18;
        vm.expectRevert("Cannot add to expired lock. Withdraw");
        veTokenContract.depositFor(address(this), depositAmount);
    }

    function testDepositForWithZeroAmount() public {
        uint256 lockAmount = 1e18;
        uint256 unlockTime = block.timestamp + 4 weeks;
        veTokenContract.createLock(lockAmount, unlockTime);

        uint256 depositAmount = 0;
        vm.expectRevert("Need non-zero value");
        veTokenContract.depositFor(address(this), depositAmount);
    }

    // `depositFor`関数の追加エラーテスト
    function testDepositForWithoutExistingLock() public {
        uint256 depositAmount = 1e18;
        vm.expectRevert("No existing lock found");
        veTokenContract.depositFor(address(this), depositAmount);
    }
}
