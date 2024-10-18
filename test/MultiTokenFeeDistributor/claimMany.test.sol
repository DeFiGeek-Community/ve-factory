// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "src/test/AlwaysFailToken.sol";
import "script/DeployMultiTokenFeeDistributor.s.sol";

contract MultiTokenFeeDistributor_ClaimManyTest is Test, DeployMultiTokenFeeDistributor {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant amount = 1e18 * 1000; // 1000 tokens

    address alice;
    address bob;
    address charlie;

    IMultiTokenFeeDistributor public feeDistributor;

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

        vm.startPrank(alice);
        (address proxyAddress,) = deploy(address(veToken), alice, bob, false);
        feeDistributor = IMultiTokenFeeDistributor(proxyAddress);
        vm.stopPrank();

        vm.prank(alice);
        feeDistributor.addToken(address(coinA), vm.getBlockTimestamp());

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
        veToken.createLock(amount, vm.getBlockTimestamp() + 8 * WEEK);
        vm.prank(bob);
        veToken.createLock(amount, vm.getBlockTimestamp() + 8 * WEEK);
        vm.prank(charlie);
        veToken.createLock(amount, vm.getBlockTimestamp() + 8 * WEEK);

        vm.warp(vm.getBlockTimestamp() + WEEK * 5);

        coinA.transfer(address(feeDistributor), 1e18 * 10);

        vm.startPrank(alice);
        feeDistributor.checkpointToken(address(coinA));
        vm.warp(vm.getBlockTimestamp() + WEEK);
        feeDistributor.checkpointToken(address(coinA));
    }

    function testClaimMany() public {
        address[] memory claimants = new address[](20);
        claimants[0] = alice;
        claimants[1] = bob;
        claimants[2] = charlie;

        uint256 balanceBeforeAlice = coinA.balanceOf(alice);
        uint256 balanceBeforeBob = coinA.balanceOf(bob);
        uint256 balanceBeforeCharlie = coinA.balanceOf(charlie);

        feeDistributor.claimMany(claimants, address(coinA));

        uint256 balanceAfterAlice = coinA.balanceOf(alice);
        uint256 balanceAfterBob = coinA.balanceOf(bob);
        uint256 balanceAfterCharlie = coinA.balanceOf(charlie);

        assertTrue(balanceAfterAlice > balanceBeforeAlice);
        assertTrue(balanceAfterBob > balanceBeforeBob);
        assertTrue(balanceAfterCharlie > balanceBeforeCharlie);
    }

    function testClaimManySameAccount() public {
        address[] memory claimants = new address[](20);
        for (uint256 i = 0; i < claimants.length; i++) {
            claimants[i] = alice;
        }

        uint256 balanceBefore = coinA.balanceOf(alice);

        feeDistributor.claimMany(claimants, address(coinA));

        uint256 balanceAfter = coinA.balanceOf(alice);

        assertTrue(balanceAfter > balanceBefore);
    }

    function testClaimManyTokenNotFound() public {
        address[] memory claimants = new address[](3);
        claimants[0] = alice;
        claimants[1] = bob;
        claimants[2] = charlie;

        address nonExistentToken = address(0x5);

        vm.expectRevert(IMultiTokenFeeDistributor.TokenNotFound.selector);
        feeDistributor.claimMany(claimants, nonExistentToken);
    }

    function testClaimManyContractIsKilled() public {
        address[] memory claimants = new address[](3);
        claimants[0] = alice;
        claimants[1] = bob;
        claimants[2] = charlie;

        // コントラクトを停止する
        feeDistributor.killMe();

        // コントラクトが停止された状態でclaimManyを呼び出す
        vm.expectRevert(IMultiTokenFeeDistributor.ContractIsKilled.selector);
        feeDistributor.claimMany(claimants, address(coinA));
    }

    function testClaimTransferFailed() public {
        // AlwaysFailTokenを作成
        vm.stopPrank();
        vm.prank(address(feeDistributor));
        failToken = new AlwaysFailToken(1e20);

        // FeeDistributorを初期化
        vm.startPrank(alice);
        feeDistributor.addToken(address(failToken), vm.getBlockTimestamp());

        vm.warp(vm.getBlockTimestamp() + 2 weeks);
        feeDistributor.toggleAllowCheckpointToken();

        address[] memory claimants = new address[](3);
        claimants[0] = alice;
        claimants[1] = bob;
        claimants[2] = charlie;

        // Aliceが請求を試みる
        vm.expectRevert(IMultiTokenFeeDistributor.TransferFailed.selector);
        feeDistributor.claimMany(claimants, address(failToken));
    }
}
