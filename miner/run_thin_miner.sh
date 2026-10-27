#!/usr/bin/env bash
# Thin Coin (THIN) Multi-Core CPU Miner & Interactive Control Panel (Base Mainnet)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

export PATH="$HOME/.foundry/bin:$PATH"

# Self-spawn in terminal emulator if started from Desktop icon
if [ ! -t 0 ] || [ ! -t 1 ]; then
    for term in lxterminal x-terminal-emulator roxterm xterm; do
        if command -v "$term" >/dev/null 2>&1; then
            exec "$term" -T "THIN Multi-Core CPU Miner (Base Mainnet)" --geometry=96x34 -e "$0" "$@"
        fi
    done
fi

if [ -f "$HOME/.thin_miner_wallet" ]; then
    source "$HOME/.thin_miner_wallet"
elif [ -f "$DIR/../contracts/.deployer_wallet" ]; then
    source "$DIR/../contracts/.deployer_wallet"
    MINER_PRIVATE_KEY="${MINER_PRIVATE_KEY:-$PRIVATE_KEY}"
    MINER_ADDRESS="${MINER_ADDRESS:-$PUBLIC_ADDRESS}"
fi

CONTRACT="${THIN_CONTRACT:-0x129af9c585f9a8a0438c79644d03e049ed6291b2}"
RPC_URL="${THIN_RPC_URL:-https://mainnet.base.org}"
MINER_ADDR="${MINER_ADDRESS:-0x617418435ba8782FEaa3756d0c853eCd1a7713F1}"

# Hardware & Thermal defaults
CORES="${MINER_CORES:-2}"
MAX_TEMP="${MINER_MAX_TEMP:-72}"
THROTTLE_MS="${MINER_THROTTLE_MS:-25}"
AUTO_STAKE="${MINER_AUTO_STAKE:-1}"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RED='\033[1;31m'
PURPLE='\033[1;35m'
BOLD='\033[1m'
NC='\033[0m'

get_status() {
    MINER_PID=$(pgrep -f "miner.py.*$CONTRACT" 2>/dev/null || true)
    DASH_PID=$(pgrep -f "dashboard.py.*$CONTRACT" 2>/dev/null || true)
}

show_panel() {
    clear
    echo -e "${CYAN}==========================================================================${NC}"
    echo -e "${CYAN}  🚀 THIN COIN (THIN) — INTERACTIVE CPU MINER & STAKING CONTROL PANEL    ${NC}"
    echo -e "${CYAN}==========================================================================${NC}"
    echo -e "  Consensus Engine:  Sequential-64 Keccak CPU PoW (Base Mainnet ID 8453)"
    echo -e "  Token Contract:    ${BOLD}${CONTRACT}${NC}"
    echo -e "  Active Miner Key:  ${MINER_ADDR}"

    python3 "$DIR/miner.py" --rpc-url "$RPC_URL" --contract "$CONTRACT" --private-key "$MINER_PRIVATE_KEY" --status 2>/dev/null || true
    get_status

    echo -ne "  ${BOLD}24/7 Background CPU Miner:${NC} "
    if [ -n "$MINER_PID" ]; then
        echo -e "${GREEN}● RUNNING${NC} (PID: $MINER_PID)"
    else
        echo -e "${RED}○ STOPPED${NC}"
    fi
    echo -ne "  ${BOLD}Web3 Trader & Miner Hub :${NC} "
    if [ -n "$DASH_PID" ]; then
        echo -e "${GREEN}● RUNNING${NC} (PID: $DASH_PID) -> ${CYAN}http://127.0.0.1:7446/${NC}"
    else
        echo -e "${RED}○ STOPPED${NC}"
    fi

    # Read live SoC temperature
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        RAW_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        CPU_TEMP=$(awk "BEGIN {printf \"%.1f\", $RAW_TEMP/1000}")
        echo -e "  ${BOLD}CPU Hardware Temperature:${NC} ${YELLOW}${CPU_TEMP}°C${NC} (Thermal Guard Limit: ${RED}${MAX_TEMP}°C${NC})"
    fi
    echo -e "  ${BOLD}Active CPU Cores Target :${NC} ${GREEN}${CORES} Core(s)${NC} (Overheat-Safe Mode)"
    if [ "$AUTO_STAKE" -eq 1 ]; then
        echo -e "  ${BOLD}Mining Payout Mode      :${NC} ${YELLOW}● Auto-Stake (Loyalty Pool 3.5% Yield)${NC}"
    else
        echo -e "  ${BOLD}Mining Payout Mode      :${NC} ${GREEN}○ Direct Wallet (Liquid THIN)${NC}"
    fi
    echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
}

while true; do
    show_panel
    echo -e "  ${BOLD}Select an action:${NC}"
    if [ "$AUTO_STAKE" -eq 1 ]; then
        echo -e "  ${GREEN}[1]${NC} ⛏  Mine Continuously in This Window (${CORES} Cores, Auto-Stake ON)"
        echo -e "  ${YELLOW}[2]${NC} ⚡ Mine 1 Single Block Right Now (${CORES} Cores, Auto-Stake ON)"
        echo -e "  ${CYAN}[3]${NC} 🚀 Start 24/7 Background Miner Daemon (${CORES} Cores, Auto-Stake ON)"
        echo -e "  ${YELLOW}[T]${NC} 🔄 Toggle Payout Mode: [Auto-Stake: ${YELLOW}ON${NC} (Pool Yield)]"
    else
        echo -e "  ${GREEN}[1]${NC} ⛏  Mine Continuously in This Window (${CORES} Cores, Liquid THIN)"
        echo -e "  ${YELLOW}[2]${NC} ⚡ Mine 1 Single Block Right Now (${CORES} Cores, Liquid THIN)"
        echo -e "  ${CYAN}[3]${NC} 🚀 Start 24/7 Background Miner Daemon (${CORES} Cores, Liquid THIN)"
        echo -e "  ${GREEN}[T]${NC} 🔄 Toggle Payout Mode: [Auto-Stake: ${GREEN}OFF (Direct Liquid THIN)${NC}]"
    fi
    echo -e "  ${PURPLE}[C]${NC} ⚙  Configure Mining Cores (1, 2, 3, or 4) & Max Temp Cap"
    echo -e "  ${CYAN}[4]${NC} 📜 Watch Background Miner Logs (tail -f miner.log)"
    echo -e "  ${GREEN}[5]${NC} 🌐 Open THIN Web3 Hub in Browser (http://127.0.0.1:7446/)"
    echo -e "  ${RED}[6]${NC} 🛑 Stop Background Miner Daemon"
    echo -e "  ${YELLOW}[7]${NC} 💰 Claim Staking Rewards to Miner Wallet"
    echo -e "  ${GREEN}[8]${NC} 📥 Stake Liquid THIN into Loyalty Pool (Custom Amount or ALL)"
    echo -e "  ${CYAN}[9]${NC} 🔓 Unstake THIN from Staking Pool to Wallet (Custom Amount or ALL)"
    echo -e "  ${PURPLE}[10]${NC} 🚀 Sweep / Transfer Liquid THIN to Address"
    echo -e "  ${BOLD}[0]${NC} ❌ Close Window"
    echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
    read -p "  Enter choice [0-10, C, or T]: " choice

    case "$choice" in
        1)
            [ "$AUTO_STAKE" -eq 1 ] && STAKE_OPT="--auto-stake" || STAKE_OPT="--no-auto-stake"
            echo -e "\n${GREEN}Starting live continuous CPU miner with ${CORES} core(s) (Press Ctrl+C to return to menu)...${NC}\n"
            trap ' ' INT
            python3 -u "$DIR/miner.py" --rpc-url "$RPC_URL" --contract "$CONTRACT" --private-key "$MINER_PRIVATE_KEY" --epochs 0 $STAKE_OPT --cores "$CORES" --max-temp "$MAX_TEMP" --throttle-ms "$THROTTLE_MS"
            trap - INT
            read -p "Press [Enter] to continue..."
            ;;
        2)
            [ "$AUTO_STAKE" -eq 1 ] && STAKE_OPT="--auto-stake" || STAKE_OPT="--no-auto-stake"
            echo -e "\n${YELLOW}Mining 1 Epoch on Base Mainnet with ${CORES} core(s)...${NC}\n"
            python3 -u "$DIR/miner.py" --rpc-url "$RPC_URL" --contract "$CONTRACT" --private-key "$MINER_PRIVATE_KEY" --epochs 1 $STAKE_OPT --cores "$CORES" --max-temp "$MAX_TEMP" --throttle-ms "$THROTTLE_MS"
            read -p "Press [Enter] to continue..."
            ;;
        3)
            get_status
            if [ -z "$MINER_PID" ]; then
                [ "$AUTO_STAKE" -eq 1 ] && STAKE_OPT="--auto-stake" || STAKE_OPT="--no-auto-stake"
                nohup python3 -u "$DIR/miner.py" --rpc-url "$RPC_URL" --contract "$CONTRACT" --private-key "$MINER_PRIVATE_KEY" --epochs 0 $STAKE_OPT --cores "$CORES" --max-temp "$MAX_TEMP" --throttle-ms "$THROTTLE_MS" >> "$DIR/miner.log" 2>&1 < /dev/null &
                echo -e "\n  ${GREEN}✓ Background CPU Miner started using ${CORES} core(s)!${NC}"
            else
                echo -e "\n  ${YELLOW}! Background CPU Miner is already running (PID: $MINER_PID).${NC}"
            fi
            sleep 1.5
            ;;
        [tT])
            if [ "$AUTO_STAKE" -eq 1 ]; then
                AUTO_STAKE=0
                echo -e "\n  ${GREEN}✓ Switched payout mode to DIRECT TO WALLET (Liquid THIN).${NC}"
            else
                AUTO_STAKE=1
                echo -e "\n  ${YELLOW}✓ Switched payout mode to AUTO-STAKE (Loyalty Pool).${NC}"
            fi
            sleep 1.2
            ;;
        [cC])
            echo -e "\n${BOLD}=== Configure Mining Cores & Thermal Guard ===${NC}"
            echo -e "Current Settings: ${CORES} Cores | Max Temp: ${MAX_TEMP}°C | Rest Throttle: ${THROTTLE_MS}ms"
            read -p "Enter number of cores [1, 2, 3, or 4; Recommended: 2]: " new_cores
            if [[ "$new_cores" =~ ^[1-4]$ ]]; then
                CORES="$new_cores"
            fi
            read -p "Enter max SoC temperature cap °C [Press Enter for ${MAX_TEMP}]: " new_temp
            if [[ "$new_temp" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                MAX_TEMP="$new_temp"
            fi
            echo -e "  ${GREEN}✓ Configuration saved: ${CORES} Cores, Max Temp ${MAX_TEMP}°C.${NC}\n"
            sleep 1.2
            ;;
        4)
            echo -e "\n${CYAN}Streaming miner.log (Press Ctrl+C to return to menu)...${NC}\n"
            trap ' ' INT
            tail -n 40 -f "$DIR/miner.log"
            trap - INT
            ;;
        5)
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "http://127.0.0.1:7446/" &
            fi
            sleep 1
            ;;
        6)
            pkill -f "miner.py.*$CONTRACT" 2>/dev/null && rm -f "$HOME/.thin_miner.lock" && echo -e "\n  ${GREEN}✓ Background Miner stopped.${NC}" || echo -e "\n  Miner was not running."
            sleep 1.5
            ;;
        7)
            python3 "$DIR/miner.py" --rpc-url "$RPC_URL" --contract "$CONTRACT" --private-key "$MINER_PRIVATE_KEY" --claim-rewards
            read -p "Press [Enter] to continue..."
            ;;
        8)
            read -p "Enter amount of THIN to stake [Press Enter for ALL]: " stake_amt
            python3 "$DIR/miner.py" --rpc-url "$RPC_URL" --contract "$CONTRACT" --private-key "$MINER_PRIVATE_KEY" --stake "${stake_amt:-all}"
            read -p "Press [Enter] to continue..."
            ;;
        9)
            read -p "Enter amount of THIN to unstake [Press Enter for ALL]: " unstake_amt
            python3 "$DIR/miner.py" --rpc-url "$RPC_URL" --contract "$CONTRACT" --private-key "$MINER_PRIVATE_KEY" --unstake "${unstake_amt:-all}"
            read -p "Press [Enter] to continue..."
            ;;
        10)
            read -p "Enter recipient address (0x...): " rec_addr
            read -p "Enter amount of THIN to send [Press Enter for ALL]: " send_amt
            python3 "$DIR/miner.py" --rpc-url "$RPC_URL" --contract "$CONTRACT" --private-key "$MINER_PRIVATE_KEY" --withdraw-to "$rec_addr" --amount "${send_amt:-all}"
            read -p "Press [Enter] to continue..."
            ;;
        0|q|Q)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid choice."
            sleep 1
            ;;
    esac
done
