// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/FeeDistributorBase.sol";
import "src/Interfaces/IFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorBaseCheckpointTest is TestBase {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = DAY * 7;
    uint256 constant YEAR = DAY * 365;
    address alice;
    address bob;
    address charlie;

    IFeeDistributor public feeDistributor = IFeeDistributor(target);

    FeeDistributorBase distributor;
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
        distributor = new FeeDistributorBase();

        _use(FeeDistributorBase.initialize.selector, address(distributor));
        _use(
            FeeDistributorBase.checkpointTotalSupply.selector,
            address(distributor)
        );
        _use(FeeDistributorBase.timeCursor.selector, address(distributor));
        _use(FeeDistributorBase.veSupply.selector, address(distributor));
        _use(FeeDistributorBase.claim.selector, address(distributor));
        _use(FeeDistributorBase.claimFor.selector, address(distributor));
        _use(FeeDistributorBase.lastTokenTime.selector, address(distributor));
        _use(
            FeeDistributorBase.toggleAllowCheckpointToken.selector,
            address(distributor)
        );

        // vm.warp(block.timestamp + YEAR);

        feeDistributor.initialize(
            address(veToken),
            block.timestamp,
            address(coinA),
            alice,
            bob
        );

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

        feeDistributor.claim();

        assertEq(feeDistributor.timeCursor(), startTime + WEEK);
    }

    function testToggleAllowCheckpoint() public {
        uint256 lastTokenTime = feeDistributor.lastTokenTime();

        vm.warp(block.timestamp + WEEK);

        feeDistributor.claim();
        assertEq(feeDistributor.lastTokenTime(), lastTokenTime);

        feeDistributor.toggleAllowCheckpointToken();
        vm.stopPrank();
        vm.prank(alice);
        feeDistributor.claim();

        uint256 newLastTokenTime = feeDistributor.lastTokenTime();
        assertTrue(newLastTokenTime > lastTokenTime);
    }
}
