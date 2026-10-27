#!/usr/bin/env python3
"""
ThinPoWToken (THIN) — High-Efficiency Multi-Core CPU Miner & Wallet Manager (Base Mainnet)
Features:
  - Native C Multi-Core Acceleration (1, 2, 3, or 4 Cores) via libthinminer.so
  - Active Thermal Guarding & Overheating Protection (Dynamic SoC Throttle & Pause)
  - Sequential-64 Keccak-256 PoW (Serial dependency algorithm)
  - --auto-stake (calls mineAndStake(uint256) to auto-compound rewards into Loyalty Pool)
  - Thin Golden Block detection (1-in-64 Jackpot Pot indicator)
  - Automatic cooldown window sleep & Single-Instance Process Lock
  - 4-second stale challenge watchdog & clean zero-memset protection
"""

import argparse
import ctypes
import json
import os
import subprocess
import sys
import time
from typing import Dict, Optional

# ---------------------------------------------------------------------------
# Thermal Monitoring & Safety Caps
# ---------------------------------------------------------------------------

def get_cpu_temperature() -> Optional[float]:
    """Reads SoC temperature from Linux sysfs or Raspberry Pi vcgencmd."""
    try:
        with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
            return float(f.read().strip()) / 1000.0
    except Exception:
        pass

    try:
        res = subprocess.run(
            ["vcgencmd", "measure_temp"],
            capture_output=True,
            text=True,
            timeout=1,
        )
        if res.returncode == 0 and "temp=" in res.stdout:
            raw = res.stdout.strip().replace("temp=", "").replace("'C", "")
            return float(raw)
    except Exception:
        pass

    return None


def format_temp_status(temp: Optional[float]) -> str:
    """Formats CPU temperature with terminal color-coding."""
    if temp is None:
        return "\033[90mN/A\033[0m"
    if temp < 68.0:
        return f"\033[92m{temp:.1f}°C (Cool / Optimal)\033[0m"
    elif temp < 75.0:
        return f"\033[93m{temp:.1f}°C (Warm)\033[0m"
    else:
        return f"\033[91m{temp:.1f}°C (Hot / High Thermal Load)\033[0m"


# ---------------------------------------------------------------------------
# Single-Instance Lock
# ---------------------------------------------------------------------------

_LOCK_FILE_HANDLE = None

def acquire_instance_lock(miner_addr: str) -> None:
    """Ensures only ONE miner instance runs at a time to prevent overheating and nonce duplication."""
    global _LOCK_FILE_HANDLE
    lock_path = os.path.expanduser("~/.thin_miner.lock")
    try:
        import fcntl
        _LOCK_FILE_HANDLE = open(lock_path, "w")
        fcntl.flock(_LOCK_FILE_HANDLE, fcntl.LOCK_EX | fcntl.LOCK_NB)
        _LOCK_FILE_HANDLE.write(f"PID: {os.getpid()}\nMiner: {miner_addr}\nStarted: {time.ctime()}\n")
        _LOCK_FILE_HANDLE.flush()
    except (BlockingIOError, IOError):
        print("\n\033[91m[!] ERROR: Another THIN miner instance is already running on this machine!\033[0m")
        print("    Running multiple instances simultaneously will overheat the CPU and cause nonce race collisions.")
        print(f"    Check lock file: {lock_path} or terminate existing process: pkill -f 'miner.py.*thin'\n")
        sys.exit(1)


# ---------------------------------------------------------------------------
# Native Multi-Core C Engine Loader
# ---------------------------------------------------------------------------

_NATIVE_ENGINE = None

def get_native_engine():
    """Loads native C engine (libthinminer.so) from engine/ directory."""
    global _NATIVE_ENGINE
    if _NATIVE_ENGINE is not None:
        return _NATIVE_ENGINE

    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    so_path = os.path.join(project_dir, "engine", "libthinminer.so")
    c_path = os.path.join(project_dir, "engine", "thin_engine.c")

    if not os.path.exists(so_path) and os.path.exists(c_path):
        try:
            print("  [⚙] Compiling native multi-core C engine (libthinminer.so)...", flush=True)
            cmd = ["gcc", "-O3", "-shared", "-fPIC", "-pthread", c_path, "-o", so_path]
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                print("  [✓] Native C accelerator successfully compiled!", flush=True)
            else:
                print(f"  [!] Compilation warning: {res.stderr.strip()}", flush=True)
        except Exception as e:
            print(f"  [!] Note: GCC error ({e}).")

    if os.path.exists(so_path):
        try:
            lib = ctypes.CDLL(so_path)
            lib.thin_mine_batch.argtypes = [
                ctypes.c_char_p,                 # challenge (32 bytes)
                ctypes.c_char_p,                 # miner (20 bytes)
                ctypes.c_char_p,                 # target (32 bytes)
                ctypes.c_uint64,                 # start_nonce
                ctypes.c_uint64,                 # count
                ctypes.c_int,                    # num_threads (1-4)
                ctypes.POINTER(ctypes.c_uint64), # found_nonce
                ctypes.c_char_p,                 # out_digest (32 bytes)
            ]
            lib.thin_mine_batch.restype = ctypes.c_int
            _NATIVE_ENGINE = lib
            return _NATIVE_ENGINE
        except Exception as e:
            print(f"  [!] Failed to load native library {so_path}: {e}")

    return None


# ---------------------------------------------------------------------------
# On-Chain Utilities & Cast Wrappers
# ---------------------------------------------------------------------------

def cast_call(rpc_url: str, contract: str, sig: str, *args: str) -> str:
    env = os.environ.copy()
    env["PATH"] = f"{os.path.expanduser('~/.foundry/bin')}:{env.get('PATH', '')}"
    cmd = ["cast", "call", "--rpc-url", rpc_url, contract, sig, *args]
    res = subprocess.run(cmd, capture_output=True, text=True, env=env, check=True)
    return res.stdout.strip().split()[0]


def cast_send(rpc_url: str, private_key: str, contract: str, sig: str, *args: str) -> str:
    env = os.environ.copy()
    env["PATH"] = f"{os.path.expanduser('~/.foundry/bin')}:{env.get('PATH', '')}"
    cmd = [
        "cast", "send",
        "--rpc-url", rpc_url,
        "--private-key", private_key,
        contract, sig, *args,
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, env=env, check=True)
    return res.stdout.strip()


def get_wallet_address(private_key: str) -> str:
    env = os.environ.copy()
    env["PATH"] = f"{os.path.expanduser('~/.foundry/bin')}:{env.get('PATH', '')}"
    cmd = ["cast", "wallet", "address", "--private-key", private_key]
    res = subprocess.run(cmd, capture_output=True, text=True, env=env, check=True)
    return res.stdout.strip()


def get_account_balances(rpc_url: str, contract: str, miner_addr: str) -> dict:
    env = os.environ.copy()
    env["PATH"] = f"{os.path.expanduser('~/.foundry/bin')}:{env.get('PATH', '')}"

    eth_wei = 0
    try:
        cmd = ["cast", "balance", "--rpc-url", rpc_url, miner_addr]
        res = subprocess.run(cmd, capture_output=True, text=True, env=env)
        if res.returncode == 0:
            eth_wei = int(res.stdout.strip().split()[0])
    except Exception:
        pass

    thin_wei = 0
    try:
        raw = cast_call(rpc_url, contract, "balanceOf(address)(uint256)", miner_addr)
        thin_wei = int(raw, 0)
    except Exception:
        pass

    staked_wei = 0
    try:
        raw = cast_call(rpc_url, contract, "stakedBalance(address)(uint256)", miner_addr)
        staked_wei = int(raw, 0)
    except Exception:
        pass

    pending_wei = 0
    try:
        raw = cast_call(rpc_url, contract, "pendingRewards(address)(uint256)", miner_addr)
        pending_wei = int(raw, 0)
    except Exception:
        pass

    return {
        "eth_balance": eth_wei / 1e18,
        "liquid_thin": thin_wei / 1e18,
        "staked_thin": staked_wei / 1e18,
        "pending_thin": pending_wei / 1e18,
    }


def print_wallet_status(rpc_url: str, contract: str, miner_addr: str) -> Dict[str, float]:
    b = get_account_balances(rpc_url, contract, miner_addr)
    temp = get_cpu_temperature()
    print("\033[96m" + "-" * 68 + "\033[0m")
    print(f"  Wallet Address   : {miner_addr}")
    print(f"  Base ETH Balance : {b['eth_balance']:.6f} ETH (Gas)")
    print(f"  Liquid THIN      : {b['liquid_thin']:,.2f} THIN")
    print(f"  Staked THIN      : {b['staked_thin']:,.2f} THIN (Earning 3.5% block yield)")
    print(f"  Pending Yield    : {b['pending_thin']:,.4f} THIN")
    print(f"  CPU Temperature  : {format_temp_status(temp)}")
    print("\033[96m" + "-" * 68 + "\033[0m\n")
    return b


def do_claim_rewards(rpc_url: str, contract: str, private_key: str) -> None:
    miner_addr = get_wallet_address(private_key)
    b = get_account_balances(rpc_url, contract, miner_addr)
    if b["pending_thin"] <= 0:
        print(f"  [!] No pending yield to harvest for {miner_addr}.")
        return
    print(f"  [+] Claiming {b['pending_thin']:,.4f} THIN in rewards to {miner_addr}...")
    tx_hash = cast_send(rpc_url, private_key, contract, "claimRewards()")
    print(f"  [✓] Rewards claimed successfully! Tx: {tx_hash[:18]}...\n")
    print_wallet_status(rpc_url, contract, miner_addr)


def do_stake(rpc_url: str, contract: str, private_key: str, amount_thin: float = 0.0) -> None:
    miner_addr = get_wallet_address(private_key)
    b = get_account_balances(rpc_url, contract, miner_addr)
    if b["liquid_thin"] <= 0:
        print(f"  [!] Error: No liquid THIN available in {miner_addr} to stake.")
        return
    target_amount = b["liquid_thin"] if amount_thin <= 0 or amount_thin >= b["liquid_thin"] else amount_thin
    amt_wei = str(int(target_amount * 1e18))
    print(f"  [+] Staking {target_amount:,.2f} THIN from {miner_addr} into Loyalty Pool...")
    tx_hash = cast_send(rpc_url, private_key, contract, "stake(uint256)", amt_wei)
    print(f"  [✓] Staked successfully! Tx: {tx_hash[:18]}...\n")
    print_wallet_status(rpc_url, contract, miner_addr)


def do_unstake(rpc_url: str, contract: str, private_key: str, amount_thin: float = 0.0) -> None:
    miner_addr = get_wallet_address(private_key)
    b = get_account_balances(rpc_url, contract, miner_addr)
    if b["staked_thin"] <= 0:
        print(f"  [!] No staked THIN found for {miner_addr}.")
        return
    target_amount = b["staked_thin"] if amount_thin <= 0 or amount_thin >= b["staked_thin"] else amount_thin
    amt_wei = str(int(target_amount * 1e18))
    print(f"  [+] Unstaking {target_amount:,.2f} THIN back to liquid wallet {miner_addr}...")
    tx_hash = cast_send(rpc_url, private_key, contract, "unstake(uint256)", amt_wei)
    print(f"  [✓] Unstaked successfully! Tx: {tx_hash[:18]}...\n")
    print_wallet_status(rpc_url, contract, miner_addr)


def do_withdraw_to(rpc_url: str, contract: str, private_key: str, recipient: str, amount_thin: float = 0.0) -> None:
    miner_addr = get_wallet_address(private_key)
    if not recipient.startswith("0x") or len(recipient) != 42:
        print(f"  [!] Error: Invalid recipient address '{recipient}'. Must be 42-char 0x... address.")
        return
    b = get_account_balances(rpc_url, contract, miner_addr)
    if b["liquid_thin"] <= 0:
        print(f"  [!] Error: No liquid THIN available in {miner_addr} to send.")
        return
    target_amount = b["liquid_thin"] if amount_thin <= 0 or amount_thin >= b["liquid_thin"] else amount_thin
    amt_wei = str(int(target_amount * 1e18))
    print(f"  [+] Sending {target_amount:,.2f} THIN from {miner_addr} -> {recipient}...")
    tx_hash = cast_send(rpc_url, private_key, contract, "transfer(address,uint256)", recipient, amt_wei)
    print(f"  [✓] Transferred successfully! Tx: {tx_hash[:18]}...\n")
    print_wallet_status(rpc_url, contract, miner_addr)


# ---------------------------------------------------------------------------
# Core Mining Engine Loop
# ---------------------------------------------------------------------------

def mine_loop(
    rpc_url: str,
    contract: str,
    private_key: str,
    max_epochs: int = 0,
    auto_stake: bool = True,
    cores: int = 2,
    max_temp: float = 72.0,
    throttle_ms: float = 25.0,
) -> None:
    miner_addr = get_wallet_address(private_key)
    acquire_instance_lock(miner_addr)
    native_engine = get_native_engine()

    engine_desc = f"Native C Accelerator ({cores} Cores)" if native_engine else "Pure Python (Slow Fallback)"
    mode_desc = "\033[96mAuto-Stake to Loyalty Pool (mineAndStake)\033[0m" if auto_stake else "\033[93mDirect Liquid Wallet (mine)\033[0m"

    print("\n" + "=" * 70)
    print("  🚀 THIN COIN (THIN) — MULTI-CORE CPU MINER (BASE MAINNET)")
    print("=" * 70)
    print(f"  Contract:         {contract}")
    print(f"  Miner Address:    {miner_addr}")
    print(f"  Consensus Engine: {engine_desc}")
    print(f"  Mining Strategy:  {mode_desc}")
    print(f"  Thermal Cap:      {max_temp:.1f}°C (Throttle: {throttle_ms:.0f}ms)")
    print(f"  Current SoC Temp: {format_temp_status(get_cpu_temperature())}")
    print("=" * 70 + "\n")

    miner_bytes20 = bytes.fromhex(miner_addr.lower().replace("0x", ""))
    epochs_completed = 0
    fn_sig = "mineAndStake(uint256)" if auto_stake else "mine(uint256)"
    batch_size = 20_000 * cores

    while True:
        if max_epochs > 0 and epochs_completed >= max_epochs:
            print(f"[✓] Reached targeted epoch limit ({max_epochs}). Mining finished.")
            break

        try:
            challenge_hex = cast_call(rpc_url, contract, "challengeNumber()(bytes32)")
            target_hex = cast_call(rpc_url, contract, "effectiveTarget()(uint256)")
            epoch_raw = cast_call(rpc_url, contract, "epochCount()(uint256)")
            last_miner_raw = cast_call(rpc_url, contract, "lastMiner()(address)")
            last_epoch_raw = cast_call(rpc_url, contract, "lastEpochTime()(uint256)")
            jackpot_raw = cast_call(rpc_url, contract, "jackpotPot()(uint256)")
        except Exception as e:
            print(f"[!] Network error fetching on-chain state: {e}. Retrying in 5s...")
            time.sleep(5)
            continue

        challenge_bytes = bytes.fromhex(challenge_hex.lower().replace("0x", ""))
        target_int = int(target_hex, 0)
        target_bytes = target_int.to_bytes(32, "big")
        epoch_int = int(epoch_raw, 0)
        last_miner_str = last_miner_raw.strip().lower()
        last_epoch_time = int(last_epoch_raw, 0)
        jackpot_wei = int(jackpot_raw, 0)

        # -------------------------------------------------------------------
        # Fairness Cooldown Check (300s window)
        # -------------------------------------------------------------------
        if last_miner_str == miner_addr.lower() and epoch_int > 0:
            now_ts = int(time.time())
            cooldown_end = last_epoch_time + 300
            if now_ts < cooldown_end:
                remaining = cooldown_end - now_ts
                print(
                    f"\n  [⏳] Cooldown active for {remaining}s (Old-PC fairness window). "
                    f"Waiting for timer or next miner...",
                    flush=True,
                )
                while now_ts < cooldown_end:
                    time.sleep(5)
                    try:
                        fresh_miner = cast_call(rpc_url, contract, "lastMiner()(address)").strip().lower()
                        if fresh_miner != miner_addr.lower():
                            print("  [✓] Subsequent epoch solved by another miner; cooldown cleared early!", flush=True)
                            break
                    except Exception:
                        pass
                    now_ts = int(time.time())
                continue

        # -------------------------------------------------------------------
        # Epoch Hash Search
        # -------------------------------------------------------------------
        temp_now = get_cpu_temperature()
        print(
            f"[Epoch #{epoch_int + 1}] Challenge: {challenge_hex[:18]}... | "
            f"Pot: {jackpot_wei / 1e18:,.2f} THIN | Temp: {format_temp_status(temp_now)}",
            flush=True,
        )

        nonce = 0
        t0 = time.time()
        found_solution = False
        winning_nonce = 0
        winning_digest = b""

        c_found_nonce = ctypes.c_uint64(0)
        c_out_digest = ctypes.create_string_buffer(32)
        last_rollover_check = time.time()

        while not found_solution:
            if native_engine:
                res = native_engine.thin_mine_batch(
                    challenge_bytes,
                    miner_bytes20,
                    target_bytes,
                    nonce,
                    batch_size,
                    cores,
                    ctypes.byref(c_found_nonce),
                    c_out_digest,
                )
                if res == 1:
                    found_solution = True
                    winning_nonce = c_found_nonce.value
                    winning_digest = bytes(c_out_digest)
                    break
                nonce += batch_size

            # Active Thermal Guard
            curr_temp = get_cpu_temperature()
            if curr_temp is not None and curr_temp >= max_temp:
                print(f"  \033[91m[🔥 Thermal Guard: {curr_temp:.1f}°C >= {max_temp:.1f}°C]\033[0m Cooling pause active...", flush=True)
                cooldown_target = max_temp - 4.0
                while True:
                    time.sleep(2.0)
                    t = get_cpu_temperature()
                    if t is None or t <= cooldown_target:
                        print(f"  \033[92m[❄️ Cooled to {t if t else 'OK':.1f}°C]\033[0m Resuming mining...", flush=True)
                        break

            if throttle_ms > 0:
                time.sleep(throttle_ms / 1000.0)

            # 4-second challenge change check
            now = time.time()
            if now - last_rollover_check >= 4.0:
                last_rollover_check = now
                try:
                    latest_challenge = cast_call(rpc_url, contract, "challengeNumber()(bytes32)")
                    if latest_challenge.lower() != challenge_hex.lower():
                        print("  [!] Another miner solved this epoch. Switching to new challenge...", flush=True)
                        break
                except Exception:
                    pass

        if found_solution:
            elapsed = max(time.time() - t0, 0.001)
            attempts = winning_nonce + 1
            rate = attempts / elapsed
            is_golden = (winning_digest[-1] & 0x3F) == 0x3F
            golden_tag = " \033[93m*** THIN GOLDEN BLOCK HIT! (JACKPOT WON!) ***\033[0m" if is_golden else ""

            print(
                f"  [+] Valid PoW found! Nonce={winning_nonce} | Attempts={attempts} "
                f"({elapsed:.2f}s, {rate:.0f} seq-chains/s){golden_tag}",
                flush=True,
            )

            print(f"  [+] Submitting transaction {fn_sig} with nonce={winning_nonce}...", flush=True)
            try:
                tx_out = cast_send(rpc_url, private_key, contract, fn_sig, str(winning_nonce))
                tx_hash = tx_out.split()[0] if tx_out else "confirmed"
                print(f"  [✓] Solution accepted on-chain! Tx: {tx_hash[:18]}...", flush=True)
                time.sleep(2)

                b = get_account_balances(rpc_url, contract, miner_addr)
                print(
                    f"  [*] Epoch #{epoch_int + 1} Mined! Wallet: {b['liquid_thin']:,.2f} THIN | "
                    f"Staked: {b['staked_thin']:,.2f} THIN | Pending: {b['pending_thin']:,.4f} THIN\n",
                    flush=True,
                )
                epochs_completed += 1

                # Record solved epoch to web/blocks.json for the 2D visual blockchain
                try:
                    blocks_file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "web", "blocks.json")
                    blocks_data = []
                    if os.path.exists(blocks_file):
                        with open(blocks_file, "r") as bf:
                            blocks_data = json.load(bf)
                    blocks_data.append({
                        "epoch": epoch_int + 1,
                        "miner": miner_addr,
                        "reward": "47.05 THIN",
                        "golden": (winning_nonce & 0x3F == 0),
                        "nonce": winning_nonce,
                        "time": "Just now",
                        "hash": tx_hash[:18]
                    })
                    with open(blocks_file, "w") as bf:
                        json.dump(blocks_data, bf, indent=2)
                except Exception:
                    pass
            except Exception as e:
                print(f"  [!] Mining transaction failed: {e}")
                time.sleep(3)


# ---------------------------------------------------------------------------
# CLI Entrypoint
# ---------------------------------------------------------------------------

def resolve_private_key(cli_key: str = "") -> str:
    if cli_key:
        return cli_key
    if os.getenv("THIN_PRIVATE_KEY"):
        return os.getenv("THIN_PRIVATE_KEY")
    user_wallet = os.path.expanduser("~/.thin_miner_wallet")
    if os.path.exists(user_wallet):
        with open(user_wallet) as f:
            for line in f:
                if line.startswith("export MINER_PRIVATE_KEY=") or line.startswith("export PRIVATE_KEY="):
                    return line.split("=", 1)[1].strip().strip('"')
    deployer_wallet = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "contracts", ".deployer_wallet")
    if os.path.exists(deployer_wallet):
        with open(deployer_wallet) as f:
            for line in f:
                if line.startswith("export PRIVATE_KEY="):
                    return line.split("=", 1)[1].strip().strip('"')
    return ""


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ThinPoWToken (THIN) Multi-Core CPU Miner & Wallet Manager")
    parser.add_argument("--rpc-url", default="https://mainnet.base.org", help="Base Mainnet JSON-RPC URL")
    parser.add_argument("--contract", default="0x129af9c585f9a8a0438c79644d03e049ed6291b2", help="ThinPoWToken contract address on Base")
    parser.add_argument("--private-key", default="", help="Miner private key")
    parser.add_argument("--epochs", type=int, default=0, help="Epochs to mine (0 = infinite 24/7)")
    parser.add_argument("--cores", "-c", type=int, default=2, choices=[1, 2, 3, 4], help="CPU cores (default: 2)")
    parser.add_argument("--max-temp", type=float, default=72.0, help="SoC max temp cap in °C (default: 72.0)")
    parser.add_argument("--throttle-ms", type=float, default=25.0, help="Throttle pause in ms (default: 25.0)")
    parser.add_argument("--auto-stake", action="store_true", default=True, help="Auto-stake mining rewards")
    parser.add_argument("--no-auto-stake", action="store_false", dest="auto_stake", help="Liquid wallet payouts")
    parser.add_argument("--stake", nargs="?", const="all", default=None, help="Stake liquid THIN into loyalty pool (amount or 'all')")
    parser.add_argument("--unstake", nargs="?", const="all", default=None, help="Unstake THIN from loyalty pool (amount or 'all')")
    parser.add_argument("--claim-rewards", action="store_true", help="Claim pending staking rewards")
    parser.add_argument("--withdraw-to", type=str, default=None, help="Transfer liquid THIN to address")
    parser.add_argument("--amount", type=str, default="all", help="Amount for stake/unstake/withdraw")
    parser.add_argument("--status", action="store_true", help="Print wallet balances and exit")

    args = parser.parse_args()

    args.private_key = resolve_private_key(args.private_key)
    if not args.private_key:
        print("[!] No private key found.")
        print("    Options to mine:")
        print("    1. Pass your key:  python3 miner.py --private-key 0x...")
        print("    2. Set env var:    export THIN_PRIVATE_KEY=0x...")
        print("    3. Or run the 1-line auto-installer which sets up a wallet for you:")
        print("       curl -sSL https://raw.githubusercontent.com/ThinPoWCoin/thin-coin/main/web/install.sh | bash")
        sys.exit(1)

    if args.status:
        addr = get_wallet_address(args.private_key)
        print_wallet_status(args.rpc_url, args.contract, addr)
        sys.exit(0)

    if args.claim_rewards:
        do_claim_rewards(args.rpc_url, args.contract, args.private_key)
        sys.exit(0)

    if args.stake is not None:
        amt_str = args.amount if args.stake == "all" and args.amount != "all" else args.stake
        amt = 0.0 if amt_str == "all" else float(amt_str)
        do_stake(args.rpc_url, args.contract, args.private_key, amt)
        sys.exit(0)

    if args.unstake is not None:
        amt_str = args.amount if args.unstake == "all" and args.amount != "all" else args.unstake
        amt = 0.0 if amt_str == "all" else float(amt_str)
        do_unstake(args.rpc_url, args.contract, args.private_key, amt)
        sys.exit(0)

    if args.withdraw_to:
        amt = 0.0 if args.amount == "all" else float(args.amount)
        do_withdraw_to(args.rpc_url, args.contract, args.private_key, args.withdraw_to, amt)
        sys.exit(0)

    mine_loop(
        args.rpc_url,
        args.contract,
        args.private_key,
        max_epochs=args.epochs,
        auto_stake=args.auto_stake,
        cores=args.cores,
        max_temp=args.max_temp,
        throttle_ms=args.throttle_ms,
    )
