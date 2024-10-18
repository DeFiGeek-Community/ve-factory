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


forge verify-contract 0x0651ABE642eFc46a4b9a6027B543eA7f875274f0 src/VeToken.sol:VeToken --chain $CHAIN_ID --etherscan-api-key $ETHERSCAN_API_KEY --num-of-optimizations 200 --watch --constructor-args $(cast abi-encode "constructor(address,string,string)" "0xdca6BcCecd7C25C654DFD80EcF7c63731B12Df5e" "veTXJP" "veTXJP")
