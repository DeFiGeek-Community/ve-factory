// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import "src/VeTokenFactory.sol";

contract DeployVeTokenFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        deploy();

        vm.stopBroadcast();
    }

    function deploy() internal returns (address) {
        address initialOwner = msg.sender;
        // VeTokenFactoryの初期化関数とその引数をエンコード
        bytes memory initializerData = abi.encodeCall(
            VeTokenFactory.initialize,
            (initialOwner)
        );

        // UUPSプロキシとしてVeTokenFactoryをデプロイ
        address proxyAddress = Upgrades.deployUUPSProxy(
            "VeTokenFactory.sol",
            initializerData
        );
        // console.log("Deployed VeTokenFactory proxy at:", proxyAddress);
        return proxyAddress;
    }
}

// Deploy command
// forge script script/DeployScript.s.sol:DeployVeTokenFactory --fork-url <RPC_URL> --broadcast --verify -vvvv
