// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VeFactorySchema} from "./VeFactorySchema.sol";

library VeFactoryStorage {
    // bytes32 private constant DEPLOYED_VETOKENS_STORAGE_LOCATION = keccak256(abi.encode(uint256(keccak256("VeFactory.VeTokenInfo")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant DEPLOYED_VETOKENS_STORAGE_LOCATION =
        0x965167c5566e6400ca5c0b84cde19d419bf7efdf30963b12dce3259d1e4b8d00;

    function Factory() internal pure returns (VeFactorySchema.VeFactoryStorage storage s) {
        assembly {
            s.slot := DEPLOYED_VETOKENS_STORAGE_LOCATION
        }
    }
}
