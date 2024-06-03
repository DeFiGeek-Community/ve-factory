// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * Schema v0.1.0
 */
library Schema {
    /// @custom:storage-location erc7201:Template.Counter.CounterState
    struct $CounterState {
        uint256 number;
    }

    /// @custom:storage-location erc7201:VeFactory.VeTokenInfo
    struct $VeTokenInfo {
        address tokenAddr; // Address of the original token.
        string name; // Name of the veToken.
        string symbol; // Symbol of the veToken.
        address veTokenAddr; // Address of the veToken.
    }
}
