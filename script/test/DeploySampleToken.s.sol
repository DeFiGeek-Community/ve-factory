// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DeployBase} from "script/util/DeployBase.sol";
import "forge-std/console.sol";
import "src/test/SampleToken.sol";

contract DeploySampleToken is DeployBase {
    function run() external {
        uint256 deployerPrivateKey = getEnvUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // .envから初期供給量を取得
        uint256 initialSupply = 2e20;

        // SampleTokenをデプロイ
        SampleToken sampleToken = new SampleToken(initialSupply);
        address sampleTokenAddress = address(sampleToken);
        console.log("Deployed SampleToken at:", sampleTokenAddress);

        // SampleTokenのアドレスをファイルに書き出し
        writeDeployedAddress(sampleTokenAddress, "SampleToken");

        vm.stopBroadcast();
    }
}
