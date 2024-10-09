// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "src/test/AlwaysFailToken.sol";
import {console} from "forge-std/console.sol";

contract MultiTokenFeeDistributor_ClaimFunctionalityTest is TestBase {
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
    AlwaysFailToken failToken;

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
        distributor = new MultiTokenFeeDistributor();

        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.addToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.checkpointToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.checkpointTotalSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claim.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claimFor.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claimMany.selector, address(distributor));
        _use(MultiTokenFeeDistributor.tokensPerWeek.selector, address(distributor));
        _use(MultiTokenFeeDistributor.toggleAllowCheckpointToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.startTime.selector, address(distributor));
        _use(MultiTokenFeeDistributor.lastTokenTime.selector, address(distributor));
        _use(MultiTokenFeeDistributor.killMe.selector, address(distributor));
        _use(MultiTokenFeeDistributor.isKilled.selector, address(distributor));
        _use(MultiTokenFeeDistributor.canCheckpointToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.timeCursorOf.selector, address(distributor));
        _use(MultiTokenFeeDistributor.userEpochOf.selector, address(distributor));
        _use(MultiTokenFeeDistributor.veSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.tokensPerWeek.selector, address(distributor));

        feeDistributor.initialize(address(veToken), address(this), bob);
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
        feeDistributor.addToken(address(coinA), time);
    }

    function testClaimUpdatesTimeCursorAndUserEpoch() public {
        // トークンを作成し、FeeDistributorを初期化
        coinA = new SampleToken(1e20);
        feeDistributor.addToken(address(coinA), block.timestamp);

        // Aliceがトークンをロック
        uint256 amount = 1000 * 1e18;
        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 8 * WEEK);

        // チェックポイントを許可
        feeDistributor.toggleAllowCheckpointToken();

        // 時間を進めて請求を行う
        vm.warp(block.timestamp + WEEK * 2);
        vm.prank(alice);
        feeDistributor.claim(address(coinA));

        // timeCursorOfとuserEpochOfが更新されていることを確認
        uint256 timeCursor = feeDistributor.timeCursorOf(address(coinA), alice);
        uint256 userEpoch = feeDistributor.userEpochOf(address(coinA), alice);

        // 期待されるtimeCursorとuserEpochの値を計算
        uint256 expectedTimeCursor = (block.timestamp / WEEK) * WEEK;
        uint256 expectedUserEpoch = 1; // 初回の請求後のユーザーエポック

        assertEq(timeCursor, expectedTimeCursor, "Time cursor should be updated to the current week start");
        assertEq(userEpoch, expectedUserEpoch, "User epoch should be updated to 1 after first claim");
    }

    function testClaimTokenNotFound() public {
        // 存在しないトークンアドレスを使用してclaimを呼び出す
        address nonExistentToken = address(0x5);

        vm.prank(alice);
        vm.expectRevert(IMultiTokenFeeDistributor.TokenNotFound.selector);
        feeDistributor.claim(nonExistentToken);
    }

    function testClaimContractIsKilled() public {
        coinA = new SampleToken(1e20);
        feeDistributorInitialize(block.timestamp);

        // コントラクトを停止する
        vm.prank(address(this));
        feeDistributor.killMe();

        // コントラクトが停止された状態でclaimを呼び出す
        vm.prank(alice);
        vm.expectRevert(IMultiTokenFeeDistributor.ContractIsKilled.selector);
        feeDistributor.claim(address(coinA));
    }

    function testClaimTransferFailed() public {
        // AlwaysFailTokenを作成
        vm.prank(address(feeDistributor));
        failToken = new AlwaysFailToken(1e20);

        // FeeDistributorを初期化
        feeDistributor.addToken(address(failToken), block.timestamp);

        vm.prank(alice);
        veToken.createLock(1000 * 1e18, block.timestamp + 8 * WEEK);

        vm.warp(block.timestamp + 2 weeks);
        feeDistributor.toggleAllowCheckpointToken();

        // Aliceが請求を試みる
        vm.prank(alice);
        vm.expectRevert(IMultiTokenFeeDistributor.TransferFailed.selector);
        feeDistributor.claim(address(failToken));
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
        vm.warp(feeDistributor.lastTokenTime(address(coinA)));

        vm.startPrank(alice);

        vm.warp(block.timestamp + 6 days);
        feeDistributor.claim(address(coinA));
        assertEq(coinA.balanceOf(alice), 0);

        vm.warp(block.timestamp + 1 days);
        feeDistributor.claim(address(coinA));
        int256 balanceAlice = safeToInt256(coinA.balanceOf(alice));

        assertTrue(abs(balanceAlice - 1e18) < 20);
    }

    function testAccumulatedClaimsAfterMultipleTokenDeposits() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;
        // Aliceにトークンをロックさせる
        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 10 * WEEK);
        vm.warp(block.timestamp + WEEK);

        // FeeDistributorを初期化し、チェックポイントトークンを許可する
        feeDistributorInitialize(block.timestamp);
        feeDistributor.toggleAllowCheckpointToken();

        // 1回目のトークン転送とチェックポイント
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e18);

        // Aliceが1回目の請求を行い、トークンの残高を確認する
        vm.warp(block.timestamp + WEEK * 2);
        vm.prank(alice);
        feeDistributor.claim(address(coinA));
        uint256 balanceAfterFirstClaim = coinA.balanceOf(alice);
        assertEq(balanceAfterFirstClaim, 1e18);

        // 2回目のトークン転送とチェックポイント
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 2e18);
        vm.warp(block.timestamp + WEEK * 2);
        // feeDistributor.checkpointToken(address(coinA));

        // Aliceが2回目の請求を行い、トークンの残高を確認する
        vm.prank(alice);
        feeDistributor.claim(address(coinA));
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
        vm.warp(block.timestamp + WEEK * 2);
        vm.prank(alice);
        feeDistributor.claim(address(coinA));
        uint256 balanceAfterFirstClaim = coinA.balanceOf(alice);
        assertEq(balanceAfterFirstClaim, 1e18);

        vm.warp(block.timestamp + WEEK * 4);
        feeDistributor.checkpointToken(address(coinA));

        // さらにトークンを転送し、チェックポイントを作成
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 2e18);

        // veTokenの残高がない状態でAliceが請求を試みる
        vm.prank(alice);
        feeDistributor.claim(address(coinA));
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
            feeDistributor.claim(address(coinA));

            uint256 balanceAfter = coinA.balanceOf(user); // claim後のトークン残高を記録
            uint256 claimedAmount = balanceAfter - balanceBefore; // claimによって得られたトークン量を計算

            // 各ユーザーが正しい量のトークンをclaimできたことを確認
            assertTrue(abs(safeToInt256(claimedAmount) - 1e18) < 20);
        }
    }

    function testClaimAfterLongPeriod() public {
        vm.prank(bob);
        coinA = new SampleToken(1e20);

        uint256 amount = 1000 * 1e18;

        // Aliceがトークンをロック
        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 100 * WEEK);

        // トークンをFeeDistributorに転送
        vm.prank(bob);
        coinA.transfer(address(feeDistributor), 1e18);

        // FeeDistributorを初期化
        uint256 startTime = block.timestamp + WEEK * 2;
        feeDistributorInitialize(startTime);
        feeDistributor.toggleAllowCheckpointToken();

        // 30週間以上時間を進める
        vm.warp(block.timestamp + 30 * WEEK);

        // Aliceが請求を行い、トークンの残高を確認する
        vm.prank(alice);
        feeDistributor.claim(address(coinA));
        uint256 balanceAfterClaim = coinA.balanceOf(alice);

        // veSupplyの値を確認
        for (uint256 i = 0; i <= 30; i++) {
            uint256 week = startTime + (i * WEEK);
            uint256 veSupply = feeDistributor.veSupply(week);
            uint256 tokensPerWeek = feeDistributor.tokensPerWeek(address(coinA), week);
            console.log(week);
            console.log(veSupply);
            console.log(tokensPerWeek);
        }

        // 請求後のトークン残高が正しいことを確認
        assertTrue(balanceAfterClaim > 0, "Alice should have received tokens after long period");
    }
}
