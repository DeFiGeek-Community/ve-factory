// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract MultiTokenFeeDistributorClaimManyTest is TestBase {
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

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);

        vm.warp(WEEK * 100);

        token = new SampleToken(1e26);
        coinA = new SampleToken(1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        distributor = new MultiTokenFeeDistributor();

        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.addToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.checkpointTotalSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claimMany.selector, address(distributor));
        _use(MultiTokenFeeDistributor.checkpointToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.timeCursor.selector, address(distributor));
        _use(MultiTokenFeeDistributor.veSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claim.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claimFor.selector, address(distributor));
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
}
