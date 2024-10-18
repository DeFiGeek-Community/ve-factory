// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "script/DeployMultiTokenFeeDistributor.s.sol";

contract MultiTokenFeeDistributor_KillFeeDistroTest is Test, DeployMultiTokenFeeDistributor {
    address alice;
    address bob;
    address charlie;

    IMultiTokenFeeDistributor public feeDistributor;

    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);

        token = new SampleToken(1e26);
        coinA = new SampleToken(1e26);
        coinA.transfer(alice, 1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");

        vm.startPrank(alice);
        (address proxyAddress,) = deploy(address(veToken), alice, bob, false);
        feeDistributor = IMultiTokenFeeDistributor(proxyAddress);
        vm.stopPrank();

        vm.prank(alice);
        feeDistributor.addToken(address(coinA), vm.getBlockTimestamp());
    }

    function testAssumptions() public view {
        assertFalse(feeDistributor.isKilled());
        assertEq(feeDistributor.emergencyReturn(), bob);
    }

    function testKill() public {
        vm.prank(alice);
        feeDistributor.killMe();
        assertTrue(feeDistributor.isKilled());
    }

    function testMultiKill() public {
        vm.prank(alice);
        feeDistributor.killMe();
        vm.prank(alice);
        feeDistributor.killMe(); // Should not change the state
        assertTrue(feeDistributor.isKilled());
    }

    function testKillingTransfersTokens() public {
        vm.startPrank(alice);
        coinA.transfer(address(feeDistributor), 31337);
        feeDistributor.killMe();
        assertEq(coinA.balanceOf(bob), 31337);
    }

    function testMultiKillTokenTransfer() public {
        vm.startPrank(alice);
        coinA.transfer(address(feeDistributor), 10000);
        feeDistributor.killMe();
        coinA.transfer(address(feeDistributor), 30000);
        feeDistributor.killMe();
        assertEq(coinA.balanceOf(bob), 40000);
    }

    function testOnlyAdminCanKill() public {
        vm.expectRevert(IMultiTokenFeeDistributor.AccessDenied.selector);
        vm.prank(charlie);
        feeDistributor.killMe();
    }

    function testCannotClaimAfterKilled() public {
        vm.prank(alice);
        feeDistributor.killMe();
        vm.expectRevert(IMultiTokenFeeDistributor.ContractIsKilled.selector);
        vm.prank(bob);
        feeDistributor.claim(address(coinA));
    }

    function testCannotClaimForAfterKilled() public {
        vm.prank(alice);
        feeDistributor.killMe();
        vm.expectRevert(IMultiTokenFeeDistributor.ContractIsKilled.selector);
        vm.prank(bob);
        feeDistributor.claimFor(alice, address(coinA));
    }

    function testCannotClaimManyAfterKilled() public {
        address[] memory claimants = new address[](20);
        for (uint256 i = 0; i < 20; i++) {
            claimants[i] = alice;
        }
        vm.prank(alice);
        feeDistributor.killMe();
        vm.expectRevert(IMultiTokenFeeDistributor.ContractIsKilled.selector);
        vm.prank(bob);
        feeDistributor.claimMany(claimants, address(coinA));
    }
}
