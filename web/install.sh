#!/usr/bin/env bash
# Thin Coin (THIN) — 1-Line Universal Community CPU Miner Installer
# Compatible with: Ubuntu, Debian, Raspberry Pi OS, Fedora, Arch, Linux Mint, Termux
set -e

CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${CYAN}==================================================================${NC}"
echo -e "${CYAN}  🚀 THIN COIN (THIN) — ZERO-FRICTION COMMUNITY MINER INSTALLER   ${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo -e "  Consensus: Sequential-64 Keccak CPU Proof-of-Work (Base Mainnet)"
echo -e "  Device:    $(uname -s) $(uname -m) ($(nproc) CPU Cores detected)"
echo -e "${CYAN}──────────────────────────────────────────────────────────────────${NC}\n"

INSTALL_DIR="$HOME/ThinCoinMiner"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 1. Dependency Check
echo -e "[+] Checking dependencies..."
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}[!] python3 is required. Please install python3 first.${NC}"
    exit 1
fi

if ! command -v cast >/dev/null 2>&1; then
    if [ -f "$HOME/.foundry/bin/cast" ]; then
        export PATH="$HOME/.foundry/bin:$PATH"
    else
        echo -e "${YELLOW}[⚙] Foundry (cast) not found. Installing Foundry automatically...${NC}"
        curl -sSL https://foundry.paradigm.xyz | bash
        export PATH="$HOME/.foundry/bin:$PATH"
        foundryup || true
    fi
fi

# 2. Extract or Download Native C Engine & Miner
echo -e "[+] Setting up native C Sequential-64 accelerator..."
cat << 'EOF' > "$INSTALL_DIR/thin_engine.c"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
static const uint64_t RC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808AULL, 0x8000000080008000ULL,
    0x000000000000808BULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008AULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000AULL,
    0x000000008000808BULL, 0x800000000000008BULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800AULL, 0x800000008000000AULL,
    0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};
static const int ROT[5][5] = {
    {0, 36, 3, 41, 18}, {1, 44, 10, 45, 2}, {62, 6, 43, 15, 61},
    {28, 55, 25, 21, 56}, {27, 20, 39, 8, 14}
};
static inline uint64_t rol64(uint64_t val, int shift) { return (val << shift) | (val >> (64 - shift)); }
static inline void keccak_f1600(uint64_t state[25]) {
    for (int r = 0; r < 24; r++) {
        uint64_t c[5];
        for (int x = 0; x < 5; x++) c[x] = state[x] ^ state[x+5] ^ state[x+10] ^ state[x+15] ^ state[x+20];
        uint64_t d[5];
        for (int x = 0; x < 5; x++) d[x] = c[(x+4)%5] ^ rol64(c[(x+1)%5], 1);
        for (int i = 0; i < 25; i++) state[i] ^= d[i%5];
        uint64_t b[25];
        for (int x = 0; x < 5; x++) {
            for (int y = 0; y < 5; y++) b[y + 5 * ((2*x + 3*y)%5)] = rol64(state[x + 5*y], ROT[x][y]);
        }
        for (int y = 0; y < 25; y += 5) {
            for (int x = 0; x < 5; x++) state[y+x] = b[y+x] ^ ((~b[y + (x+1)%5]) & b[y + (x+2)%5]);
        }
        state[0] ^= RC[r];
    }
}
static inline void keccak256_single_block(const uint8_t *in, size_t in_len, uint8_t out[32]) {
    uint64_t state[25] = {0};
    uint8_t block[136] = {0};
    memcpy(block, in, in_len);
    block[in_len] = 0x01;
    block[135] |= 0x80;
    for (int i = 0; i < 17; i++) {
        uint64_t lane = 0;
        memcpy(&lane, &block[i * 8], 8);
        state[i] ^= lane;
    }
    keccak_f1600(state);
    memcpy(out, state, 32);
}
void compute_sequential_digest(const uint8_t challenge[32], const uint8_t miner[20], uint64_t nonce, uint8_t out[32]) {
    uint8_t buf0[84];
    memcpy(buf0, challenge, 32);
    memcpy(buf0 + 32, miner, 20);
    memset(buf0 + 52, 0, 24);
    for (int i = 0; i < 8; i++) buf0[83 - i] = (uint8_t)((nonce >> (i * 8)) & 0xFF);
    uint8_t digest[32];
    keccak256_single_block(buf0, 84, digest);
    uint8_t step_buf[96];
    memcpy(step_buf + 32, challenge, 32);
    memset(step_buf + 64, 0, 32);
    for (int step = 1; step < 64; step++) {
        memcpy(step_buf, digest, 32);
        step_buf[95] = (uint8_t)step;
        step_buf[94] = (uint8_t)(step >> 8);
        keccak256_single_block(step_buf, 96, digest);
    }
    memcpy(out, digest, 32);
}
typedef struct {
    const uint8_t *challenge, *miner, *target;
    uint64_t start_nonce, end_nonce;
    int thread_id, num_threads;
    volatile int *found_flag;
    uint64_t *found_nonce;
    uint8_t *out_digest;
    pthread_mutex_t *found_lock;
} WorkerArgs;
static void* search_worker(void *arg_ptr) {
    WorkerArgs *args = (WorkerArgs*)arg_ptr;
    uint8_t digest[32];
    uint64_t start = args->start_nonce + args->thread_id, step = args->num_threads, end = args->end_nonce;
    for (uint64_t n = start; n < end; n += step) {
        if (*(args->found_flag)) break;
        compute_sequential_digest(args->challenge, args->miner, n, digest);
        if (memcmp(digest, args->target, 32) <= 0) {
            pthread_mutex_lock(args->found_lock);
            if (!*(args->found_flag)) {
                *(args->found_flag) = 1;
                *(args->found_nonce) = n;
                memcpy(args->out_digest, digest, 32);
            }
            pthread_mutex_unlock(args->found_lock);
            break;
        }
    }
    return NULL;
}
int thin_mine_batch(const uint8_t challenge[32], const uint8_t miner[20], const uint8_t target[32],
                    uint64_t start_nonce, uint64_t count, int num_threads,
                    uint64_t *found_nonce, uint8_t out_digest[32]) {
    if (num_threads < 1) num_threads = 1;
    if (num_threads > 16) num_threads = 16;
    volatile int found_flag = 0;
    pthread_mutex_t found_lock = PTHREAD_MUTEX_INITIALIZER;
    pthread_t threads[16];
    WorkerArgs args[16];
    for (int i = 0; i < num_threads; i++) {
        args[i].challenge = challenge; args[i].miner = miner; args[i].target = target;
        args[i].start_nonce = start_nonce; args[i].end_nonce = start_nonce + count;
        args[i].thread_id = i; args[i].num_threads = num_threads;
        args[i].found_flag = &found_flag; args[i].found_nonce = found_nonce;
        args[i].out_digest = out_digest; args[i].found_lock = &found_lock;
        pthread_create(&threads[i], NULL, search_worker, &args[i]);
    }
    for (int i = 0; i < num_threads; i++) pthread_join(threads[i], NULL);
    return found_flag;
}
EOF

if command -v gcc >/dev/null 2>&1; then
    echo -e "[+] Compiling libthinminer.so with -O3 optimizations..."
    gcc -O3 -shared -fPIC -pthread -o "$INSTALL_DIR/libthinminer.so" "$INSTALL_DIR/thin_engine.c"
    echo -e "${GREEN}[✓] Accelerator compiled!${NC}"
fi

# Copy or download standalone python miner
if [ -f "$HOME/Desktop/ThinCoin/miner/miner.py" ]; then
    cp "$HOME/Desktop/ThinCoin/miner/miner.py" "$INSTALL_DIR/miner.py"
else
    echo -e "[+] Fetching official Thin Coin miner orchestrator..."
    curl -sSL "http://127.0.0.1:7446/miner.py" -o "$INSTALL_DIR/miner.py" || true
fi

# 3. Interactive Miner Wallet Setup
WALLET_FILE="$INSTALL_DIR/wallet.env"
if [ ! -f "$WALLET_FILE" ]; then
    echo -e "\n${YELLOW}Choose an option for your Miner Wallet:${NC}"
    echo "  [1] Enter existing private key (MetaMask / dedicated rig)"
    echo "  [2] Auto-generate a brand new miner wallet right now"
    read -p "Select [1 or 2]: " OPTION
    if [ "$OPTION" = "1" ]; then
        read -p "Enter Private Key (0x...): " USER_KEY
    else
        echo -e "[+] Generating fresh on-chain EVM wallet..."
        USER_KEY=$(cast wallet new | grep "Private key" | awk '{print $3}')
        ADDR=$(cast wallet address --private-key "$USER_KEY")
        echo -e "${GREEN}[✓] Created Wallet Address:${NC} $ADDR"
        echo -e "${YELLOW}[!] Backup Private Key:${NC} $USER_KEY"
    fi
    echo "MINER_PRIVATE_KEY=$USER_KEY" > "$WALLET_FILE"
fi

source "$WALLET_FILE"
MINER_ADDR=$(cast wallet address --private-key "$MINER_PRIVATE_KEY")
AVAILABLE_CORES=$(nproc)
RECOMMENDED_CORES=$((AVAILABLE_CORES > 2 ? 2 : AVAILABLE_CORES))

echo -e "\n${CYAN}Configuration Summary:${NC}"
echo -e "  Miner Address:    ${GREEN}$MINER_ADDR${NC}"
echo -e "  CPU Cores:        $RECOMMENDED_CORES of $AVAILABLE_CORES cores"
echo -e "  Network:          Base Mainnet (EVM ID 8453)"
echo -e "  Payout Strategy:  Auto-Stake (mineAndStake 3.5% yield)"

# 4. Create Desktop Shortcut if Desktop directory exists
if [ -d "$HOME/Desktop" ]; then
    cat << EOF > "$HOME/Desktop/Thin_Coin_Miner.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Thin Coin Miner
Comment=Start Mining Thin Coin on Base Mainnet
Exec=lxterminal -T "Thin Coin Multi-Core Miner" -e "bash -c 'cd $INSTALL_DIR && python3 miner.py --contract 0x129af9c585f9a8a0438c79644d03e049ed6291b2 --private-key $MINER_PRIVATE_KEY --cores $RECOMMENDED_CORES --auto-stake'"
Terminal=false
StartupNotify=true
Categories=Utility;Finance;
EOF
    chmod +x "$HOME/Desktop/Thin_Coin_Miner.desktop"
    echo -e "${GREEN}[✓] Desktop launcher created at ~/Desktop/Thin_Coin_Miner.desktop${NC}"
fi

echo -e "\n${GREEN}[✓] Installation complete! Happy mining!${NC}"
