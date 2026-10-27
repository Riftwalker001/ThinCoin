#!/usr/bin/env bash
# Transfer liquid THIN tokens to friends, testers, or external wallets
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.foundry/bin:$PATH"

RPC_URL="https://mainnet.base.org"

if [ -f "$HOME/.thin_miner_wallet" ]; then
    source "$HOME/.thin_miner_wallet"
fi

echo "=================================================================="
echo "  💸 THIN COIN (THIN) DEV WALLET TRANSFER TOOL"
echo "=================================================================="
echo "  Quickly send liquid THIN to friends, family, or tester wallets."
echo "=================================================================="

if [ -z "$THIN_CONTRACT" ]; then
    read -p "Enter ThinPoWToken Contract Address (0x...): " THIN_CONTRACT
fi

if [ -z "$DEV_KEY" ]; then
    read -p "Enter Dev Private Key: " DEV_KEY
fi

DEV_ADDR=$(cast wallet address --private-key "$DEV_KEY")
BAL_RAW=$(cast call --rpc-url "$RPC_URL" "$THIN_CONTRACT" "balanceOf(address)(uint256)" "$DEV_ADDR" 2>/dev/null || echo "0")
BAL_THIN=$(cast --from-wei "$BAL_RAW" ether 2>/dev/null || echo "0")

echo ""
echo "  Dev Address:          $DEV_ADDR"
echo "  Liquid THIN Balance:  $BAL_THIN THIN"
echo "──────────────────────────────────────────────────────────────────"

read -p "Enter Recipient Address (0x...): " RECIPIENT
read -p "Enter Amount of THIN to Send: " AMOUNT

if [ -z "$RECIPIENT" ] || [ -z "$AMOUNT" ]; then
    echo "[!] Recipient and Amount are required."
    exit 1
fi

echo ""
echo "[+] Sending $AMOUNT THIN to $RECIPIENT on Base Mainnet..."
TX_OUT=$(cast send "$THIN_CONTRACT" \
    "transfer(address,uint256)" \
    "$RECIPIENT" \
    $(cast --to-wei "$AMOUNT" ether) \
    --rpc-url "$RPC_URL" \
    --private-key "$DEV_KEY")

TX_HASH=$(echo "$TX_OUT" | head -n 1)
echo "[✓] Transfer complete! Tx Hash: $TX_HASH"
echo "    BaseScan: https://basescan.org/tx/$TX_HASH"
