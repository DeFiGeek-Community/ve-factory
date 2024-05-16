// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2024 DeFiGeek Community Japan
 */

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./veToken.sol";
import "./storage/Storage.sol";
import "./storage/Schema.sol";

/// @title VeTokenFactory
/// @notice This contract is used to create new veToken contracts.
contract VeTokenFactory is UUPSUpgradeable, OwnableUpgradeable {
    /// @notice Event triggered when a veToken is created.
    event VeTokenCreated(
        address indexed tokenAddr,
        address indexed veTokenAddr,
        string name,
        string symbol
    );

    function initialize(address admin) public initializer {
        __Ownable_init(admin);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /// @notice Creates a new veToken contract.
    /// @param _tokenAddr Address of the original token.
    /// @param _name Name of the veToken.
    /// @param _symbol Symbol of the veToken.
    /// @return Address of the newly created veToken.
    function createVeToken(
        address _tokenAddr,
        string memory _name,
        string memory _symbol
    ) external returns (address) {
        require(
            _tokenAddr != address(0),
            "Token address cannot be the zero address."
        );
        require(bytes(_name).length > 0, "Name cannot be empty.");
        require(bytes(_symbol).length > 0, "Symbol cannot be empty.");
        require(
            Storage.deployedVeTokens().data[_tokenAddr].veTokenAddr ==
                address(0),
            "veToken for this token address already exists."
        );
        veToken newVeToken = new veToken(_tokenAddr, _name, _symbol);
        Schema.VeTokenInfo memory newVeTokenInfo = Schema.VeTokenInfo({
            tokenAddr: _tokenAddr,
            name: _name,
            symbol: _symbol,
            veTokenAddr: address(newVeToken)
        });

        Storage.deployedVeTokens().data[_tokenAddr] = newVeTokenInfo;

        // Trigger the event.
        emit VeTokenCreated(_tokenAddr, address(newVeToken), _name, _symbol);

        // Return the address of the newly created veToken.
        return address(newVeToken);
    }

    /// @notice Retrieves deployed veToken information.
    /// @param tokenAddr Address of the Token.
    /// @return VeTokenInfo structure containing veToken details.
    function getDeployedVeTokens(
        address tokenAddr
    ) external view returns (Schema.VeTokenInfo memory) {
        return Storage.deployedVeTokens().data[tokenAddr];
    }
}
