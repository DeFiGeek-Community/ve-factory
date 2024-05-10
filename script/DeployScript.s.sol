// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/VeTokenFactory.sol";

contract DeployVeTokenFactory is Script {
    VeTokenFactory public veFactory;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        deploy();

        vm.stopBroadcast();
    }

    function deploy() internal {
        veFactory = new VeTokenFactory();
    }
}

// Deploy command
// forge script script/DeployScript.s.sol:DeployVeTokenFactory --fork-url <RPC_URL> --broadcast --verify -vvvv
