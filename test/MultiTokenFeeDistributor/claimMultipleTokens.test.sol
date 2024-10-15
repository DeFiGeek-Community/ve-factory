// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "src/test/AlwaysFailToken.sol";
import "script/DeployMultiTokenFeeDistributor.s.sol";

contract MultiTokenFeeDistributor_ClaimMultipleTokensTest is Test, DeployMultiTokenFeeDistributor {
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
    SampleToken coinB;
    AlwaysFailToken failToken;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);

        token = new SampleToken(1e26);
        coinA = new SampleToken(1e26);
        coinB = new SampleToken(1e26);

        veToken = new VeToken(address(token), "veToken", "veTKN");

        (address proxyAddress,) = deploy(address(veToken), alice, bob, false);
        feeDistributor = IMultiTokenFeeDistributor(proxyAddress);

        vm.prank(address(feeDistributor));
        failToken = new AlwaysFailToken(1e26);

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
        coinB.transfer(address(feeDistributor), 1e18 * 10);

        vm.startPrank(alice);
        feeDistributor.addToken(address(coinA), vm.getBlockTimestamp());
        feeDistributor.addToken(address(coinB), vm.getBlockTimestamp());

        feeDistributor.checkpointToken(address(coinA));
        feeDistributor.checkpointToken(address(coinB));
        vm.warp(vm.getBlockTimestamp() + WEEK);
        feeDistributor.checkpointToken(address(coinA));
        feeDistributor.checkpointToken(address(coinB));
    }

    function testClaimMultipleTokens() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(coinA);
        tokens[1] = address(coinB);

        uint256 balanceBeforeAliceA = coinA.balanceOf(alice);
        uint256 balanceBeforeAliceB = coinB.balanceOf(alice);

        feeDistributor.claimMultipleTokens(tokens);

        uint256 balanceAfterAliceA = coinA.balanceOf(alice);
        uint256 balanceAfterAliceB = coinB.balanceOf(alice);

        assertTrue(balanceAfterAliceA > balanceBeforeAliceA);
        assertTrue(balanceAfterAliceB > balanceBeforeAliceB);
    }

    function testClaimMultipleTokensSameAccount() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(coinA);
        tokens[1] = address(coinB);

        uint256 balanceBefore = coinA.balanceOf(alice) + coinB.balanceOf(alice);

        feeDistributor.claimMultipleTokens(tokens);

        uint256 balanceAfter = coinA.balanceOf(alice) + coinB.balanceOf(alice);

        assertTrue(balanceAfter > balanceBefore);
    }

    function testClaimMultipleTokensRevertsForInvalidToken() public {
        address[] memory tokens = new address[](3);
        tokens[0] = address(coinA);
        tokens[1] = address(coinB);
        tokens[2] = address(0x4); // Invalid token address

        vm.expectRevert(IMultiTokenFeeDistributor.TokenNotFound.selector);
        feeDistributor.claimMultipleTokens(tokens);
    }

    function testClaimMultipleTokensTransferFailed() public {
        vm.startPrank(alice);
        feeDistributor.addToken(address(failToken), vm.getBlockTimestamp());

        feeDistributor.checkpointToken(address(failToken));
        vm.warp(vm.getBlockTimestamp() + WEEK);
        feeDistributor.checkpointToken(address(failToken));

        address[] memory tokens = new address[](3);
        tokens[0] = address(coinA);
        tokens[1] = address(coinB);
        tokens[2] = address(failToken);

        vm.expectRevert(IMultiTokenFeeDistributor.TransferFailed.selector);
        feeDistributor.claimMultipleTokens(tokens);
    }

    function testClaimMultipleTokensContractIsKilled() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(coinA);
        tokens[1] = address(coinB);

        // コントラクトを停止する
        feeDistributor.killMe();

        // コントラクトが停止された状態でclaimMultipleTokensを呼び出す
        vm.expectRevert(IMultiTokenFeeDistributor.ContractIsKilled.selector);
        feeDistributor.claimMultipleTokens(tokens);
    }

    function testClaimMultipleTokensNoTokensProvided() public {
        // すべてのトークンを削除
        feeDistributor.removeToken(address(coinA));
        feeDistributor.removeToken(address(coinB));

        // 空のトークンリストでclaimMultipleTokensを呼び出す
        address[] memory tokens = new address[](0);

        vm.expectRevert(IMultiTokenFeeDistributor.NoTokensProvided.selector);
        feeDistributor.claimMultipleTokens(tokens);
    }
}
