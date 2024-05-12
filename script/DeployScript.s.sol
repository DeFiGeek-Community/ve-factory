// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import "../src/VeTokenFactory.sol";

contract DeployVeTokenFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        deploy();

        vm.stopBroadcast();
    }

    function deploy() internal {

        address initialOwner = vm.envAddress("INITIAL_OWNER");
        // VeTokenFactoryの初期化関数とその引数をエンコード
        bytes memory initializerData = abi.encodeWithSelector(
            VeTokenFactory.initialize.selector,
            initialOwner // ここに初期所有者のアドレスを指定
        );

        // UUPSプロキシとしてVeTokenFactoryをデプロイ
        address proxyAddress = Upgrades.deployUUPSProxy(
            "src/VeTokenFactory.sol:VeTokenFactory",
            initializerData
        );
        console.log("Deployed VeTokenFactory proxy at:", proxyAddress);
    }
}

// Deploy command
// forge script script/DeployScript.s.sol:DeployVeTokenFactory --fork-url <RPC_URL> --broadcast --verify -vvvv
