// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/FeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorClaimManyTest is Test {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant amount = 1e18 * 1000; // 1000 tokens

    address alice;
    address bob;
    address charlie;

    FeeDistributor distributor;
    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);

        token = new SampleToken(1e20);
        coinA = new SampleToken(1e20);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        uint256 currentTime = block.timestamp;
        distributor = new FeeDistributor(
            address(veToken),
            currentTime,
            address(coinA),
            alice,
            bob
        );

        token.transfer(alice, amount);
        token.transfer(bob, amount);
        token.transfer(charlie, amount);

        token.approve(address(veToken), amount * 10);
        vm.prank(bob);
        token.approve(address(veToken), amount * 10);
        vm.prank(charlie);
        token.approve(address(veToken), amount * 10);

        veToken.createLock(amount, block.timestamp + 8 * WEEK);
        vm.prank(bob);
        veToken.createLock(
            amount,
            block.timestamp + 8 * WEEK
        );
        vm.prank(charlie);
        veToken.createLock(
            amount,
            block.timestamp + 8 * WEEK
        );

        vm.warp(block.timestamp + WEEK * 5);

        coinA.transfer(address(distributor), 1e18 * 10);
        distributor.checkpointToken();
        vm.warp(block.timestamp + WEEK);
        distributor.checkpointToken();
    }

    function testClaimMany() public {
        address[] memory claimants = new address[](20);
        claimants[0] = alice;
        claimants[1] = bob;
        claimants[2] = charlie;

        uint256 balanceBeforeAlice = coinA.balanceOf(alice);
        uint256 balanceBeforeBob = coinA.balanceOf(bob);
        uint256 balanceBeforeCharlie = coinA.balanceOf(charlie);

        distributor.claimMany(claimants);

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

        distributor.claimMany(claimants);

        uint256 balanceAfter = coinA.balanceOf(alice);

        assertTrue(balanceAfter > balanceBefore);
    }
}
