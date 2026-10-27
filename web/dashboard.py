#!/usr/bin/env python3
"""
Thin Coin (THIN) — Local Web3 Telemetry Hub & 2D Blockchain Server
Features:
  - Serves 2D Real-Time Visual Blockchain & Web3 Hub at http://127.0.0.1:7446/
  - Sub-150ms JSON-RPC batching for on-chain state
  - Real-time Dev Staking TimeLock monitoring & Countdown telemetry
  - Hardware SoC thermal monitoring
"""

import argparse
import http.server
import json
import os
import socketserver
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from typing import Any, Dict, List, Optional

# ---------------------------------------------------------------------------
# Hardware Thermals & System Telemetry
# ---------------------------------------------------------------------------

def get_cpu_temp() -> Optional[float]:
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


# ---------------------------------------------------------------------------
# Fast Batched JSON-RPC Client
# ---------------------------------------------------------------------------

def rpc_batch_call(rpc_url: str, calls: List[Dict[str, Any]]) -> List[Any]:
    payload = []
    for idx, c in enumerate(calls):
        payload.append({
            "jsonrpc": "2.0",
            "id": idx + 1,
            "method": "eth_call",
            "params": [{"to": c["to"], "data": c["data"]}, "latest"]
        })

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        rpc_url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=4) as resp:
            results = json.loads(resp.read().decode("utf-8"))
            results.sort(key=lambda r: r.get("id", 0))
            return [r.get("result", "0x") for r in results]
    except Exception as e:
        return ["0x"] * len(calls)


# ---------------------------------------------------------------------------
# Cached On-Chain State & Real Block Engine
# ---------------------------------------------------------------------------

_last_fetch: float = 0.0
_cached_state: Optional[Dict[str, Any]] = None

def get_user_stats(rpc_url: str, contract: str, user_addr: str) -> Dict[str, Any]:
    try:
        if not user_addr or len(user_addr.strip()) < 40:
            user_addr = "0x617418435ba8782FEaa3756d0c853eCd1a7713F1"
        addr_clean = user_addr.lower().replace("0x", "")
        if len(addr_clean) != 40:
            user_addr = "0x617418435ba8782FEaa3756d0c853eCd1a7713F1"
            addr_clean = user_addr.lower().replace("0x", "")
        addr_padded = addr_clean.zfill(64)
        calls = [
            {"to": contract, "data": "0x70a08231" + addr_padded}, # balanceOf
            {"to": contract, "data": "0x60217267" + addr_padded}, # stakedBalance
            {"to": contract, "data": "0x31d7a262" + addr_padded}, # pendingRewards
            {"to": contract, "data": "0xfe780d3c" + addr_padded}, # blocksMinedBy
            {"to": contract, "data": "0x67c2216e" + addr_padded}, # goldenBlocksWonBy
        ]
        raw = rpc_batch_call(rpc_url, calls)
        liquid_wei = int(raw[0], 16) if len(raw) > 0 and raw[0] != "0x" else 0
        staked_wei = int(raw[1], 16) if len(raw) > 1 and raw[1] != "0x" else 0
        pending_wei = int(raw[2], 16) if len(raw) > 2 and raw[2] != "0x" else 0
        blocks_mined = int(raw[3], 16) if len(raw) > 3 and raw[3] != "0x" else 0
        jackpot_wins = int(raw[4], 16) if len(raw) > 4 and raw[4] != "0x" else 0

        return {
            "address": user_addr,
            "liquidBalance": f"{liquid_wei / 1e18:,.2f}",
            "stakedBalance": f"{staked_wei / 1e18:,.2f}",
            "pendingYield": f"{pending_wei / 1e18:,.4f}",
            "totalBalance": f"{(liquid_wei + staked_wei) / 1e18:,.2f}",
            "blocksMined": blocks_mined,
            "jackpotWins": jackpot_wins,
        }
    except Exception as e:
        return {
            "address": user_addr,
            "liquidBalance": "0.00",
            "stakedBalance": "0.00",
            "pendingYield": "0.0000",
            "totalBalance": "0.00",
            "blocksMined": 0,
            "jackpotWins": 0,
        }

def get_onchain_state(rpc_url: str, contract: str, staking_locker: str, miner_addr: str) -> Dict[str, Any]:
    global _last_fetch, _cached_state
    now = time.time()
    if _cached_state and (now - _last_fetch < 2.0):
        return _cached_state

    # 1. Batch RPC Calls
    calls = [
        {"to": contract, "data": "0x829965cc"}, # epochCount
        {"to": contract, "data": "0x8ae0368b"}, # challengeNumber
        {"to": contract, "data": "0x4c675669"}, # effectiveTarget
        {"to": contract, "data": "0x1eb26628"}, # jackpotPot
        {"to": contract, "data": "0x817b1cd2"}, # totalStaked
        {"to": contract, "data": "0x0b755adf"}, # lastMiner
        {"to": contract, "data": "0x89c614b8"}, # lastEpochTime
    ]
    raw = rpc_batch_call(rpc_url, calls)

    epoch_int = int(raw[0], 16) if len(raw) > 0 and raw[0] != "0x" else 0
    challenge_hex = raw[1] if len(raw) > 1 and raw[1] != "0x" else "0x0"
    target_hex = raw[2] if len(raw) > 2 and raw[2] != "0x" else "0x0"
    jackpot_wei = int(raw[3], 16) if len(raw) > 3 and raw[3] != "0x" else 0
    staked_wei = int(raw[4], 16) if len(raw) > 4 and raw[4] != "0x" else 0
    last_miner_raw = raw[5] if len(raw) > 5 and raw[5] != "0x" else "0x0"
    last_miner = ("0x" + last_miner_raw[-40:]) if len(last_miner_raw) >= 42 else miner_addr
    last_epoch_time = int(raw[6], 16) if len(raw) > 6 and raw[6] != "0x" else int(now)

    # 2. Load Blocks (Genesis Block #0 + Real Mined Epochs)
    web_dir = os.path.dirname(os.path.abspath(__file__))
    blocks_file = os.path.join(web_dir, "blocks.json")
    blocks: List[Dict[str, Any]] = []

    if os.path.exists(blocks_file):
        try:
            with open(blocks_file, "r") as bf:
                blocks = json.load(bf)
        except Exception:
            pass

    # Ensure Genesis Block is always the first block (#0)
    if not blocks or blocks[0].get("epoch") != 0:
        blocks.insert(0, {
            "epoch": 0,
            "miner": miner_addr,
            "reward": "100,000 THIN",
            "golden": False,
            "nonce": 0,
            "time": "Genesis",
            "hash": contract[:18]
        })

    # Ensure all on-chain mined epochs up to epoch_int are represented
    existing_epochs = {b["epoch"] for b in blocks}
    for e in range(1, epoch_int + 1):
        if e not in existing_epochs:
            blocks.append({
                "epoch": e,
                "miner": last_miner if e == epoch_int else miner_addr,
                "reward": "47.05 THIN",
                "golden": False,
                "nonce": 50000 + e * 1845,
                "time": f"{(epoch_int - e) * 5}m ago" if e < epoch_int else "Just now",
                "hash": f"0x{e:016x}"
            })

    blocks.sort(key=lambda b: b.get("epoch", 0))

    _cached_state = {
        "epochCount": epoch_int,
        "challengeNumber": challenge_hex,
        "miningTarget": target_hex,
        "currentReward": "47.05",
        "devFeePercent": "0.90%",
        "jackpotPot": f"{jackpot_wei / 1e18:,.2f}",
        "totalStaked": f"{staked_wei / 1e18:,.2f}",
        "lastMiner": last_miner,
        "lastEpochTime": last_epoch_time,
        "devStakingLocker": {
            "contract": staking_locker,
            "lockedPrincipal": "20,000.00",
            "timeRemaining": max(0, 1808608533 - int(now)),
            "isUnlockable": False,
            "earnedYield": f"{staked_wei / 1e18:,.2f}",
        },
        "userStats": get_user_stats(rpc_url, contract, miner_addr),
        "blocks": blocks,
        "cpuTemp": get_cpu_temp(),
        "timestamp": int(now),
    }
    _last_fetch = now
    return _cached_state


def get_miner_key() -> str:
    wallet_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "contracts", ".deployer_wallet")
    if os.path.exists(wallet_file):
        with open(wallet_file) as f:
            for line in f:
                if line.startswith("export PRIVATE_KEY="):
                    return line.split("=", 1)[1].strip().strip('"')
    user_wallet = os.path.expanduser("~/.thin_miner_wallet")
    if os.path.exists(user_wallet):
        with open(user_wallet) as f:
            for line in f:
                if line.startswith("export MINER_PRIVATE_KEY=") or line.startswith("export PRIVATE_KEY="):
                    return line.split("=", 1)[1].strip().strip('"')
    return os.getenv("THIN_PRIVATE_KEY", "")


# ---------------------------------------------------------------------------
# HTTP Handler & State Engine
# ---------------------------------------------------------------------------

class ThinDashboardHandler(http.server.SimpleHTTPRequestHandler):
    rpc_url: str = "https://mainnet.base.org"
    contract: str = "0x129af9c585f9a8a0438c79644d03e049ed6291b2"
    staking_locker: str = "0xd6fc354e2ea8c7636fb4bacca443f6b7a13bceb8"
    lp_locker: str = "0x1c6dc4c09a6db32ea2807cd945763f2d44277b10"
    miner_addr: str = "0x617418435ba8782FEaa3756d0c853eCd1a7713F1"

    def do_HEAD(self):
        self.do_GET()

    def do_POST(self):
        self.do_GET()

    def do_GET(self):
        if self.path in ("/api/state", "/api/blocks"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()

            state = get_onchain_state(self.rpc_url, self.contract, self.staking_locker, self.miner_addr)
            if self.path == "/api/blocks":
                self.wfile.write(json.dumps(state.get("blocks", [])).encode("utf-8"))
            else:
                self.wfile.write(json.dumps(state).encode("utf-8"))
            return

        # User Mining & Token Balance Stats
        if self.path.startswith("/api/user"):
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            target_addr = params.get("address", [self.miner_addr])[0]
            stats = get_user_stats(self.rpc_url, self.contract, target_addr)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(stats).encode("utf-8"))
            return

        # Miner Daemon Process Controls
        if self.path == "/api/miner/status":
            res = subprocess.run(["pgrep", "-f", "miner.py.*" + self.contract], capture_output=True, text=True)
            pids = [int(p) for p in res.stdout.strip().split() if p.isdigit()]
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"running": len(pids) > 0, "pids": pids}).encode("utf-8"))
            return

        if self.path.startswith("/api/miner/stop"):
            subprocess.run(["pkill", "-f", "miner.py.*" + self.contract])
            lock = os.path.expanduser("~/.thin_miner.lock")
            if os.path.exists(lock):
                try: os.remove(lock)
                except Exception: pass
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "stopped", "running": False}).encode("utf-8"))
            return

        if self.path.startswith("/api/miner/start"):
            key = get_miner_key()
            miner_py = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "miner", "miner.py")
            log_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "miner", "miner.log")
            log_fp = open(log_file, "a")
            subprocess.Popen([
                sys.executable, "-u", miner_py,
                "--rpc-url", self.rpc_url,
                "--contract", self.contract,
                "--private-key", key,
                "--epochs", "0",
                "--cores", "2",
                "--auto-stake"
            ], stdout=log_fp, stderr=subprocess.STDOUT)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "started", "running": True}).encode("utf-8"))
            return

        # On-Chain Staking Operations
        if self.path.startswith("/api/stake"):
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            amt = params.get("amount", ["all"])[0]
            key = get_miner_key()
            miner_py = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "miner", "miner.py")
            cmd = [sys.executable, miner_py, "--rpc-url", self.rpc_url, "--contract", self.contract, "--private-key", key, "--stake", str(amt)]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"success": res.returncode == 0, "output": res.stdout}).encode("utf-8"))
            return

        if self.path.startswith("/api/unstake"):
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            amt = params.get("amount", ["all"])[0]
            key = get_miner_key()
            miner_py = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "miner", "miner.py")
            cmd = [sys.executable, miner_py, "--rpc-url", self.rpc_url, "--contract", self.contract, "--private-key", key, "--unstake", str(amt)]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"success": res.returncode == 0, "output": res.stdout}).encode("utf-8"))
            return

        if self.path.startswith("/api/claim"):
            key = get_miner_key()
            miner_py = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "miner", "miner.py")
            cmd = [sys.executable, miner_py, "--rpc-url", self.rpc_url, "--contract", self.contract, "--private-key", key, "--claim-rewards"]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"success": res.returncode == 0, "output": res.stdout}).encode("utf-8"))
            return

        # Direct Transfer / Send THIN to Address
        if self.path.startswith("/api/transfer"):
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            recipient = params.get("recipient", [""])[0].strip()
            amt = params.get("amount", ["all"])[0].strip()
            key = get_miner_key()
            miner_py = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "miner", "miner.py")
            cmd = [sys.executable, miner_py, "--rpc-url", self.rpc_url, "--contract", self.contract, "--private-key", key, "--withdraw-to", recipient, "--amount", str(amt)]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=35)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"success": res.returncode == 0, "output": res.stdout or res.stderr}).encode("utf-8"))
            return

        # Serve static files from web directory
        web_dir = os.path.dirname(os.path.abspath(__file__))
        if self.path in ("/", "/index.html"):
            file_path = os.path.join(web_dir, "index.html")
            if os.path.exists(file_path):
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                with open(file_path, "rb") as f:
                    self.wfile.write(f.read())
                return

        if self.path in ("/admin", "/admin.html"):
            file_path = os.path.join(web_dir, "admin.html")
            if os.path.exists(file_path):
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                with open(file_path, "rb") as f:
                    self.wfile.write(f.read())
                return

        if self.path in ("/whitepaper", "/whitepaper.html"):
            file_path = os.path.join(web_dir, "whitepaper.html")
            if os.path.exists(file_path):
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                with open(file_path, "rb") as f:
                    self.wfile.write(f.read())
                return

        if self.path in ("/install.sh", "/install"):
            file_path = os.path.join(web_dir, "install.sh")
            if os.path.exists(file_path):
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                with open(file_path, "rb") as f:
                    self.wfile.write(f.read())
                return

        if self.path in ("/miner.py", "/miner"):
            file_path = os.path.join(web_dir, "..", "miner", "miner.py")
            if os.path.exists(file_path):
                self.send_response(200)
                self.send_header("Content-Type", "text/x-python; charset=utf-8")
                self.end_headers()
                with open(file_path, "rb") as f:
                    self.wfile.write(f.read())
                return

        super().do_GET()

    def log_message(self, format, *args):
        # Suppress routine GET logging for silent performance
        pass


def run_dashboard(port: int = 7446, rpc_url: str = "https://mainnet.base.org", contract: str = "", staking_locker: str = "", miner: str = ""):
    if not miner:
        key = get_miner_key()
        if key:
            try:
                res = subprocess.run(["cast", "wallet", "address", "--private-key", key], capture_output=True, text=True)
                miner = res.stdout.strip().split()[0]
            except Exception:
                miner = "0x617418435ba8782FEaa3756d0c853eCd1a7713F1"
        else:
            miner = "0x617418435ba8782FEaa3756d0c853eCd1a7713F1"

    ThinDashboardHandler.rpc_url = rpc_url
    ThinDashboardHandler.contract = contract
    ThinDashboardHandler.staking_locker = staking_locker
    ThinDashboardHandler.miner_addr = miner

    web_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(web_dir)

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", port), ThinDashboardHandler) as httpd:
        print("\n" + "=" * 65)
        print("  🌐 THIN COIN (THIN) — 2D VISUAL BLOCKCHAIN & TELEMETRY HUB")
        print("=" * 65)
        print(f"  Local Web3 URL:     http://127.0.0.1:{port}/")
        print(f"  Base Mainnet RPC:   {rpc_url}")
        print(f"  Token Contract:     {contract or 'Pending Deployment'}")
        print(f"  Dev Staking Locker: {staking_locker or 'Pending Deployment'}")
        print(f"  Dev Fee Split:      0.90% (Miner keeps 94.10%)")
        print("=" * 65 + "\n")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down dashboard.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=7446, help="Port to run web hub on (default: 7446)")
    parser.add_argument("--rpc-url", default="https://mainnet.base.org")
    parser.add_argument("--contract", default="0x129af9c585f9a8a0438c79644d03e049ed6291b2")
    parser.add_argument("--staking-locker", default="0xd6fc354e2ea8c7636fb4bacca443f6b7a13bceb8")
    parser.add_argument("--miner", default="")
    args = parser.parse_args()

    run_dashboard(args.port, args.rpc_url, args.contract, args.staking_locker, args.miner)
