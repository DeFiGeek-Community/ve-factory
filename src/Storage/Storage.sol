// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Schema} from "./Schema.sol";

library Storage {
    // bytes32 private constant DEPLOYED_VETOKENS_STORAGE_LOCATION = keccak256(abi.encode(uint256(keccak256("VeFactory.VeTokenInfo")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant DEPLOYED_VETOKENS_STORAGE_LOCATION =
        0x034eab1f967b01acc29ed43b575543f84affebe55494d54d0d4700702700f900;

    function deployedVeTokens()
        internal
        pure
        returns (Schema.$DeployedVeTokensStorage storage s)
    {
        assembly {
            s.slot := DEPLOYED_VETOKENS_STORAGE_LOCATION
        }
    }
}
