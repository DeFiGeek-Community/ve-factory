// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

library VeFactorySchema {
    /// @custom:storage-location erc7201:VeFactory.DeployedVeTokensStorage
    struct VeFactoryStorage {
        mapping(address => VeTokenInfo) deployedVeTokens;
    }

    struct VeTokenInfo {
        address tokenAddr; // Address of the original token.
        string name; // Name of the veToken.
        string symbol; // Symbol of the veToken.
        address veTokenAddr; // Address of the veToken.
    }
}
