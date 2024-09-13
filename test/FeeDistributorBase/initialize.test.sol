// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/FeeDistributorBase.sol";
import "src/Interfaces/IFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorBaseInitializeTest is TestBase {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;

    address alice;
    address bob;

    IFeeDistributor public feeDistributor = IFeeDistributor(target);

    FeeDistributorBase distributor;
    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);

        token = new SampleToken(1e32);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        distributor = new FeeDistributorBase();

        _use(FeeDistributorBase.initialize.selector, address(distributor));
        _use(FeeDistributorBase.votingEscrow.selector, address(distributor));
        _use(FeeDistributorBase.startTime.selector, address(distributor));
        _use(FeeDistributorBase.lastTokenTime.selector, address(distributor));
        _use(FeeDistributorBase.timeCursor.selector, address(distributor));
        _use(FeeDistributorBase.token.selector, address(distributor));
        _use(FeeDistributorBase.admin.selector, address(distributor));
        _use(FeeDistributorBase.emergencyReturn.selector, address(distributor));
    }

    function testInitialize() public {
        vm.prank(alice);
        uint256 startTime = block.timestamp;
        feeDistributor.initialize(
            address(veToken),
            startTime,
            address(coinA),
            alice,
            bob
        );

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
        uint256 startTime = block.timestamp;
        distributor.initialize(address(veToken), startTime, address(token), alice, bob);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        distributor.initialize(address(veToken), startTime, address(token), alice, bob);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        distributor.initialize(address(veToken), startTime, address(token), alice, bob);
    }

}
