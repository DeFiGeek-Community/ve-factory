// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "src/Interfaces/IFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";
import "script/DeployFeeDistributor.s.sol";

contract SingleTokenFeeDistributor_InitializeTest is Test, DeployFeeDistributor {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;

    address alice;
    address bob;
    uint256 startTime;

    IFeeDistributor public feeDistributor;

    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);

        token = new SampleToken(1e32);
        veToken = new VeToken(address(token), "veToken", "veTKN");

        startTime = vm.getBlockTimestamp();

        (address proxyAddress,) = deploy(address(veToken), startTime, address(coinA), alice, bob, false);
        feeDistributor = IFeeDistributor(proxyAddress);
    }

    function testInitialize() public view {

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

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        feeDistributor.initialize(address(veToken), startTime, address(token), alice, bob);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        feeDistributor.initialize(address(veToken), startTime, address(token), alice, bob);
    }
}
