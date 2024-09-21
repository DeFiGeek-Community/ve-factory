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
    SampleToken stakeToken;

    function setUp() public {
        // Initialize tokens
        rewardToken1 = new SampleToken(1e26);
        rewardToken2 = new SampleToken(1e26);
        stakeToken = new SampleToken(1e26);

        // Initialize the veToken
        veToken = new VeToken(address(stakeToken), "veToken", "veTKN");

        // Initialize the distributor with the veToken
        vm.prank(admin);
        distributor = new FeeDistributorYamawake(address(veToken), address(this), block.timestamp + THREE_MONTHS);

        // Lock user tokens in veToken
        stakeToken.transfer(user1, amount);
        vm.prank(user1);
        stakeToken.approve(address(veToken), amount);
        vm.prank(user1);
        veToken.createLock(amount, block.timestamp + 30 * WEEK);

        // Admin adds rewardToken with a start time of 3 months from now
        vm.prank(admin);
        distributor.addRewardToken(address(rewardToken1));
    }

    function roundToWeek(uint256 timestamp) internal pure returns (uint256) {
        return (timestamp / WEEK) * WEEK;
    }

    function testClaimRewardToken1WithLateLock() public {
        // Send some reward tokens to the distributor contract
        rewardToken1.transfer(address(distributor), 1e18 * 100);

        // Warp to 3 months later (after the reward distribution start time)
        vm.warp(distributor.startTime() + 1 weeks);

        distributor.checkpointTotalSupply();
        vm.prank(admin);
        distributor.checkpointToken(address(rewardToken1));
        vm.prank(user1);
        distributor.claim(address(rewardToken1));

        // User2 creates a new lock after the start time
        stakeToken.transfer(user2, amount);
        vm.prank(user2);
        stakeToken.approve(address(veToken), amount);
        vm.prank(user2);
        veToken.createLock(amount, block.timestamp + 30 * WEEK);



        vm.warp(roundToWeek(distributor.startTime()) + 2 weeks);
        // User2 tries to claim but should fail because the lock was created after the start time
        vm.prank(admin);
        distributor.checkpointToken(address(rewardToken1));
        vm.prank(user1);
        distributor.claim(address(rewardToken1));
        vm.prank(user2);
        distributor.claim(address(rewardToken1));
    }


    function testClaimAfterLongPeriod() public {

        // user2がトークンをロック
        stakeToken.transfer(user2, 1e18);
        vm.prank(user2);
        stakeToken.approve(address(veToken), 1e18);
        vm.prank(user2);
        veToken.createLock(1e18, block.timestamp + 100 * WEEK);

        // トークンをFeeDistributorに転送
        rewardToken1.transfer(address(distributor), 1e18);

        // 30週間時間を進める
        vm.warp(distributor.startTime() + 30 * WEEK);

        // user2が請求
        vm.prank(admin);
        distributor.checkpointToken(address(rewardToken1));
        vm.prank(user2);
        distributor.claim(address(rewardToken1));

        // uint256 startTime = distributor.startTime();
        // for (uint256 i = 0; i <= 30; i++) {
        //     uint256 week = startTime + (i * WEEK);
        //     uint256 veSupply = distributor.veSupply(week);
        //     uint256 tokensPerWeek = distributor.tokensPerWeek(address(rewardToken1), week);
        //     console.log(week);
        //     console.log(veSupply);
        //     console.log(tokensPerWeek);
        // }
    }

}