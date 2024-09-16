// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/FeeDistributorBase.sol";
import "src/Interfaces/IFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorBaseKillFeeDistroTest is TestBase {
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
        coinA.transfer(alice, 1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        distributor = new FeeDistributorBase();

        _use(FeeDistributorBase.initialize.selector, address(distributor));
        _use(FeeDistributorBase.isKilled.selector, address(distributor));
        _use(FeeDistributorBase.killMe.selector, address(distributor));
        _use(FeeDistributorBase.claim.selector, address(distributor));
        _use(FeeDistributorBase.claimFor.selector, address(distributor));
        _use(FeeDistributorBase.claimMany.selector, address(distributor));
        _use(FeeDistributorBase.emergencyReturn.selector, address(distributor));

        feeDistributor.initialize(address(veToken), block.timestamp, address(coinA), alice, bob);
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
        coinA.transfer(target, 31337);
        feeDistributor.killMe();
        assertEq(coinA.balanceOf(bob), 31337);
    }

    function testMultiKillTokenTransfer() public {
        vm.startPrank(alice);
        coinA.transfer(target, 10000);
        feeDistributor.killMe();
        coinA.transfer(target, 30000);
        feeDistributor.killMe();
        assertEq(coinA.balanceOf(bob), 40000);
    }

    function testOnlyAdminCanKill() public {
        vm.expectRevert();
        vm.prank(charlie);
        feeDistributor.killMe();
    }

    function testCannotClaimAfterKilled() public {
        vm.prank(alice);
        feeDistributor.killMe();
        vm.expectRevert();
        vm.prank(bob);
        feeDistributor.claim();
    }

    function testCannotClaimForAfterKilled() public {
        vm.prank(alice);
        feeDistributor.killMe();
        vm.expectRevert();
        vm.prank(bob);
        feeDistributor.claimFor(alice);
    }

    function testCannotClaimManyAfterKilled() public {
        address[] memory claimants = new address[](20);
        for (uint256 i = 0; i < 20; i++) {
            claimants[i] = alice;
        }
        vm.prank(alice);
        feeDistributor.killMe();
        vm.expectRevert();
        vm.prank(bob);
        feeDistributor.claimMany(claimants);
    }
}
