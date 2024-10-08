// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/util/TestBase.sol";
import "src/MultiTokenFeeDistributor.sol";
import "src/Interfaces/IMultiTokenFeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract MultiTokenFeeDistributor_KillFeeDistroTest is TestBase {
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
        coinA.transfer(alice, 1e26);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        distributor = new MultiTokenFeeDistributor();

        _use(MultiTokenFeeDistributor.initialize.selector, address(distributor));
        _use(MultiTokenFeeDistributor.addToken.selector, address(distributor));
        _use(MultiTokenFeeDistributor.isKilled.selector, address(distributor));
        _use(MultiTokenFeeDistributor.killMe.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claim.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claimFor.selector, address(distributor));
        _use(MultiTokenFeeDistributor.claimMany.selector, address(distributor));
        _use(MultiTokenFeeDistributor.emergencyReturn.selector, address(distributor));

        feeDistributor.initialize(address(veToken), alice, bob);
        vm.prank(alice);

        feeDistributor.addToken(address(coinA), block.timestamp);
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
        feeDistributor.claim(address(coinA));
    }

    function testCannotClaimForAfterKilled() public {
        vm.prank(alice);
        feeDistributor.killMe();
        vm.expectRevert();
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
        vm.expectRevert();
        vm.prank(bob);
        feeDistributor.claimMany(claimants, address(coinA));
    }
}
