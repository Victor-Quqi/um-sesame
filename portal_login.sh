#!/bin/sh

# --- Load environment config (.env) ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
MAX_TIME=15

# Logger wrapper
log() {
    logger -t "PortalLogin" "$1"
}

if [ ! -f "$ENV_FILE" ]; then
    log "FATAL ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

while IFS= read -r line || [ -n "$line" ]; do
    line=$(printf '%s' "$line" | tr -d '\r')

    case "$line" in
        ''|'#'*)
            continue
            ;;
    esac

    key=${line%%=*}
    value=${line#*=}

    case "$key" in
        USERNAME)
            USERNAME=$value
            export USERNAME
            ;;
        PASSWORD)
            PASSWORD=$value
            export PASSWORD
            ;;
        LOGIN_URL)
            LOGIN_URL=$value
            export LOGIN_URL
            ;;
    esac
done < "$ENV_FILE"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$LOGIN_URL" ]; then
    log "FATAL ERROR: USERNAME, PASSWORD or LOGIN_URL is empty in .env"
    exit 1
fi

# --- Temp file paths (stored in /tmp, memory-backed) ---
DEBUG_FILE="/tmp/portal_debug.log"
HEADER_FILE="/tmp/portal_headers.txt"

# Overwrite on each run to prevent unbounded growth
# Set restrictive permissions so only the owner can read the log
echo "--- Debug log started at $(date) ---" > "$DEBUG_FILE"
chmod 600 "$DEBUG_FILE"
: > "$HEADER_FILE"
chmod 600 "$HEADER_FILE"

# --- Main ---
log "======== SCRIPT EXECUTION STARTED ========"

# --- Step 1: Detect captive portal via redirect ---
DETECTION_URLS="http://detectportal.firefox.com/success.txt http://www.msftconnecttest.com/connecttest.txt"
PORTAL_ENTRY_URL=""

for url in $DETECTION_URLS; do
    log "Step 1.1: Attempting to detect portal using: $url"
    curl_output=$(curl -v --max-redirs 1 --connect-timeout 5 --max-time "$MAX_TIME" "$url" 2>&1)

    echo "--- [Step 1] Initial Redirect Detection ---" >> "$DEBUG_FILE"
    echo "$curl_output" >> "$DEBUG_FILE"

    PORTAL_ENTRY_URL=$(echo "$curl_output" | sed -n "s/.*URL=\([^'\"]*\).*/\1/p")
    if [ -n "$PORTAL_ENTRY_URL" ]; then
        log "Step 1.2: SUCCESS - Detected intermediate portal URL."
        break
    fi
done

if [ -z "$PORTAL_ENTRY_URL" ]; then
    log "Step 1.3: ERROR - Failed to detect intermediate portal URL."
    exit 1
fi
log "Step 1.4: Intermediate URL: $PORTAL_ENTRY_URL"

# --- Step 2: Follow intermediate URL to reach the final auth page ---
log "Step 2.1: Following redirect to final auth page..."
if ! curl -s -L --connect-timeout 5 --max-time "$MAX_TIME" -D "$HEADER_FILE" "$PORTAL_ENTRY_URL" -o /dev/null; then
    log "Step 2.2: ERROR - Failed to fetch final auth page."
    exit 1
fi
echo "--- [Step 2] Final Redirect Headers ---" >> "$DEBUG_FILE"
cat "$HEADER_FILE" >> "$DEBUG_FILE"

FINAL_AUTH_URL=$(grep -i "^Location:" "$HEADER_FILE" | tail -1 | awk '{print $2}' | tr -d '\r')
if [ -z "$FINAL_AUTH_URL" ]; then
    log "Step 2.3: WARNING - No second redirect detected. Using intermediate URL as final."
    FINAL_AUTH_URL="$PORTAL_ENTRY_URL"
fi
log "Step 2.4: Reached Final Auth Page URL: $FINAL_AUTH_URL"

# --- Step 3: Parse dynamic parameters from the auth URL ---
log "Step 3.1: Parsing dynamic parameters..."
pushPageId=$(echo "$FINAL_AUTH_URL" | sed -n "s/.*pushPageId=\([^&]*\).*/\1/p")
ssid=$(echo "$FINAL_AUTH_URL" | sed -n "s/.*ssid=\([^&]*\).*/\1/p")
uaddress=$(echo "$FINAL_AUTH_URL" | sed -n "s/.*uaddress=\([^&]*\).*/\1/p")
umac=$(echo "$FINAL_AUTH_URL" | sed -n "s/.*umac=\([^&]*\).*/\1/p")
acip=$(echo "$FINAL_AUTH_URL" | sed -n "s/.*ac-ip=\([^&]*\).*/\1/p")
log "Step 3.2: Parsed Parameters: pushPageId=$pushPageId, ssid=$ssid"

# --- Step 4: Build and send the login request ---
LOGIN_POST_URL="$LOGIN_URL"
log "Step 4.1: Sending authentication request..."
POST_DATA="pushPageId=$pushPageId&userPass=$PASSWORD&esn=&apmac=&armac=&authType=1&ssid=$ssid&uaddress=$uaddress&umac=$umac&accessMac=&businessType=&acip=$acip&agreed=1&registerCode=&questions=&dynamicValidCode=&dynamicRSAToken=&validCode=&userName=$USERNAME"

# Log sanitized POST data (mask password)
MASKED_PASS=$(echo "$PASSWORD" | sed 's/./*/g')
echo "--- [Step 4] POST Data (password masked) ---" >> "$DEBUG_FILE"
echo "$POST_DATA" | sed "s/userPass=$PASSWORD/userPass=$MASKED_PASS/" >> "$DEBUG_FILE"

if ! auth_response_body=$(curl -sS "$LOGIN_POST_URL" \
  --connect-timeout 5 \
  --max-time "$MAX_TIME" \
  -H "Accept: application/json, text/javascript, */*; q=0.01" \
  -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
  -H "Referer: $FINAL_AUTH_URL" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
  -H "X-Requested-With: XMLHttpRequest" \
  --data-raw "$POST_DATA"); then
    log "Step 4.2: ERROR - Authentication request failed."
    exit 1
fi

echo "--- [Step 4] Final Authentication Response Body ---" >> "$DEBUG_FILE"
echo "$auth_response_body" >> "$DEBUG_FILE"

# --- Step 5: Validate the JSON response ---
log "Step 5.1: Validating JSON response..."
if echo "$auth_response_body" | grep -q '"success":true'; then
    log "Step 5.2: SUCCESS - Authentication response confirms success!"
else
    error_code=$(echo "$auth_response_body" | sed -n 's/.*"errorcode":"\([^"]*\)".*/\1/p')
    log "Step 5.2: ERROR - Server responded, but login failed. Error code: ${error_code:-N/A}"
    exit 1
fi

log "======== SCRIPT EXECUTION FINISHED ========"
exit 0
