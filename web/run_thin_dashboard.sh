#!/usr/bin/env bash
# Launches the Thin Coin Web3 Hub and 2D Visual Blockchain
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

PORT="7446"
URL="http://127.0.0.1:$PORT/"

if ! curl -sf -o /dev/null "$URL"; then
    nohup python3 -u "$DIR/dashboard.py" \
        --port "$PORT" >> "$DIR/dashboard.log" 2>&1 < /dev/null &
    for _ in $(seq 1 25); do
        curl -sf -o /dev/null "$URL" && break
        sleep 0.2
    done
fi

exec firefox "$URL" 2>/dev/null || exec xdg-open "$URL"
