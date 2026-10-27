#!/usr/bin/env bash
# Opens the Thin Coin Private Dev Control Center & Holder Audit Portal
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

PORT="7446"
ADMIN_URL="http://127.0.0.1:$PORT/admin.html"

if ! curl -sf -o /dev/null "http://127.0.0.1:$PORT/"; then
    nohup python3 -u "$DIR/dashboard.py" \
        --port "$PORT" >> "$DIR/dashboard.log" 2>&1 < /dev/null &
    for _ in $(seq 1 25); do
        curl -sf -o /dev/null "$ADMIN_URL" && break
        sleep 0.2
    done
fi

exec firefox "$ADMIN_URL" 2>/dev/null || exec xdg-open "$ADMIN_URL"
