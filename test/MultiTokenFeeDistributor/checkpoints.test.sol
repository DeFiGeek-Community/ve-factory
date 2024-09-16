// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract MultiTokenFeeDistributorCheckpointTest is TestBase {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant YEAR = DAY * 365;
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
        token = new SampleToken(1e26);
        coinA = new SampleToken(1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        distributor = new MultiTokenFeeDistributor();

        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.addToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.checkpointTotalSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.timeCursor.selector, address(distributor));
        _use(MultiTokenFeeDistributor.veSupply.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claim.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claimFor.selector, address(distributor));
        _use(MultiTokenFeeDistributor.lastTokenTime.selector, address(distributor));
        _use(MultiTokenFeeDistributor.toggleAllowCheckpointToken.selector, address(distributor));

        feeDistributor.initialize(address(veToken), alice, bob);
        vm.prank(alice);
        feeDistributor.addToken(address(coinA), block.timestamp);

        token.transfer(alice, 1e24);
        vm.startPrank(alice);
        token.approve(address(veToken), type(uint256).max);
        veToken.createLock(1e18 * 1000, block.timestamp + WEEK * 52);
    }

    function testCheckpointTotalSupply() public {
        uint256 startTime = feeDistributor.timeCursor();
        uint256 weekEpoch = ((block.timestamp + WEEK) / WEEK) * WEEK;

        vm.warp(weekEpoch);

        feeDistributor.checkpointTotalSupply();

        assertEq(feeDistributor.veSupply(startTime), 0);
        assertEq(feeDistributor.veSupply(weekEpoch), veToken.totalSupply());
    }

    function testAdvanceTimeCursor() public {
        uint256 startTime = feeDistributor.timeCursor();
        vm.warp(block.timestamp + YEAR);
        feeDistributor.checkpointTotalSupply();
        uint256 newTimeCursor = feeDistributor.timeCursor();

        assertEq(newTimeCursor, startTime + WEEK * 20);
        assertTrue(feeDistributor.veSupply(startTime + WEEK * 19) > 0);
        assertEq(feeDistributor.veSupply(startTime + WEEK * 20), 0);

        feeDistributor.checkpointTotalSupply();

        assertEq(feeDistributor.timeCursor(), startTime + WEEK * 40);
        assertTrue(feeDistributor.veSupply(startTime + WEEK * 20) > 0);
        assertTrue(feeDistributor.veSupply(startTime + WEEK * 39) > 0);
        assertEq(feeDistributor.veSupply(startTime + WEEK * 40), 0);
    }

    function testClaimCheckpointsTotalSupply() public {
        uint256 startTime = feeDistributor.timeCursor();

        feeDistributor.claim(address(coinA));

        assertEq(feeDistributor.timeCursor(), startTime + WEEK);
    }

    function testToggleAllowCheckpoint() public {
        uint256 lastTokenTime = feeDistributor.lastTokenTime(address(coinA));

        vm.warp(block.timestamp + WEEK);

        feeDistributor.claim(address(coinA));
        assertEq(feeDistributor.lastTokenTime(address(coinA)), lastTokenTime);

        feeDistributor.toggleAllowCheckpointToken();
        vm.stopPrank();
        vm.prank(alice);
        feeDistributor.claim(address(coinA));

        uint256 newLastTokenTime = feeDistributor.lastTokenTime(address(coinA));
        assertTrue(newLastTokenTime > lastTokenTime);
    }
}
