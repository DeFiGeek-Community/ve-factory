// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/FeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributor222FirstClaimTest is Test {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant amount = 1e18 * 1000; // 1000 tokens
    uint256 constant THREE_MONTHS = 12 weeks;

    uint256 createTime;
    address admin = address(0x1);
    address emergencyReturn = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);

    FeeDistributor distributor;
    VeToken veToken;
    SampleToken rewardToken1;
    SampleToken stakeToken;

    uint256 startTimeToken;

    function setUp() public {
        // Initialize tokens
        rewardToken1 = new SampleToken(1e26);
        stakeToken = new SampleToken(1e26);

        // Initialize the veToken
        veToken = new VeToken(address(stakeToken), "veToken", "veTKN");

        // Initialize the distributor with the veToken
        vm.prank(admin);
        distributor = new FeeDistributor();
        distributor.initialize(
            address(veToken), block.timestamp + THREE_MONTHS, address(rewardToken1), admin, emergencyReturn
        );

        // Lock user tokens in veToken
        createTime = block.timestamp + 100 * WEEK;
        stakeToken.transfer(user1, amount);
        vm.prank(user1);
        stakeToken.approve(address(veToken), amount);
        vm.prank(user1);
        veToken.createLock(amount, createTime);

        startTimeToken = distributor.startTime();

        vm.prank(admin);
        distributor.toggleAllowCheckpointToken();
    }

    function testCannotClaimRewardToken1BeforeThreeMonths() public {
        // Send some reward tokens to the distributor contract
        rewardToken1.transfer(address(distributor), 1e18 * 100);

        // Warp to 2 months later (before the reward distribution start time)
        vm.warp(startTimeToken - 4 weeks);

        // User tries to claim but should fail because 3 months haven't passed yet
        vm.prank(user1);
        uint256 claimedAmount = distributor.claim();
        assertTrue(
            claimedAmount == 0, "User should not be able to claim tokens before the reward distribution start time"
        );

        // Warp to 3 months later (after the reward distribution start time)
        vm.warp(startTimeToken + 2 weeks);

        // User claims and should succeed
        vm.prank(user1);
        claimedAmount = distributor.claim();
        assertApproxEqAbs(
            claimedAmount, 1e18 * 100, 1e4, "Claim should be approximately 1e18 * 100 tokens after 3 months"
        );
    }

    function testCanClaimRewardToken1AfterThreeMonths() public {
        // Send some reward tokens to the distributor contract
        rewardToken1.transfer(address(distributor), 1e18 * 100);

        // Warp to 3 months later (after the reward distribution start time)
        vm.warp(startTimeToken + 2 weeks);

        // User claims and should succeed
        vm.prank(user1);
        uint256 claimedAmount = distributor.claim();

        assertApproxEqAbs(
            claimedAmount, 1e18 * 100, 1e4, "Claim should be approximately 1e18 * 100 tokens after 3 months"
        );
    }

    function testClaimRewardToken1WithNewLock() public {
        // Send some reward tokens to the distributor contract
        rewardToken1.transfer(address(distributor), 1e18 * 100);

        vm.warp(startTimeToken + 1 weeks);
        vm.prank(user1);
        distributor.claim();
        stakeToken.transfer(user2, amount);
        vm.prank(user2);
        stakeToken.approve(address(veToken), amount);
        vm.prank(user2);
        veToken.createLock(amount, createTime);

        distributor.timeCursor();
        distributor.lastCheckpointTotalSupplyTime();

        // Warp to 3 months later (after the reward distribution start time)
        vm.warp(startTimeToken + 2 weeks);

        rewardToken1.transfer(address(distributor), 1e18 * 100);

        // User1 claims
        vm.prank(user1);
        uint256 claimedAmountUser1 = distributor.claim();

        // User2 claims
        vm.prank(user2);
        uint256 claimedAmountUser2 = distributor.claim();

        // Check the distribution
        assertApproxEqAbs(
            claimedAmountUser1, 1e18 * 50, 1e4, "User1 should have claimed approximately 50% of the tokens"
        );
        assertApproxEqAbs(
            claimedAmountUser2, 1e18 * 50, 1e4, "User2 should have claimed approximately 50% of the tokens"
        );
    }

    function testClaimRewardToken1WithLateLock() public {
        // Send some reward tokens to the distributor contract
        rewardToken1.transfer(address(distributor), 1e18 * 100);

        // Warp to 3 months later (after the reward distribution start time)
        vm.warp(startTimeToken + 1 weeks);

        // User2 creates a new lock after the start time
        stakeToken.transfer(user2, amount);
        vm.prank(user2);
        stakeToken.approve(address(veToken), amount);
        vm.prank(user2);
        veToken.createLock(amount, block.timestamp + 30 * WEEK);

        // User2 tries to claim but should fail because the lock was created after the start time
        vm.prank(user2);
        uint256 claimedAmountUser2 = distributor.claim();
        assertTrue(claimedAmountUser2 == 0, "User2 should not have claimed any tokens");
    }

    // コメント: オーナーが0週目と22週目にリワードトークンを投入し、ユーザが30週目にclaimを実行するテスト
    function testOwnerDepositsAndUserClaims() public {
        vm.warp(startTimeToken);
        // 0週目にリワードトークンを投入し、tokenCheckpointを実行
        rewardToken1.transfer(address(distributor), 1e18);
        vm.prank(admin);
        distributor.checkpointToken();

        // 22週目にリワードトークンを投入し、tokenCheckpointを実行
        vm.warp(startTimeToken + 22 * WEEK);
        rewardToken1.transfer(address(distributor), 1e18);
        vm.prank(admin);
        distributor.checkpointToken();

        // 30週目にユーザがclaimを実行
        vm.warp(startTimeToken + 8 * WEEK);
        vm.prank(user1);
        uint256 claimedAmount = distributor.claim();
        assertApproxEqAbs(
            claimedAmount, 2e18, 1e4, "User should be able to claim approximately 2e18 tokens after 30 weeks"
        );
    }
}
