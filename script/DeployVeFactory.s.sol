// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DeployBase} from "./util/DeployBase.sol";
import "openzeppelin-foundry-upgrades/Upgrades.sol";
import "src/VeFactory.sol";

contract DeployVeFactory is DeployBase {
    function run() external {
        uint256 deployerPrivateKey = getEnvUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        address proxyAddress = deploy(deployerAddress);

        writeDeployedAddress(proxyAddress, "VeFactory_Proxy");
        console.log("Deployed VeFactory proxy at:", proxyAddress);

        vm.stopBroadcast();
    }

    function deploy(address initialOwner) internal returns (address) {
        // VeFactoryの初期化関数とその引数をエンコード
        bytes memory initializerData = abi.encodeCall(VeFactory.initialize, (initialOwner));

        // UUPSプロキシとしてVeFactoryをデプロイ
        address proxyAddress = Upgrades.deployUUPSProxy("VeFactory.sol", initializerData);
        return proxyAddress;
    }
}

// Deploy command
// ｓｈ　script/sh/VerifyVeToken.sh
