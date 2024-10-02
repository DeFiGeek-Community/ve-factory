// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract MultiTokenFeeDistributorFeeDistributionTest is TestBase {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;

    address alice;
    address bob;
    address charlie;

    IMultiTokenFeeDistributor public feeDistributor = IMultiTokenFeeDistributor(target);

    MultiTokenFeeDistributor distributor;
    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);

        vm.warp(WEEK * 100);

        token = new SampleToken(1e32);
        token.transfer(alice, 1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        token.approve(address(veToken), 1e24);
        vm.prank(alice);
        token.approve(address(veToken), type(uint256).max);
        vm.prank(bob);
        token.approve(address(veToken), type(uint256).max);
        vm.prank(charlie);
        token.approve(address(veToken), type(uint256).max);
        distributor = new MultiTokenFeeDistributor();

        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.addToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.checkpointToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.checkpointTotalSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claim.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claimFor.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claimMany.selector, address(distributor));
        _use(MultiTokenFeeDistributor.tokensPerWeek.selector, address(distributor));
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

    function feeDistributorInitialize(uint256 time, address[] memory tokens) internal {
        feeDistributor.initialize(address(veToken), address(this), bob);
        for (uint256 i = 0; i < tokens.length; i++) {
            feeDistributor.addToken(tokens[i], time);
        }
    }

    function testDepositedAfter() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);
        address[] memory tokens = new address[](1);
        tokens[0] = address(coinA);
        feeDistributorInitialize(block.timestamp, tokens);
        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        token.approve(address(veToken), amount * 10);
        // トークンの転送とチェックポイントの作成
        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = 0; j < 7; j++) {
                vm.prank(bob);
                coinA.transfer(address(feeDistributor), 1e18);
                feeDistributor.checkpointToken(address(coinA));
                feeDistributor.checkpointTotalSupply();
                vm.warp(block.timestamp + DAY);
            }
        }

        vm.warp(block.timestamp + WEEK);

        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 3 * WEEK);
        vm.warp(block.timestamp + 2 * WEEK);

        vm.prank(alice);
        feeDistributor.claimFor(alice, address(coinA));
        uint256 balanceBefore = coinA.balanceOf(alice);
        vm.prank(alice);
        feeDistributor.claimFor(alice, address(coinA));
        uint256 balanceAfter = coinA.balanceOf(alice);

        assertEq(balanceAfter - balanceBefore, 0);
    }

    function testDepositedDuring() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        token.approve(address(veToken), amount * 10);

        vm.warp(block.timestamp + WEEK);

        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 8 * WEEK);
        vm.warp(block.timestamp + WEEK);

        address[] memory tokens = new address[](1);
        tokens[0] = address(coinA);
        feeDistributorInitialize(block.timestamp, tokens);

        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 0; j < 7; j++) {
                vm.prank(bob);
                coinA.transfer(address(feeDistributor), 1e18);
                feeDistributor.checkpointToken(address(coinA));
                feeDistributor.checkpointTotalSupply();
                vm.warp(block.timestamp + DAY);
            }
        }

        vm.warp(block.timestamp + WEEK);
        feeDistributor.checkpointToken(address(coinA));
        vm.prank(alice);
        feeDistributor.claimFor(alice, address(coinA));

        assertTrue(abs(safeToInt256(coinA.balanceOf(alice)) - safeToInt256(21 * 1e18)) < 10);
    }

    function testDepositedBefore() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 8 * WEEK);
        vm.warp(block.timestamp + WEEK);
        uint256 startTime = block.timestamp;
        vm.warp(block.timestamp + WEEK * 5);
        address[] memory tokens = new address[](1);
        tokens[0] = address(coinA);
        feeDistributorInitialize(block.timestamp, tokens);

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e19);
        feeDistributor.checkpointToken(address(coinA));
        vm.warp(block.timestamp + WEEK);
        feeDistributor.checkpointToken(address(coinA));
        feeDistributor.claimFor(alice, address(coinA));

        assertTrue(abs(safeToInt256(coinA.balanceOf(alice)) - 1e19) < 10);
    }

    function testDepositedTwice() public {
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
        uint256 excludeTime = (block.timestamp / WEEK) * WEEK;

        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 4 * WEEK);
        vm.warp(block.timestamp + WEEK * 2);

        address[] memory tokens = new address[](1);
        tokens[0] = address(coinA);
        feeDistributorInitialize(block.timestamp, tokens);

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 10 ** 19);
        feeDistributor.checkpointToken(address(coinA));
        vm.warp(block.timestamp + WEEK);
        feeDistributor.checkpointToken(address(coinA));
        feeDistributor.claimFor(alice, address(coinA));

        uint256 tokensToExclude = feeDistributor.tokensPerWeek(address(coinA), excludeTime);
        assertTrue(abs(10 ** 19 - safeToInt256(coinA.balanceOf(alice)) - safeToInt256(tokensToExclude)) < 10);
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

        address[] memory tokens = new address[](1);
        tokens[0] = address(coinA);
        feeDistributorInitialize(block.timestamp, tokens);

        vm.prank(charlie);
        coinA.transfer(address(feeDistributor), 1e19);
        feeDistributor.checkpointToken(address(coinA));
        vm.warp(block.timestamp + WEEK);
        feeDistributor.checkpointToken(address(coinA));
        feeDistributor.claimFor(alice, address(coinA));
        feeDistributor.claimFor(bob, address(coinA));

        int256 balanceAlice = safeToInt256(coinA.balanceOf(alice));
        int256 balanceBob = safeToInt256(coinA.balanceOf(bob));
        assertEq(balanceAlice, balanceBob);
        assertTrue(abs(balanceAlice + balanceBob - 10 ** 19) < 20);
    }
}
