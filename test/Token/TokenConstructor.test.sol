// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Token.sol";

contract TokenConstructorTest is Test {
    uint256 constant YEAR = 365 days;

    Token token;
    uint256 decimals;

    function setUp() public {
        // Set up the environment and deploy the token contract with predefined parameters
        vm.warp(block.timestamp + 365 days * 10); // Fast-forward time to ensure no interference with time-dependent parameters
        decimals = 14;
        token = new Token(
            "Token",
            "TKN",
            uint8(decimals),
            450_000_000,
            55_000_000,
            YEAR,
            10,
            1 days
        );
    }

    function testInitialSettings() public view {
        // Test if the initial settings of the token contract are correctly set
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), decimals);
        assertEq(token.totalSupply(), 450_000_000 * (10 ** decimals));
        assertEq(token.initialRate(), (55_000_000 * (10 ** decimals)) / YEAR);
        assertEq(token.rateReductionTime(), YEAR);
        assertEq(token.rateReductionCoefficient(), (10 * (10 ** decimals)) / 9);
        assertEq(token.inflationDelay(), 1 days);
    }

    function testDecimalsBoundary() public {
        // Test the boundary conditions for the decimals parameter
        Token tokenWithMinDecimals = new Token(
            "Token",
            "TKN",
            4, // Minimum allowed decimals
            450_000_000,
            55_000_000,
            YEAR,
            10,
            1 days
        );
        assertEq(tokenWithMinDecimals.decimals(), 4);

        Token tokenWithMaxDecimals = new Token(
            "Token",
            "TKN",
            18, // Maximum allowed decimals
            450_000_000,
            55_000_000,
            YEAR,
            90,
            1 days
        );
        assertEq(tokenWithMaxDecimals.decimals(), 18);
    }

    function testInitialSupplyZero() public {
        // Test the contract behavior when the initial supply is set to zero
        Token tokenWithZeroSupply = new Token(
            "Token",
            "TKN",
            14,
            0, // Zero initial supply
            55_000_000,
            YEAR,
            10,
            1 days
        );
        assertEq(tokenWithZeroSupply.totalSupply(), 0);
    }

    function testRateReductionTimeEffect() public {
        // Test the effect of rate reduction time on the mining rate
        Token tokenWithStandardReduction = new Token(
            "Token",
            "TKN",
            14,
            450_000_000,
            55_000_000,
            YEAR,
            10,
            1 days
        );
        assertEq(tokenWithStandardReduction.rate(), 0);
        vm.warp(block.timestamp + 2 days); // Advance time to trigger rate reduction
        tokenWithStandardReduction.updateMiningParameters(); // Update mining parameters
        assertEq(
            tokenWithStandardReduction.rate(),
            (55_000_000 * (10 ** decimals)) / YEAR
        );
    }

    function testInflationDelayEffect() public {
        // Test the contract behavior when inflation delay is set to zero
        Token tokenWithNoDelay = new Token(
            "Token",
            "TKN",
            14,
            450_000_000,
            55_000_000,
            YEAR,
            10,
            0 // Zero inflation delay
        );
        assertEq(tokenWithNoDelay.rate(), 0);
        tokenWithNoDelay.updateMiningParameters(); // Immediately update mining parameters
        assertEq(
            tokenWithNoDelay.rate(),
            (55_000_000 * (10 ** decimals)) / YEAR
        );
    }

    function testRateReductionCoefficientEffect() public {
        // Test how different rate reduction coefficients affect the token's mining rate over time
        uint256 initialRate = (55_000_000 * (10 ** 18)) / YEAR;
        uint256 denominator = 10 ** 18;

        // High coefficient should result in a slower rate reduction
        Token tokenWithHighCoefficient = new Token(
            "Token",
            "TKN",
            18,
            450_000_000,
            55_000_000,
            YEAR,
            10, // This implies a 10% reduction per YEAR
            0
        );
        tokenWithHighCoefficient.updateMiningParameters(); // Initialize mining parameters
        assertEq(
            tokenWithHighCoefficient.rate(),
            initialRate
        );

        // Simulate passing of one rate reduction period
        vm.warp(block.timestamp + YEAR);
        tokenWithHighCoefficient.updateMiningParameters();
        // Expected rate after one YEAR with a 10% reduction
        assertEq(
            tokenWithHighCoefficient.rate(),
            (initialRate * denominator) / 1_111_111_111_111_111_111
        );

        // Low coefficient should result in a faster rate reduction
        Token tokenWithLowCoefficient = new Token(
            "Token",
            "TKN",
            18,
            450_000_000,
            55_000_000,
            YEAR,
            50, // This implies a 50% reduction per YEAR
            0
        );
        tokenWithLowCoefficient.updateMiningParameters(); // Initialize mining parameters

        // Simulate passing of one rate reduction period
        vm.warp(block.timestamp + YEAR + 1 days); // Ensure we're beyond the first reduction period
        tokenWithLowCoefficient.updateMiningParameters();
        // Expected rate after one YEAR with a 50% reduction
        uint256 expectedLowCoefficientRate = initialRate / 2;
        assertEq(
            tokenWithLowCoefficient.rate(),
            expectedLowCoefficientRate
        );
    }
}
