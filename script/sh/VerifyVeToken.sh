#!/bin/bash

# .envファイルを読み込む
if [ -f .env ]; then
  source .env
else
  echo ".env file not found!"
  exit 1
fi

# 必要な環境変数が設定されているか確認
if [ -z "$CHAIN_ID" ] || [ -z "$ETHERSCAN_API_KEY" ]; then
  echo "One or more environment variables are missing in .env file!"
  exit 1
fi

# アドレスファイルからVeTokenのアドレスを読み込む
CHAIN_ID_STR=$(echo $CHAIN_ID | tr -d '\n') # 改行を削除
ADDRESS_FILE="./deployments/$CHAIN_ID_STR/$VE_TOKEN_NAME"
if [ ! -f "$ADDRESS_FILE" ]; then
  echo "VeToken address file not found!"
  exit 1
fi
VETOKEN_ADDRESS=$(cat "$ADDRESS_FILE")

# forge verify-contractコマンドを実行
forge verify-contract $VETOKEN_ADDRESS src/VeToken.sol:VeToken --chain $CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --num-of-optimizations 200 --watch --constructor-args $(cast abi-encode "constructor(address,string,string)" "$TOKEN_ADDRESS" "$VE_TOKEN_NAME" "$VE_TOKEN_SYMBOL")