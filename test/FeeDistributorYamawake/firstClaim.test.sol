// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/FeeDistributorYamawake.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorYamawakeFirstClaimTest is Test {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant amount = 1e18 * 1000; // 1000 tokens
    uint256 constant THREE_MONTHS = 12 weeks;

    address admin = address(0x1);
    address emergencyReturn = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);

    FeeDistributorYamawake distributor;
    VeToken veToken;
    SampleToken rewardToken1;
    SampleToken rewardToken2;
    SampleToken rewardToken3;
    SampleToken stakeToken;

    function setUp() public {
        // トークンの初期化
        rewardToken1 = new SampleToken(1e26);
        rewardToken2 = new SampleToken(1e26);
        rewardToken3 = new SampleToken(1e26);
        stakeToken = new SampleToken(1e26);

        // veTokenの初期化
        veToken = new VeToken(address(stakeToken), "veToken", "veTKN");

        // veTokenを使用してディストリビュータを初期化
        vm.prank(admin);
        distributor = new FeeDistributorYamawake(address(veToken), address(this), block.timestamp + THREE_MONTHS);

        // ユーザーのトークンをveTokenにロック
        stakeToken.transfer(user1, amount);
        vm.prank(user1);
        stakeToken.approve(address(veToken), amount);
        vm.prank(user1);
        veToken.createLock(amount, block.timestamp + 30 * WEEK);

        // 管理者が3ヶ月後に開始する報酬トークンを追加
        vm.prank(admin);
        distributor.addRewardToken(address(rewardToken1));
    }

    function roundToWeek(uint256 timestamp) internal pure returns (uint256) {
        return (timestamp / WEEK) * WEEK;
    }

    // テスト名: testClaimRewardToken1WithLateLock
    // コメント: ユーザー2が遅れてロックした場合の報酬請求テスト
    function testClaimRewardToken1WithLateLock() public {
        // ディストリビュータコントラクトに報酬トークンを送信
        rewardToken1.transfer(address(distributor), 1e18 * 100);
        vm.prank(admin);
        distributor.checkpointToken(address(rewardToken1));

        // 3ヶ月後に時間を進める（報酬分配開始後）
        vm.warp(distributor.startTime() + 3 weeks);
        vm.prank(user1);
        distributor.claim(address(rewardToken1));

        // ユーザー2が開始時間後に新しいロックを作成
        stakeToken.transfer(user2, amount);
        vm.prank(user2);
        stakeToken.approve(address(veToken), amount);
        vm.warp(distributor.timeCursor() - 1 weeks);
        vm.prank(user2);
        veToken.createLock(amount, block.timestamp + 30 * WEEK);

        vm.warp(distributor.startTime() + 5 weeks);
        rewardToken1.transfer(address(distributor), 1e18 * 100);
        vm.prank(admin);
        distributor.checkpointToken(address(rewardToken1));

        vm.warp(roundToWeek(distributor.startTime()) + 7 weeks);
        // ユーザー2が請求を試みる

        vm.prank(user1);
        distributor.claim(address(rewardToken1));
        vm.prank(user2);
        distributor.claim(address(rewardToken1));
        rewardToken1.balanceOf(address(distributor));
    }

    // テスト名: testClaimAfterLongPeriod
    // コメント: 長期間後の報酬請求テスト
    function testClaimAfterLongPeriod() public {
        // ユーザー2がトークンをロック
        stakeToken.transfer(user2, 1e18);
        vm.prank(user2);
        stakeToken.approve(address(veToken), 1e18);
        vm.prank(user2);
        veToken.createLock(1e18, block.timestamp + 100 * WEEK);

        // トークンをFeeDistributorに転送
        rewardToken1.transfer(address(distributor), 1e18);

        // 30週間時間を進める
        vm.warp(distributor.startTime() + 30 * WEEK);

        // ユーザー2が請求
        vm.prank(user2);
        distributor.claim(address(rewardToken1));
    }

    function testClaim3() public {
        vm.warp(distributor.startTime() + 156 weeks); // 3 years

        vm.prank(admin);
        distributor.addRewardToken(address(rewardToken3));

        // ユーザー2がトークンをロック
        stakeToken.transfer(user2, 1e18);
        vm.prank(user2);
        stakeToken.approve(address(veToken), 1e18);
        vm.prank(user2);
        veToken.createLock(1e18, block.timestamp + 100 * WEEK);

        // トークンをFeeDistributorに転送
        rewardToken3.transfer(address(distributor), 1e18);

        // ユーザー2が請求
        vm.prank(user2);
        distributor.claim(address(rewardToken3));
        vm.prank(user2);
        distributor.claim(address(rewardToken3));
        vm.prank(user2);
        distributor.claim(address(rewardToken3));
        vm.prank(user2);
        distributor.claim(address(rewardToken3));
        vm.prank(user2);
        distributor.claim(address(rewardToken3));
        vm.prank(user2);
        distributor.claim(address(rewardToken3));
    }
}
