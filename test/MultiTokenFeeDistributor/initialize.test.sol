// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract MultiTokenFeeDistributor_InitializeTest is TestBase {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;

    address alice;
    address bob;

    IMultiTokenFeeDistributor public feeDistributor = IMultiTokenFeeDistributor(target);

    MultiTokenFeeDistributor distributor;
    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);

        token = new SampleToken(1e32);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        distributor = new MultiTokenFeeDistributor();

        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.votingEscrow.selector, address(distributor));
        _use(MultiTokenFeeDistributor.startTime.selector, address(distributor));
        _use(MultiTokenFeeDistributor.lastTokenTime.selector, address(distributor));
        _use(MultiTokenFeeDistributor.timeCursor.selector, address(distributor));
        _use(MultiTokenFeeDistributor.admin.selector, address(distributor));
        _use(MultiTokenFeeDistributor.emergencyReturn.selector, address(distributor));
    }

    function testInitialize() public {
        vm.prank(alice);
        feeDistributor.initialize(address(veToken), alice, bob);

        assertEq(feeDistributor.votingEscrow(), address(veToken));
        assertEq(feeDistributor.admin(), alice);
        assertEq(feeDistributor.emergencyReturn(), bob);
    }

    function testInitializeMultipleTimesReverts() public {
        feeDistributor.initialize(address(veToken), alice, bob);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        feeDistributor.initialize(address(veToken), alice, bob);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        feeDistributor.initialize(address(veToken), alice, bob);
    }
}
