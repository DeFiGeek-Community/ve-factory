// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract MultiTokenFeeDistributorFirstClaimTest is Test {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant amount = 1e18 * 1000; // 1000 tokens
    uint256 constant THREE_MONTHS = 12 weeks;

    address admin = address(0x1);
    address emergencyReturn = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);

    MultiTokenFeeDistributor distributor;
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
        distributor = new MultiTokenFeeDistributor();
        distributor.initialize(address(veToken), admin, emergencyReturn);

        // Lock user tokens in veToken
        stakeToken.transfer(user1, amount);
        vm.prank(user1);
        stakeToken.approve(address(veToken), amount);
        vm.prank(user1);
        veToken.createLock(amount, block.timestamp + 30 * WEEK);

        // Admin adds rewardToken with a start time of 3 months from now
        vm.prank(admin);
        distributor.addToken(address(rewardToken1), block.timestamp + THREE_MONTHS);
        vm.prank(admin);
        distributor.addToken(address(rewardToken2), block.timestamp + THREE_MONTHS);
    }

    function roundToWeek(uint256 timestamp) internal pure returns (uint256) {
        return (timestamp / WEEK) * WEEK;
    }

    function testCannotClaimRewardToken1BeforeThreeMonths() public {
        vm.prank(admin);
        distributor.toggleAllowCheckpointToken();

        // Send some reward tokens to the distributor contract
        rewardToken1.transfer(address(distributor), 1e18 * 100);

        // Warp to 2 months later (before the reward distribution start time)
        vm.warp(roundToWeek(block.timestamp + 8 weeks));

        // User tries to claim but should fail because 3 months haven't passed yet
        vm.prank(user1);
        uint256 claimedAmount = distributor.claim(address(rewardToken1));
        assertTrue(claimedAmount == 0);

        // Warp to 3 months later (after the reward distribution start time)
        vm.warp(roundToWeek(block.timestamp + 6 weeks));

        // User claims and should succeed
        vm.prank(user1);
        claimedAmount = distributor.claim(address(rewardToken1));
        assertTrue(claimedAmount > 0, "Claim should be successful after 3 months");
    }

    function testCanClaimRewardToken1AfterThreeMonths() public {
        vm.prank(admin);
        distributor.toggleAllowCheckpointToken();

        // Send some reward tokens to the distributor contract
        rewardToken1.transfer(address(distributor), 1e18 * 100);

        // Warp to 3 months later (after the reward distribution start time)
        vm.warp(roundToWeek(distributor.startTime()) + 2 weeks);

        // User claims and should succeed
        vm.prank(user1);
        uint256 claimedAmount = distributor.claim(address(rewardToken1));

        assertTrue(claimedAmount > 0, "Claim should be successful after 3 months");
    }

    function testClaimRewardToken1WithNewLock() public {
        // Send some reward tokens to the distributor contract
        rewardToken1.transfer(address(distributor), 1e18 * 100);

        vm.warp(distributor.startTime() + 1 weeks - 1);
        vm.prank(user1);
        distributor.claim(address(rewardToken1));
        stakeToken.transfer(user2, amount);
        vm.prank(user2);
        stakeToken.approve(address(veToken), amount);
        vm.prank(user2);
        veToken.createLock(amount, block.timestamp + 30 * WEEK);
        vm.warp(distributor.startTime() + 1 weeks);

        // User2 creates a new lock just before user1 claims

        // Warp to 3 months later (after the reward distribution start time)
        vm.warp(roundToWeek(distributor.startTime()) + 2 weeks);

        vm.prank(admin);
        distributor.toggleAllowCheckpointToken();
        // User1 claims
        vm.prank(user1);
        uint256 claimedAmountUser1 = distributor.claim(address(rewardToken1));

        // User2 claims
        vm.prank(user2);
        uint256 claimedAmountUser2 = distributor.claim(address(rewardToken1));

        // Check the distribution
        assertTrue(claimedAmountUser1 > 0, "User1 should have claimed some tokens");
        assertTrue(claimedAmountUser2 > 0, "User2 should have claimed some tokens");
    }

    function testClaimRewardToken1WithLateLock() public {
        vm.prank(admin);
        distributor.toggleAllowCheckpointToken();

        // Send some reward tokens to the distributor contract
        rewardToken1.transfer(address(distributor), 1e18 * 100);

        // Warp to 3 months later (after the reward distribution start time)
        vm.warp(roundToWeek(distributor.startTime()) + 1 weeks);

        // User2 creates a new lock after the start time
        stakeToken.transfer(user2, amount);
        vm.prank(user2);
        stakeToken.approve(address(veToken), amount);
        vm.prank(user2);
        veToken.createLock(amount, block.timestamp + 30 * WEEK);

        // User2 tries to claim but should fail because the lock was created after the start time
        vm.prank(user2);
        uint256 claimedAmountUser2 = distributor.claim(address(rewardToken1));
        assertTrue(claimedAmountUser2 == 0, "User2 should not have claimed any tokens");
    }

    function testCannotClaimMultipleTokensBeforeThreeMonths() public {
        vm.prank(admin);
        distributor.toggleAllowCheckpointToken();

        // Send some reward tokens to the distributor contract
        rewardToken1.transfer(address(distributor), 1e18 * 100);
        rewardToken2.transfer(address(distributor), 1e18 * 100);

        // Warp to 2 months later (before the reward distribution start time)
        // solhint-disable-next-line security/no-block-members
        vm.warp(roundToWeek(block.timestamp + 8 weeks));

        // User tries to claim but should fail because 3 months haven't passed yet
        vm.startPrank(user1);
        uint256 claimedAmount1 = distributor.claim(address(rewardToken1));
        uint256 claimedAmount2 = distributor.claim(address(rewardToken2));
        assertTrue(claimedAmount1 == 0);
        assertTrue(claimedAmount2 == 0);

        // Warp to 3 months later (after the reward distribution start time)
        // solhint-disable-next-line security/no-block-members
        vm.warp(roundToWeek(block.timestamp + 6 weeks));

        // User claims and should succeed
        vm.startPrank(user1);
        claimedAmount1 = distributor.claim(address(rewardToken1));
        claimedAmount2 = distributor.claim(address(rewardToken2));
        assertTrue(claimedAmount1 > 0, "Claim should be successful after 3 months");
        assertTrue(claimedAmount2 > 0, "Claim should be successful after 3 months");
    }

    function testCanClaimMultipleTokensAfterThreeMonths() public {
        vm.prank(admin);
        distributor.toggleAllowCheckpointToken();

        // Send some reward tokens to the distributor contract
        rewardToken1.transfer(address(distributor), 1e18 * 100);
        rewardToken2.transfer(address(distributor), 1e18 * 100);

        // Warp to 3 months later (after the reward distribution start time)
        // solhint-disable-next-line security/no-block-members
        vm.warp(distributor.startTime() + 2 weeks);

        // User claims and should succeed
        vm.startPrank(user1);
        uint256 claimedAmount1 = distributor.claim(address(rewardToken1));
        uint256 claimedAmount2 = distributor.claim(address(rewardToken2));

        assertTrue(claimedAmount1 > 0, "Claim should be successful after 3 months");
        assertTrue(claimedAmount2 > 0, "Claim should be successful after 3 months");
    }
}