#!/bin/bash

# .envファイルを読み込む
if [ -f .env ]; then
  source .env
else
  echo ".env file not found!"
  exit 1
fi

# 必要な環境変数が設定されているか確認
if [ -z "$RPC_URL" ] || [ -z "$DEPLOYER_PRIVATE_KEY" ] || [ -z "$VOTING_ESCROW" ] || [ -z "$ADMIN" ] || [ -z "$EMERGENCY_RETURN" ]; then
  echo "One or more environment variables are missing in .env file!"
  exit 1
fi

# forge scriptコマンドを実行
if [ "$RPC_URL" == "127.0.0.1:8545" ]; then
  forge script script/DeployMultiTokenFeeDistributor.s.sol:DeployMultiTokenFeeDistributor --fork-url $RPC_URL --broadcast -vvvv
else
  forge script script/DeployMultiTokenFeeDistributor.s.sol:DeployMultiTokenFeeDistributor --fork-url $RPC_URL --broadcast --verify -vvvv --etherscan-api-key $ETHERSCAN_API_KEY 
fi