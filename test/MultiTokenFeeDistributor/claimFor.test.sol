// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "src/test/AlwaysFailToken.sol";

contract MultiTokenFeeDistributor_ClaimForTest is TestBase {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant amount = 1e18 * 1000; // 1000 tokens

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

        token = new SampleToken(1e26);
        coinA = new SampleToken(1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        distributor = new MultiTokenFeeDistributor();

        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.addToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.checkpointTotalSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claimFor.selector, address(distributor));
        _use(MultiTokenFeeDistributor.checkpointToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.killMe.selector, address(distributor));
        _use(MultiTokenFeeDistributor.timeCursor.selector, address(distributor));
        _use(MultiTokenFeeDistributor.veSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claim.selector, address(distributor));
        _use(MultiTokenFeeDistributor.lastTokenTime.selector, address(distributor));
        _use(MultiTokenFeeDistributor.toggleAllowCheckpointToken.selector, address(distributor));

        feeDistributor.initialize(address(veToken), alice, bob);

        vm.prank(alice);
        feeDistributor.addToken(address(coinA), block.timestamp);

        token.transfer(alice, amount);
        token.transfer(bob, amount);
        token.transfer(charlie, amount);

        vm.prank(alice);
        token.approve(address(veToken), amount * 10);
        vm.prank(bob);
        token.approve(address(veToken), amount * 10);
        vm.prank(charlie);
        token.approve(address(veToken), amount * 10);

        vm.prank(alice);
        veToken.createLock(amount, block.timestamp + 8 * WEEK);
        vm.prank(bob);
        veToken.createLock(amount, block.timestamp + 8 * WEEK);
        vm.prank(charlie);
        veToken.createLock(amount, block.timestamp + 8 * WEEK);

        vm.warp(block.timestamp + WEEK * 5);
        coinA.transfer(address(feeDistributor), 1e18 * 10);

        vm.startPrank(alice);
        feeDistributor.checkpointToken(address(coinA));
        vm.warp(block.timestamp + WEEK);
        feeDistributor.checkpointToken(address(coinA));
    }

    function testClaimFor() public {
        uint256 balanceBefore = coinA.balanceOf(bob);

        feeDistributor.claimFor(bob, address(coinA));

        uint256 balanceAfter = coinA.balanceOf(bob);

        assertTrue(balanceAfter > balanceBefore, "Bob should have received tokens");
    }

    function testClaimForTokenNotFound() public {
        address nonExistentToken = address(0x5);

        vm.expectRevert(IMultiTokenFeeDistributor.TokenNotFound.selector);
        feeDistributor.claimFor(bob, nonExistentToken);
    }

    function testClaimForContractIsKilled() public {
        // コントラクトを停止する
        feeDistributor.killMe();

        // コントラクトが停止された状態でclaimForを呼び出す
        vm.expectRevert(IMultiTokenFeeDistributor.ContractIsKilled.selector);
        feeDistributor.claimFor(bob, address(coinA));
    }

    function testClaimForTransferFailed() public {
        // AlwaysFailTokenを使用して、トランスファーが失敗するシナリオを作成
        vm.stopPrank();
        vm.prank(address(feeDistributor));
        failToken = new AlwaysFailToken(1e20);

        // FeeDistributorを初期化
        vm.startPrank(alice);
        feeDistributor.addToken(address(failToken), block.timestamp);

        vm.warp(block.timestamp + 2 weeks);
        feeDistributor.toggleAllowCheckpointToken();

        // Bobが請求を試みる
        vm.expectRevert(IMultiTokenFeeDistributor.TransferFailed.selector);
        feeDistributor.claimFor(bob, address(failToken));
    }
}
