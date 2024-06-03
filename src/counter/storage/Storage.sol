// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Schema} from "./Schema.sol";

library Storage {
    function CounterState() internal pure returns(Schema.$CounterState storage ref) {
        assembly { ref.slot := 0x9d2213992402928855512c8ba65338877a8da4519b1df3203c2a2647166a8d00 }
    }

    function DeployedVeTokens() internal pure returns(Schema.$VeTokenInfo storage ref) {
        // keccak256(abi.encode(uint256(keccak256("VeFactory.VeTokenInfo")) - 1)) & ~bytes32(uint256(0xff));
        assembly { ref.slot := 0x034eab1f967b01acc29ed43b575543f84affebe55494d54d0d4700702700f900 }
    }
}
