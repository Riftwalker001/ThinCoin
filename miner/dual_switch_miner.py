#!/usr/bin/env python3
"""
Thin Coin & Fractal Coin — High-Efficiency Cooldown Switch-Miner (Base Mainnet)
Features:
  - 100% Zero-Idle CPU Orchestrator:
    * Actively mines THIN. When THIN solves and enters 300s cooldown, instantly switches CPU to FRAC!
    * When FRAC enters cooldown, switches back to THIN!
  - Native Multi-Core C Acceleration for both tokens (Sequential-64 Keccak-256)
  - Auto-Staking enabled on both networks for compound yield
  - Active Thermal Governance (SoC throttle & cooling protection)
"""

import argparse
import ctypes
import json
import os
import subprocess
import sys
import time
from typing import Optional

# ---------------------------------------------------------------------------
# Thermal Monitoring & Safety Caps
# ---------------------------------------------------------------------------

def get_cpu_temperature() -> Optional[float]:
    try:
        with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
            return float(f.read().strip()) / 1000.0
    except Exception:
        pass
    try:
        res = subprocess.run(["vcgencmd", "measure_temp"], capture_output=True, text=True, timeout=1)
        if res.returncode == 0 and "temp=" in res.stdout:
            return float(res.stdout.strip().replace("temp=", "").replace("'C", ""))
    except Exception:
        pass
    return None


def format_temp_status(temp: Optional[float]) -> str:
    if temp is None:
        return "\033[90mN/A\033[0m"
    if temp < 68.0:
        return f"\033[92m{temp:.1f}°C (Optimal)\033[0m"
    elif temp < 75.0:
        return f"\033[93m{temp:.1f}°C (Warm)\033[0m"
    else:
        return f"\033[91m{temp:.1f}°C (High Load)\033[0m"


# ---------------------------------------------------------------------------
# Native C Engine Loader
# ---------------------------------------------------------------------------

_NATIVE_ENGINE = None

def get_native_engine():
    global _NATIVE_ENGINE
    if _NATIVE_ENGINE is not None:
        return _NATIVE_ENGINE

    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    so_path = os.path.join(project_dir, "engine", "libthinminer.so")

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
            print(f"  [!] Failed to load C accelerator: {e}")
    return None


# ---------------------------------------------------------------------------
# Cast RPC Wrappers
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
    cmd = ["cast", "send", "--rpc-url", rpc_url, "--private-key", private_key, contract, sig, *args]
    res = subprocess.run(cmd, capture_output=True, text=True, env=env, check=True)
    return res.stdout.strip()


def get_wallet_address(private_key: str) -> str:
    env = os.environ.copy()
    env["PATH"] = f"{os.path.expanduser('~/.foundry/bin')}:{env.get('PATH', '')}"
    cmd = ["cast", "wallet", "address", "--private-key", private_key]
    res = subprocess.run(cmd, capture_output=True, text=True, env=env, check=True)
    return res.stdout.strip()


# ---------------------------------------------------------------------------
# Cooldown Status Evaluator
# ---------------------------------------------------------------------------

def get_cooldown_remaining(rpc_url: str, contract: str, miner_addr: str) -> int:
    try:
        last_miner = cast_call(rpc_url, contract, "lastMiner()(address)").strip().lower()
        epoch_count = int(cast_call(rpc_url, contract, "epochCount()(uint256)"), 0)
        last_epoch_time = int(cast_call(rpc_url, contract, "lastEpochTime()(uint256)"), 0)

        if epoch_count > 0 and last_miner == miner_addr.lower():
            now = int(time.time())
            cooldown_end = last_epoch_time + 300
            if now < cooldown_end:
                return cooldown_end - now
    except Exception:
        pass
    return 0


# ---------------------------------------------------------------------------
# Mine Single Epoch Core
# ---------------------------------------------------------------------------

def mine_epoch(
    token_name: str,
    rpc_url: str,
    contract: str,
    private_key: str,
    miner_addr: str,
    cores: int,
    max_temp: float,
    throttle_ms: float,
    auto_stake: bool,
    native_engine
) -> bool:
    try:
        challenge_hex = cast_call(rpc_url, contract, "challengeNumber()(bytes32)")
        target_hex = cast_call(rpc_url, contract, "effectiveTarget()(uint256)")
        epoch_int = int(cast_call(rpc_url, contract, "epochCount()(uint256)"), 0)
    except Exception as e:
        print(f"  [!] Failed fetching {token_name} state: {e}")
        return False

    challenge_bytes = bytes.fromhex(challenge_hex.lower().replace("0x", ""))
    target_int = int(target_hex, 0)
    target_bytes = target_int.to_bytes(32, "big")
    miner_bytes20 = bytes.fromhex(miner_addr.lower().replace("0x", ""))

    print(f"\n  ⛏️  [\033[96m{token_name}\033[0m] Mining Epoch #{epoch_int + 1} | Temp: {format_temp_status(get_cpu_temperature())}", flush=True)

    nonce = 0
    batch_size = 20_000 * cores
    t0 = time.time()
    found_solution = False
    winning_nonce = 0
    winning_digest = b""

    c_found_nonce = ctypes.c_uint64(0)
    c_out_digest = ctypes.create_string_buffer(32)
    last_rollover = time.time()

    while not found_solution:
        if native_engine:
            res = native_engine.thin_mine_batch(
                challenge_bytes, miner_bytes20, target_bytes,
                nonce, batch_size, cores, ctypes.byref(c_found_nonce), c_out_digest
            )
            if res == 1:
                found_solution = True
                winning_nonce = c_found_nonce.value
                winning_digest = bytes(c_out_digest)
                break
            nonce += batch_size

        # Thermal Governor
        curr_temp = get_cpu_temperature()
        if curr_temp is not None and curr_temp >= max_temp:
            print(f"  \033[91m[🔥 Thermal Limit: {curr_temp:.1f}°C]\033[0m Cooling...", flush=True)
            time.sleep(3.0)

        if throttle_ms > 0:
            time.sleep(throttle_ms / 1000.0)

        # 4s Watchdog Check
        now = time.time()
        if now - last_rollover >= 4.0:
            last_rollover = now
            try:
                latest = cast_call(rpc_url, contract, "challengeNumber()(bytes32)")
                if latest.lower() != challenge_hex.lower():
                    print(f"  [!] Another miner solved {token_name} Epoch #{epoch_int + 1}. Switching...", flush=True)
                    return False
            except Exception:
                pass

    if found_solution:
        elapsed = max(time.time() - t0, 0.001)
        rate = (winning_nonce + 1) / elapsed
        is_golden = (winning_digest[-1] & 0x3F) == 0x3F
        golden_str = " \033[93m*** GOLDEN JACKPOT HIT! ***\033[0m" if is_golden else ""

        print(f"  [+] Solved {token_name} block! Nonce={winning_nonce} ({elapsed:.1f}s, {rate:.0f} h/s){golden_str}", flush=True)

        fn_sig = "mineAndStake(uint256)" if auto_stake else "mine(uint256)"
        try:
            tx_out = cast_send(rpc_url, private_key, contract, fn_sig, str(winning_nonce))
            tx_hash = tx_out.split()[0] if tx_out else "confirmed"
            print(f"  [✓] Solution accepted on Base Mainnet! Tx: {tx_hash[:18]}...", flush=True)
            return True
        except Exception as e:
            print(f"  [!] Failed to broadcast transaction: {e}")
            return False

    return False


# ---------------------------------------------------------------------------
# Zero-Idle Switch-Miner Main Loop
# ---------------------------------------------------------------------------

def run_switch_miner(
    rpc_url: str,
    thin_contract: str,
    frac_contract: str,
    private_key: str,
    cores: int = 2,
    max_temp: float = 72.0,
    throttle_ms: float = 25.0
):
    miner_addr = get_wallet_address(private_key)
    native_engine = get_native_engine()

    print("\n" + "=" * 70)
    print("  🚀 THIN & FRAC — ZERO-IDLE DUAL SWITCH-MINER (BASE MAINNET)")
    print("=" * 70)
    print(f"  Miner Wallet:     {miner_addr}")
    print(f"  Thin Coin (THIN): {thin_contract}")
    print(f"  FractalCoin (FRAC): {frac_contract}")
    print(f"  CPU Allocation:   {cores} Cores | Max Temp: {max_temp}°C")
    print(f"  Zero-Idle Logic:  Auto-switches to FRAC when THIN is cooling, and vice versa!")
    print("=" * 70 + "\n")

    while True:
        thin_cooldown = get_cooldown_remaining(rpc_url, thin_contract, miner_addr)
        frac_cooldown = get_cooldown_remaining(rpc_url, frac_contract, miner_addr)

        # Priority 1: If THIN is ready, mine THIN!
        if thin_cooldown == 0:
            mine_epoch("THIN", rpc_url, thin_contract, private_key, miner_addr, cores, max_temp, throttle_ms, True, native_engine)
            continue

        # Priority 2: THIN is in cooldown. If FRAC is ready, mine FRAC!
        if frac_cooldown == 0:
            print(f"  [⏳] THIN is in 300s cooldown ({thin_cooldown}s left). Instantly switching CPU to FRAC!", flush=True)
            mine_epoch("FRAC", rpc_url, frac_contract, private_key, miner_addr, cores, max_temp, throttle_ms, True, native_engine)
            continue

        # Priority 3: Both are temporarily in cooldown (rare overlap)
        min_wait = min(thin_cooldown, frac_cooldown)
        print(f"  [⏳] Both tokens in fairness cooldown (THIN: {thin_cooldown}s | FRAC: {frac_cooldown}s). Resting SoC for {min_wait}s...", flush=True)
        time.sleep(min_wait)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="THIN & FRAC Cooldown Switch-Miner")
    parser.add_argument("--rpc-url", default="https://mainnet.base.org")
    parser.add_argument("--thin-contract", default="0x129af9c585f9a8a0438c79644d03e049ed6291b2", help="ThinPoWToken contract address")
    parser.add_argument("--frac-contract", default="0x8F92de279E8f942Cb4E37F3A207A221CB5566C04")
    parser.add_argument("--private-key", default=os.getenv("MINER_PRIVATE_KEY", ""))
    parser.add_argument("--cores", type=int, default=2)
    parser.add_argument("--max-temp", type=float, default=72.0)
    parser.add_argument("--throttle-ms", type=float, default=25.0)

    args = parser.parse_args()

    if not args.private_key:
        print("[!] Private key required. Pass via --private-key or MINER_PRIVATE_KEY env var.")
        sys.exit(1)

    run_switch_miner(
        args.rpc_url,
        args.thin_contract,
        args.frac_contract,
        args.private_key,
        args.cores,
        args.max_temp,
        args.throttle_ms
    )
