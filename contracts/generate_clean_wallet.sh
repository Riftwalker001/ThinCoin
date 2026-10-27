#!/usr/bin/env bash
# Generate a pristine, unlinked EVM deployer wallet for Thin Coin
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.foundry/bin:$PATH"

echo "=================================================================="
echo "  🔒 GENERATING CLEAN, UNLINKED DEPLOYER WALLET"
echo "=================================================================="
echo "  This wallet has ZERO on-chain connection to any past projects."
echo "=================================================================="

WALLET_OUTPUT=$(cast wallet new 2>&1)
PRIV_KEY=$(echo "$WALLET_OUTPUT" | grep -i "Private key" | awk '{print $3}')
PUB_ADDR=$(echo "$WALLET_OUTPUT" | grep -i "Address" | awk '{print $2}')

cat <<EOF > "$DIR/.deployer_wallet"
export PRIVATE_KEY="$PRIV_KEY"
export PUBLIC_ADDRESS="$PUB_ADDR"
EOF
chmod 600 "$DIR/.deployer_wallet"

echo ""
echo "  NEW UNLINKED ADDRESS:  $PUB_ADDR"
echo "  PRIVATE KEY:          $PRIV_KEY"
echo ""
echo "  Saved securely to:     $DIR/.deployer_wallet"
echo ""
echo "  To deploy Thin Coin with complete anonymity:"
echo "  1. Fund $PUB_ADDR with ~0.04 to 0.05 Base ETH (for initial pool & gas)."
echo "  2. Run: ./contracts/deploy_mainnet.sh"
echo "──────────────────────────────────────────────────────────────────"
