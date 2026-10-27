#!/usr/bin/env bash
# Launches THIN + FRAC Zero-Idle Cooldown Switch-Miner
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.foundry/bin:$PATH"

if [ ! -t 0 ] || [ ! -t 1 ]; then
    for term in lxterminal x-terminal-emulator roxterm xterm; do
        if command -v "$term" >/dev/null 2>&1; then
            exec "$term" -T "THIN + FRAC Zero-Idle Dual Switch-Miner" --geometry=96x34 -e "$0" "$@"
        fi
    done
fi

if [ -f "$HOME/.thin_miner_wallet" ]; then
    source "$HOME/.thin_miner_wallet"
elif [ -f "$HOME/.frac_miner_wallet" ]; then
    source "$HOME/.frac_miner_wallet"
fi

RPC_URL="${RPC_URL:-https://mainnet.base.org}"
THIN_CONTRACT="${THIN_CONTRACT:-0x129af9c585f9a8a0438c79644d03e049ed6291b2}"
FRAC_CONTRACT="${FRAC_CONTRACT:-0x8F92de279E8f942Cb4E37F3A207A221CB5566C04}"
CORES="${MINER_CORES:-2}"
MAX_TEMP="${MINER_MAX_TEMP:-72}"
THROTTLE="${MINER_THROTTLE_MS:-25}"

if [ -z "$MINER_PRIVATE_KEY" ] && [ -n "$THIN_PRIVATE_KEY" ]; then
    MINER_PRIVATE_KEY="$THIN_PRIVATE_KEY"
fi

if [ -z "$MINER_PRIVATE_KEY" ]; then
    echo "=================================================================="
    echo "  🚀 THIN + FRAC ZERO-IDLE DUAL SWITCH-MINER"
    echo "=================================================================="
    read -p "Enter Miner Private Key (0x...): " MINER_PRIVATE_KEY
fi

if [ "$THIN_CONTRACT" = "0x0000000000000000000000000000000000000000" ]; then
    read -p "Enter ThinPoWToken Contract Address (0x...): " THIN_CONTRACT
fi

python3 -u "$DIR/dual_switch_miner.py" \
    --rpc-url "$RPC_URL" \
    --thin-contract "$THIN_CONTRACT" \
    --frac-contract "$FRAC_CONTRACT" \
    --private-key "$MINER_PRIVATE_KEY" \
    --cores "$CORES" \
    --max-temp "$MAX_TEMP" \
    --throttle-ms "$THROTTLE"
