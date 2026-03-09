#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGIN_SCRIPT="$SCRIPT_DIR/portal_login.sh"

RESP=$(curl -s --connect-timeout 5 --max-time 10 http://detectportal.firefox.com/success.txt 2>/dev/null)

if [ "$RESP" = "success" ]; then
    exit 0
fi

logger -t "NetWatchdog" "Network check failed. Triggering login script..."
/bin/sh "$LOGIN_SCRIPT"
