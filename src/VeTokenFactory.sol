// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "./veToken.sol";
import "./Interfaces/IVeTokenFactory.sol";

/// @title VeTokenFactory
/// @notice This contract is used to create new veToken contracts.
contract VeTokenFactory is IVeTokenFactory {
/// @dev Mapping to record information of deployed veTokens.
/// Key is the Token address, value is the VeTokenInfo struct.
mapping(address => VeTokenInfo) internal deployedVeTokens;

    /// @notice Creates a new veToken contract.
    /// @param _tokenAddr Address of the original token.
    /// @param _name Name of the veToken.
    /// @param _symbol Symbol of the veToken.
    /// @return Address of the newly created veToken.
    function createVeToken(
        address _tokenAddr,
        string memory _name,
        string memory _symbol
    ) external override returns (address) {
        require(
            _tokenAddr != address(0),
            "Token address cannot be the zero address."
        );
        require(bytes(_name).length > 0, "Name cannot be empty.");
        require(bytes(_symbol).length > 0, "Symbol cannot be empty.");
        require(
            deployedVeTokens[_tokenAddr].veTokenAddr == address(0),
            "veToken for this token address already exists."
        );
        veToken newVeToken = new veToken(_tokenAddr, _name, _symbol);
        VeTokenInfo memory newVeTokenInfo = VeTokenInfo({
            tokenAddr: _tokenAddr,
            name: _name,
            symbol: _symbol,
            veTokenAddr: address(newVeToken)
        });

        deployedVeTokens[_tokenAddr] = newVeTokenInfo;

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
    ) external view override returns (VeTokenInfo memory) {
        return deployedVeTokens[tokenAddr];
    }
}
