// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import "src/VeFactory.sol";

contract DeployVeFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        deploy();

        vm.stopBroadcast();
    }

    function deploy() internal returns (address) {
        address initialOwner = msg.sender;
        // VeFactoryの初期化関数とその引数をエンコード
        bytes memory initializerData = abi.encodeCall(
            VeFactory.initialize,
            (initialOwner)
        );

        // UUPSプロキシとしてVeFactoryをデプロイ
        address proxyAddress = Upgrades.deployUUPSProxy(
            "VeFactory.sol",
            initializerData
        );
        // console.log("Deployed VeFactory proxy at:", proxyAddress);
        return proxyAddress;
    }
}

// Deploy command
// forge script script/DeployVeFactory.s.sol:DeployVeFactory --fork-url <RPC_URL> --broadcast --verify -vvvv
