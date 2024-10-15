// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/FeeDistributorBase.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorBase_InitializeTest is Test {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;

    address alice;
    address bob;

    FeeDistributorBase public feeDistributor;
    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);

        token = new SampleToken(1e32);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        feeDistributor = new FeeDistributorBase();
    }

    function testInitialize() public {
        vm.prank(alice);
        uint256 startTime = vm.getBlockTimestamp();
        feeDistributor.initialize(address(veToken), startTime, address(coinA), alice, bob);

        uint256 time = (startTime / WEEK) * WEEK;

        assertEq(feeDistributor.votingEscrow(), address(veToken));
        assertEq(feeDistributor.startTime(), time);
        assertEq(feeDistributor.lastTokenTime(), time);
        assertEq(feeDistributor.timeCursor(), time);
        assertEq(feeDistributor.token(), address(coinA));
        assertEq(feeDistributor.admin(), alice);
        assertEq(feeDistributor.emergencyReturn(), bob);
    }

    function testInitializeMultipleTimesReverts() public {
        uint256 startTime = vm.getBlockTimestamp();
        feeDistributor.initialize(address(veToken), startTime, address(token), alice, bob);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        feeDistributor.initialize(address(veToken), startTime, address(token), alice, bob);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        feeDistributor.initialize(address(veToken), startTime, address(token), alice, bob);
    }
}
