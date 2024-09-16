// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/// @title Interface for VeFactory
/// @notice Defines the basic interface for the VeFactory contract.
interface IVeFactory {
    /// @dev Structure to store metadata of veToken.
    struct VeTokenInfo {
        address tokenAddr; // Address of the original token.
        string name; // Name of the veToken.
        string symbol; // Symbol of the veToken.
        address veTokenAddr; // Address of the veToken.
    }

    /// @notice Creates a new veToken contract.
    /// @param _tokenAddr Address of the original token.
    /// @param _name Name of the veToken.
    /// @param _symbol Symbol of the veToken.
    /// @return Address of the newly created veToken.
    function createVeToken(address _tokenAddr, string memory _name, string memory _symbol) external returns (address);

    /// @notice Retrieves deployed veToken information.
    /// @param tokenAddr Address of the Token.
    /// @return VeTokenInfo structure containing veToken details.
    function getDeployedVeTokens(address tokenAddr) external view returns (VeTokenInfo memory);
}
