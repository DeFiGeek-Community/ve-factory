// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/FeeDistributorBase.sol";
import "src/Interfaces/IFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorWithToggleCheckpointTest is TestBase {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;

    address alice;
    address bob;
    address charlie;

    IFeeDistributor public feeDistributor = IFeeDistributor(target);

    FeeDistributorBase distributor;
    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);

        token = new SampleToken(1e40);
        token.transfer(alice, 1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        token.approve(address(veToken), 1e24);
        vm.prank(alice);
        token.approve(address(veToken), type(uint256).max);
        vm.prank(bob);
        token.approve(address(veToken), type(uint256).max);
        vm.prank(charlie);
        token.approve(address(veToken), type(uint256).max);
        distributor = new FeeDistributorBase();

        _use(FeeDistributorBase.initialize.selector, address(distributor));
        _use(FeeDistributorBase.checkpointToken.selector, address(distributor));
        _use(FeeDistributorBase.checkpointTotalSupply.selector, address(distributor));
        _use(FeeDistributorBase.claim.selector, address(distributor));
        _use(FeeDistributorBase.claimFor.selector, address(distributor));
        _use(FeeDistributorBase.claimMany.selector, address(distributor));
        _use(FeeDistributorBase.tokensPerWeek.selector, address(distributor));
        _use(FeeDistributorBase.toggleAllowCheckpointToken.selector, address(distributor));
        _use(FeeDistributorBase.startTime.selector, address(distributor));
        _use(FeeDistributorBase.lastTokenTime.selector, address(distributor));
        _use(FeeDistributorBase.timeCursor.selector, address(distributor));
        _use(FeeDistributorBase.canCheckpointToken.selector, address(distributor));

        vm.warp(WEEK * 1000);
    }

    // abs関数のカスタム実装
    function abs(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    // 安全なキャストを行うヘルパー関数
    function safeToInt256(uint256 x) internal pure returns (int256) {
        require(x <= uint256(type(int256).max), "Value exceeds int256 max");
        return int256(x);
    }

    function feeDistributorInitialize(uint256 time) internal {
        feeDistributor.initialize(address(veToken), time, address(coinA), address(this), bob);
    }

    function testClaimAfterTokenDeposit() public {
        vm.warp(WEEK * 1000);
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        feeDistributorInitialize(block.timestamp);
        feeDistributor.toggleAllowCheckpointToken();
        assertTrue(feeDistributor.canCheckpointToken());
        vm.warp(feeDistributor.lastTokenTime());

        uint256 amount = 1000 * 1e18;

        // トークンの転送
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e18);

        vm.startPrank(alice);
        veToken.createLock(amount, block.timestamp + 3 * WEEK);
        vm.warp(block.timestamp + 2 * WEEK);

        feeDistributor.claimFor(alice);
        uint256 balanceBefore = coinA.balanceOf(alice);

        feeDistributor.claimFor(alice);
        uint256 balanceAfter = coinA.balanceOf(alice);

        assertEq(balanceAfter - balanceBefore, 0);
    }

    function testClaimDuringTokenDepositPeriod() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.warp(block.timestamp + WEEK);

        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 30 * WEEK);
        vm.warp(block.timestamp + WEEK);

        feeDistributorInitialize(block.timestamp);
        feeDistributor.toggleAllowCheckpointToken();
        vm.warp(feeDistributor.lastTokenTime());
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 0; j < 7; j++) {
                vm.prank(bob);
                coinA.transfer(address(feeDistributor), 1e18);
                vm.warp(block.timestamp + DAY);
            }
        }

        vm.warp(block.timestamp + WEEK * 10);
        vm.prank(alice);
        feeDistributor.claimFor(alice);
        coinA.balanceOf(address(this));

        assertTrue(abs(safeToInt256(coinA.balanceOf(alice)) - safeToInt256(21 * 1e18)) < 1000);
    }

    function testClaimBeforeTokenDeposit() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 8 * WEEK);
        vm.warp(block.timestamp + WEEK);
        uint256 startTime = block.timestamp;
        vm.warp(block.timestamp + WEEK * 5);
        feeDistributorInitialize(startTime);
        feeDistributor.toggleAllowCheckpointToken();

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e19);
        vm.warp(block.timestamp + WEEK);
        feeDistributor.claimFor(alice);

        assertTrue(abs(safeToInt256(coinA.balanceOf(alice)) - 1e19) < 1000);
    }

    function testClaimForMultipleTokenDeposits() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 4 * WEEK);
        vm.warp(block.timestamp + WEEK);
        uint256 startTime = block.timestamp;
        vm.warp(block.timestamp + WEEK * 3);

        vm.prank(alice);
        veToken.withdraw();

        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 10 * WEEK);
        vm.warp(block.timestamp + WEEK * 2);

        feeDistributorInitialize(startTime);
        feeDistributor.toggleAllowCheckpointToken();

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 10 ** 19);
        vm.warp(block.timestamp + WEEK);
        feeDistributor.claimFor(alice);

        assertTrue(abs(10 ** 19 - safeToInt256(coinA.balanceOf(alice))) < 1000);
    }

    function testDepositedParallel() public {
        vm.prank(charlie);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;

        token.transfer(bob, amount);
        uint256 currentTimestamp = block.timestamp;
        vm.prank(alice);
        veToken.createLock(amount, currentTimestamp + 8 * WEEK);
        vm.prank(bob);
        veToken.createLock(amount, currentTimestamp + 8 * WEEK);
        vm.warp(block.timestamp + WEEK);
        uint256 startTime = block.timestamp;
        vm.warp(block.timestamp + WEEK * 5);

        feeDistributorInitialize(startTime);
        feeDistributor.toggleAllowCheckpointToken();

        vm.prank(charlie);
        coinA.transfer(address(feeDistributor), 1e19);
        feeDistributor.checkpointToken();
        vm.warp(block.timestamp + WEEK);
        feeDistributor.checkpointToken();
        feeDistributor.claimFor(alice);
        feeDistributor.claimFor(bob);

        int256 balanceAlice = safeToInt256(coinA.balanceOf(alice));
        int256 balanceBob = safeToInt256(coinA.balanceOf(bob));
        assertEq(balanceAlice, balanceBob);
        assertTrue(abs(balanceAlice + balanceBob - 10 ** 19) < 20);
    }
}
