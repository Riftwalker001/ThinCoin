#!/usr/bin/env bash
# Deploy Thin Coin ecosystem to Base Mainnet
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

export PATH="$HOME/.foundry/bin:$PATH"

if [ -f "$DIR/.deployer_wallet" ]; then
    source "$DIR/.deployer_wallet"
elif [ -f "$HOME/.thin_miner_wallet" ]; then
    source "$HOME/.thin_miner_wallet"
fi

RPC_URL="https://mainnet.base.org"

if [ -z "$PRIVATE_KEY" ]; then
    read -p "Enter Deployer Private Key: " PRIVATE_KEY
fi

export PRIVATE_KEY

echo "=================================================="
echo "  BROADCASTING THIN COIN TO BASE MAINNET"
echo "=================================================="
forge script script/DeployThinCoin.s.sol:DeployThinCoin \
    --rpc-url "$RPC_URL" \
    --broadcast \
    -vvvv

if [ -f "broadcast/DeployThinCoin.s.sol/8453/run-latest.json" ]; then
    python3 - << 'PYEOF'
import json, sys

with open("broadcast/DeployThinCoin.s.sol/8453/run-latest.json") as f:
    data = json.load(f)

thin_token = None
staking_locker = None
lp_locker = None

for tx in data.get("transactions", []):
    name = tx.get("contractName")
    addr = tx.get("contractAddress")
    if name == "ThinPoWToken":
        thin_token = addr
    elif name == "ThinStakingLocker":
        staking_locker = addr
    elif name == "ThinLPLocker":
        lp_locker = addr

print("\n==================================================")
print("  ✓ DEPLOYMENT ADDRESSES RECORDED")
print("==================================================")
print(f"  ThinPoWToken:       {thin_token}")
print(f"  ThinStakingLocker:  {staking_locker}")
print(f"  ThinLPLocker:       {lp_locker}")
print("==================================================")

with open(".deployer_wallet", "a") as f:
    if thin_token:
        f.write(f'export THIN_CONTRACT="{thin_token}"\n')
    if staking_locker:
        f.write(f'export STAKING_LOCKER="{staking_locker}"\n')
    if lp_locker:
        f.write(f'export LP_LOCKER="{lp_locker}"\n')
PYEOF
fi
