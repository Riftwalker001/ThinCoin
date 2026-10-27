#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[+] Compiling Thin Coin Sequential-64 Native C Engine with -O3..."
gcc -O3 -shared -fPIC -pthread -o "$DIR/libthinminer.so" "$DIR/thin_engine.c"
echo "[✓] libthinminer.so compiled successfully!"
