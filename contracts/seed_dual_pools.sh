#!/usr/bin/env bash
# Seed Dual Pools on Base Mainnet: THIN/WETH & THIN/FRAC
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

export PATH="$HOME/.foundry/bin:$PATH"

RPC_URL="https://mainnet.base.org"
UNISWAP_V2_ROUTER="0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24"
WETH_ADDRESS="0x4200000000000000000000000000000000000006"
FRAC_ADDRESS="0x8F92de279E8f942Cb4E37F3A207A221CB5566C04"

echo "=================================================================="
echo "  🚀 THIN COIN (THIN) DUAL-POOL LIQUIDITY INITIALIZATION"
echo "=================================================================="
echo "  Pool 1: THIN / WETH  (Cash Gateway — Traders & Bots)"
echo "  Pool 2: THIN / FRAC  (PoW Ecosystem Triangular Bridge — \$0 Out of Pocket)"
echo "=================================================================="

if [ -f "$DIR/.deployer_wallet" ]; then
    source "$DIR/.deployer_wallet"
fi

if [ -z "$DEV_KEY" ] && [ -n "$PRIVATE_KEY" ]; then
    DEV_KEY="$PRIVATE_KEY"
fi

if [ -z "$THIN_CONTRACT" ]; then
    read -p "Enter Deployed ThinPoWToken Address (0x...): " THIN_CONTRACT
fi

if [ -z "$DEV_KEY" ]; then
    read -p "Enter Dev Private Key: " DEV_KEY
fi

# Check ETH Balance
DEV_ADDR=$(cast wallet address --private-key "$DEV_KEY")
ETH_BAL=$(cast balance "$DEV_ADDR" --rpc-url "$RPC_URL")
echo "[i] Deployer Address:     $DEV_ADDR"
echo "[i] Deployer ETH Balance: $(cast --from-wei "$ETH_BAL" ether) ETH"

# Dynamic Pool ETH calculation (Reserve 0.0005 ETH for future gas)
SUGGESTED_POOL_WEI=$(python3 -c "bal = int('$ETH_BAL'); res = 500000000000000; print(max(0, bal - res))")
SUGGESTED_POOL_ETH=$(cast --from-wei "$SUGGESTED_POOL_WEI" ether)

if [ -z "$INPUT_POOL_ETH" ]; then
    if [ -t 0 ]; then
        read -p "Enter ETH amount for THIN/WETH Pool [Default: $SUGGESTED_POOL_ETH ETH]: " INPUT_POOL_ETH
    fi
fi
POOL_ETH="${INPUT_POOL_ETH:-$SUGGESTED_POOL_ETH}"
POOL_ETH_WEI=$(cast --to-wei "$POOL_ETH" ether)

echo "[+] Target Liquidity: 35,000 THIN + $POOL_ETH ETH"

# 1. Approve Uniswap Router for THIN if needed
THIN_ALLOWANCE=$(cast call "$THIN_CONTRACT" "allowance(address,address)(uint256)" "$DEV_ADDR" "$UNISWAP_V2_ROUTER" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
if [ "$THIN_ALLOWANCE" = "0" ] || [ $(cast --to-unit "$THIN_ALLOWANCE" ether | cut -d. -f1) -lt 70000 ]; then
    echo "[+] Approving Uniswap V2 Router for THIN..."
    cast send "$THIN_CONTRACT" "approve(address,uint256)" "$UNISWAP_V2_ROUTER" $(cast --to-wei 70000 ether) --rpc-url "$RPC_URL" --private-key "$DEV_KEY"
    sleep 2
else
    echo "[✓] Uniswap V2 Router already approved for THIN."
fi

# 2. Add Liquidity: THIN / WETH
echo "[+] Creating & Seeding Pool 1 (THIN/WETH Primary Cash Gateway)..."
cast send "$UNISWAP_V2_ROUTER" \
    "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)" \
    "$THIN_CONTRACT" \
    $(cast --to-wei 35000 ether) \
    0 \
    0 \
    "$DEV_ADDR" \
    $(($(date +%s) + 1200)) \
    --value "$POOL_ETH_WEI" \
    --rpc-url "$RPC_URL" \
    --private-key "$DEV_KEY"
echo "[✓] THIN/WETH Pool successfully seeded with $POOL_ETH ETH!"

# Check if deployer holds FRAC before attempting Pool 2
FRAC_BAL=$(cast call "$FRAC_ADDRESS" "balanceOf(address)(uint256)" $(cast wallet address --private-key "$DEV_KEY") --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
if [ "$FRAC_BAL" != "0" ] && [ $(cast --to-unit "$FRAC_BAL" ether | cut -d. -f1) -ge 1000 ]; then
    echo "[+] Deployer has FRAC balance ($(cast --from-wei "$FRAC_BAL" ether) FRAC). Seeding Pool 2 (THIN/FRAC)..."
    cast send "$FRAC_ADDRESS" "approve(address,uint256)" "$UNISWAP_V2_ROUTER" "$FRAC_BAL" --rpc-url "$RPC_URL" --private-key "$DEV_KEY"
    cast send "$UNISWAP_V2_ROUTER" \
        "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)" \
        "$THIN_CONTRACT" \
        "$FRAC_ADDRESS" \
        $(cast --to-wei 35000 ether) \
        "$FRAC_BAL" \
        $(cast --to-wei 34000 ether) \
        0 \
        $(cast wallet address --private-key "$DEV_KEY") \
        $(($(date +%s) + 1200)) \
        --rpc-url "$RPC_URL" \
        --private-key "$DEV_KEY"
    echo "[✓] THIN/FRAC Pool successfully seeded!"
else
    echo "[i] No FRAC in deployer wallet (or balance < 1000). Skipped THIN/FRAC pool for clean OpSec."
    echo "    (You can swap for FRAC directly on Uniswap from this wallet later if desired)."
fi

echo "[✓] Liquidity initialization complete!"
