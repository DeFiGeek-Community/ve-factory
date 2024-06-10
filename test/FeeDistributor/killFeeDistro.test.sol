// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/FeeDistributor.sol";
import "src/VeToken.sol";
import "src/test/SampleToken.sol";

contract FeeDistributorKillFeeDistroTest is Test {
    address alice;
    address bob;
    address charlie;

    FeeDistributor distributor;
    VeToken veToken;
    IERC20 token;
    SampleToken coinA;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);

        token = new SampleToken(1e22);
        coinA = new SampleToken(1e22);
        veToken = new VeToken(address(token), "veToken", "veTKN");
        uint256 currentTime = block.timestamp;
        distributor = new FeeDistributor(
            address(veToken),
            currentTime,
            address(coinA),
            alice,
            bob
        );
    }

    function testKillFeeDistro() public {
        // 初期状態の確認
        assertFalse(distributor.isKilled());
        assertEq(distributor.emergencyReturn(), bob);

        // kill関数のテスト
        vm.prank(alice);
        distributor.killMe();
        assertTrue(distributor.isKilled());

        // kill関数を複数回呼び出しても状態が変わらないことを確認
        vm.prank(alice);
        distributor.killMe();
        assertTrue(distributor.isKilled());

        // トークン転送のテスト
        coinA.transfer(address(distributor), 31337);
        vm.prank(alice);
        distributor.killMe();
        assertEq(coinA.balanceOf(bob), 31337);

        // 複数回killを呼び出した後のトークン転送テスト
        coinA.transfer(address(distributor), 10000);
        vm.prank(alice);
        distributor.killMe();
        coinA.transfer(address(distributor), 30000);
        vm.prank(alice);
        distributor.killMe();
        assertEq(coinA.balanceOf(bob), 40000);

        // 管理者以外がkillを呼び出せないことを確認
        vm.expectRevert();
        vm.prank(charlie);
        distributor.killMe();

        // kill後にclaimが呼び出せないことを確認
        vm.prank(alice);
        distributor.killMe();
        vm.expectRevert();
        vm.prank(bob);
        distributor.claim();

        // kill後にclaim(address)が呼び出せないことを確認
        vm.expectRevert();
        vm.prank(bob);
        distributor.claim(alice);

        // kill後にclaimManyが呼び出せないことを確認
        vm.expectRevert();
        vm.prank(bob);
        distributor.claimMany(new address[](20));
    }
}
