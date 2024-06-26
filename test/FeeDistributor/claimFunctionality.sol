// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MCTest} from "@mc/devkit/Flattened.sol";
import "src/FeeDistributor.sol";
import "src/Interfaces/IFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorClaimFunctionalityTest is MCTest {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;

    address alice;
    address bob;
    address charlie;

    IFeeDistributor public feeDistributor = IFeeDistributor(target);

    FeeDistributor distributor;
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
        distributor = new FeeDistributor();

        _use(FeeDistributor.initialize.selector, address(distributor));
        _use(FeeDistributor.checkpointToken.selector, address(distributor));
        _use(
            FeeDistributor.checkpointTotalSupply.selector,
            address(distributor)
        );
        _use(bytes4(keccak256("claim()")), address(distributor));
        _use(bytes4(keccak256("claim(address)")), address(distributor));
        _use(FeeDistributor.claimMany.selector, address(distributor));
        _use(FeeDistributor.tokensPerWeek.selector, address(distributor));
        _use(
            FeeDistributor.toggleAllowCheckpointToken.selector,
            address(distributor)
        );
        _use(FeeDistributor.startTime.selector, address(distributor));
        _use(FeeDistributor.lastTokenTime.selector, address(distributor));
        _use(FeeDistributor.timeCursor.selector, address(distributor));
        _use(FeeDistributor.canCheckpointToken.selector, address(distributor));

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
        feeDistributor.initialize(
            address(veToken),
            time,
            address(coinA),
            address(this),
            bob
        );
    }

    function testClaimWithCheckpointAfterToggle() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;

        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 8 * WEEK);

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e18);

        uint256 startTime = block.timestamp + WEEK * 2;
        feeDistributorInitialize(startTime);

        feeDistributor.toggleAllowCheckpointToken();
        vm.warp(feeDistributor.lastTokenTime());

        vm.startPrank(alice);

        vm.warp(block.timestamp + 6 days);
        feeDistributor.claim(alice);
        assertEq(coinA.balanceOf(alice), 0);

        vm.warp(block.timestamp + 1 days);
        feeDistributor.claim(alice);
        int256 balanceAlice = safeToInt256(coinA.balanceOf(alice));

        assertTrue(abs(balanceAlice - 1e18) < 20);
    }

    function testAccumulatedClaimsAfterMultipleTokenDeposits() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        // Aliceにトークンをロックさせる
        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 4 * WEEK);
        vm.warp(block.timestamp + WEEK);

        // FeeDistributorを初期化し、チェックポイントトークンを許可する
        feeDistributorInitialize(block.timestamp);
        feeDistributor.toggleAllowCheckpointToken();

        // 1回目のトークン転送とチェックポイント
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e18);

        // Aliceが1回目の請求を行い、トークンの残高を確認する
        vm.warp(block.timestamp + WEEK);
        vm.prank(alice);
        feeDistributor.claim(alice);
        uint256 balanceAfterFirstClaim = coinA.balanceOf(alice);
        assertEq(balanceAfterFirstClaim, 1e18);

        // 2回目のトークン転送とチェックポイント
        vm.warp(block.timestamp + WEEK);
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 2e18);
        feeDistributor.checkpointToken();

        // Aliceが2回目の請求を行い、トークンの残高を確認する
        vm.prank(alice);
        feeDistributor.claim(alice);
        uint256 balanceAfterSecondClaim = coinA.balanceOf(alice);

        // 2回目の請求で2e18が加算されていることを確認
        assertEq(balanceAfterSecondClaim, 3e18);
    }

    function testClaimFailsWithoutVeTokenBalance() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        // Aliceにトークンをロックさせる
        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 4 * WEEK);
        vm.warp(block.timestamp + WEEK);

        // FeeDistributorを初期化し、チェックポイントトークンを許可する
        feeDistributorInitialize(block.timestamp);
        feeDistributor.toggleAllowCheckpointToken();

        // トークンをFeeDistributorに転送
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e18);

        // Aliceが請求を行い、トークンの残高を確認する
        vm.warp(block.timestamp + WEEK);
        vm.prank(alice);
        feeDistributor.claim(alice);
        uint256 balanceAfterFirstClaim = coinA.balanceOf(alice);
        assertEq(balanceAfterFirstClaim, 1e18);

        vm.warp(block.timestamp + WEEK * 4);
        feeDistributor.checkpointToken();

        // さらにトークンを転送し、チェックポイントを作成
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 2e18);

        // veTokenの残高がない状態でAliceが請求を試みる
        vm.prank(alice);
        feeDistributor.claim(alice);
        uint256 balanceAfterSecondAttempt = coinA.balanceOf(alice);

        // veTokenの残高がないため、2回目の請求でトークンが加算されていないことを確認
        assertEq(balanceAfterSecondAttempt, balanceAfterFirstClaim);
    }

    function testClaimWithLargeNumberOfUsers() public {
        uint256 userCount = 10000; // テストするユーザーの数
        uint256 amount = 1e18; // 各ユーザーがロックするトークンの量

        // トークンをFeeDistributorに転送
        vm.prank(bob);
        coinA = new SampleToken(userCount * 1e18);

        // FeeDistributorを初期化し、チェックポイントトークンを許可する
        feeDistributorInitialize(block.timestamp);
        feeDistributor.toggleAllowCheckpointToken();

        vm.prank(bob);
        coinA.transfer(address(feeDistributor), userCount * 1e18);

        // 100人のユーザーがveTokenをロック
        for (uint256 i = 0; i < userCount; i++) {
            address user = address(uint160(i + 1)); // ユーザーアドレスを生成
            token.transfer(address(user), amount);
            vm.prank(user);
            token.approve(address(veToken), type(uint256).max);
            vm.prank(user);
            veToken.createLock(amount, block.timestamp + 10 * WEEK);
        }

        vm.warp(block.timestamp + WEEK * 3);

        // 各ユーザーがclaimを行う
        for (uint256 i = 0; i < userCount; i++) {
            address user = address(uint160(i + 1)); // ユーザーアドレスを生成
            uint256 balanceBefore = coinA.balanceOf(user); // claim前のトークン残高を記録

            vm.prank(user);
            feeDistributor.claim(user);

            uint256 balanceAfter = coinA.balanceOf(user); // claim後のトークン残高を記録
            uint256 claimedAmount = balanceAfter - balanceBefore; // claimによって得られたトークン量を計算

            // 各ユーザーが正しい量のトークンをclaimできたことを確認
            assertTrue(abs(safeToInt256(claimedAmount) - 1e18) < 20);
        }
    }

    receive() external payable {}
}
