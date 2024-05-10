// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

library Schema {
    /// @custom:storage-location erc7201:VeTokenFactory.DeployedVeTokensStorage
    struct $DeployedVeTokensStorage {
        mapping(address => VeTokenInfo) data;
    }

    struct VeTokenInfo {
        address tokenAddr; // Address of the original token.
        string name; // Name of the veToken.
        string symbol; // Symbol of the veToken.
        address veTokenAddr; // Address of the veToken.
    }
}
