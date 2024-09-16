// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/Token.sol";

contract TokenMintIntegrationTest is Test {
    Token token;
    address minter;
    address recipient;
    uint256 constant YEAR = 365 days;

    function setUp() public {
        minter = address(this);
        recipient = address(0x1); // recipientを設定
        vm.warp(block.timestamp + 365 days * 10);
        token = new Token("Token", "TKN", 18, 1e24, 55_000_000, 365 days, 10, 0);
        token.setMinter(minter);
        token.updateMiningParameters();
    }

    function testShouldMintTheCorrectAmount() public {
        uint256 duration = YEAR;
        vm.warp(block.timestamp + duration); // 時間を1日進める

        uint256 creationTime = token.startEpochTime();
        uint256 initialSupply = token.totalSupply();
        uint256 rate = token.rate();

        uint256 currentTime = block.timestamp;
        uint256 amount = (currentTime - creationTime) * rate;
        token.mint(recipient, amount);

        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.totalSupply(), initialSupply + amount);
    }

    function testShouldRevertOnOvermint() public {
        uint256 duration = YEAR;
        uint256 creationTime = token.startEpochTime();
        uint256 rate = token.rate();

        vm.warp(block.timestamp + duration);

        uint256 currentTime = block.timestamp;
        uint256 amount = (currentTime - creationTime + 2) * rate;
        vm.expectRevert("dev: exceeds allowable mint amount");
        token.mint(recipient, amount);
    }

    function testShouldMintMultipleTimesCorrectly() public {
        uint256 totalSupply = token.totalSupply();
        uint256 balance = 0;
        uint256 epochStart = token.startEpochTime();

        uint256[] memory durations = new uint256[](3);
        durations[0] = (YEAR * 33) / 100;
        durations[1] = YEAR / 2;
        durations[2] = (YEAR * 70) / 100;

        for (uint256 i = 0; i < durations.length; i++) {
            vm.warp(block.timestamp + durations[i]);

            if (block.timestamp - epochStart > YEAR) {
                token.updateMiningParameters();
                epochStart = token.startEpochTime();
            }

            uint256 amount = token.availableSupply() - totalSupply;
            token.mint(recipient, amount);

            balance += amount;
            totalSupply += amount;

            assertEq(token.balanceOf(recipient), balance);
            assertEq(token.totalSupply(), totalSupply);
        }
    }
}
