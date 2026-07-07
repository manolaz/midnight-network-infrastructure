#!/bin/bash
# ==============================================================================
# Midnight FNO Maintenance Notification Script (Option B)
# Description: Generates and sends a structured maintenance window notification 
#              to a list of node operators. Flags operators who have not 
#              acknowledged within a configurable timeout.
# Usage: ./maintenance_notify.sh [timeout_in_sec]
# ==============================================================================

DATA_DIR="$(dirname "$0")/data"
mkdir -p "$DATA_DIR"
OPERATORS_FILE="$DATA_DIR/operators.json"

# Mock operators setup
if [ ! -f "$OPERATORS_FILE" ]; then
  cat <<JSON > "$OPERATORS_FILE"
  [
    {"id": "fno-1", "email": "admin@fno1.test"},
    {"id": "fno-2", "email": "admin@fno2.test"},
    {"id": "fno-3", "email": "admin@fno3.test"}
  ]
JSON
fi

TIMEOUT_SEC=${1:-5}

# Configuration for maintenance window
START_TIME="2026-08-01T00:00:00Z"
END_TIME="2026-08-01T04:00:00Z"
IMPACT="Node downtime expected. Block production will pause for 4 hours."

echo "[*] Generating Maintenance Notification..."

# Create a structured JSON notification
NOTIFICATION_JSON=$(jq -n \
  --arg st "$START_TIME" \
  --arg et "$END_TIME" \
  --arg imp "$IMPACT" \
  '{window_start: $st, window_end: $et, expected_impact: $imp, requires_ack: true}')
  
echo "$NOTIFICATION_JSON" | jq .
echo ""
echo "[*] Sending notifications to operators..."

# Track acknowledgments in a dictionary
declare -A ACK_STATUS

for row in $(cat "$OPERATORS_FILE" | jq -r '.[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    ID=$(_jq '.id')
    EMAIL=$(_jq '.email')
    
    echo "  -> Sending notification to $ID ($EMAIL)..."
    ACK_STATUS["$ID"]="pending"
done

echo ""
echo "[*] Waiting for acknowledgements (Timeout configured: ${TIMEOUT_SEC}s)..."

# Simulate waiting and receiving random acknowledgments
for (( i=1; i<=$TIMEOUT_SEC; i++ )); do
    sleep 1
    # Check pending operators
    for ID in "${!ACK_STATUS[@]}"; do
        if [ "${ACK_STATUS[$ID]}" == "pending" ]; then
            # 30% chance per second they acknowledge for the sake of demonstration
            if [ $((RANDOM % 100)) -lt 30 ]; then
                ACK_STATUS["$ID"]="acknowledged"
                echo "  [ACK] Received acknowledgement from $ID at T+${i}s"
            fi
        fi
    done
done

echo ""
echo "[*] Timeout reached. Evaluating unacknowledged operators:"
for ID in "${!ACK_STATUS[@]}"; do
    if [ "${ACK_STATUS[$ID]}" == "pending" ]; then
        echo "  [FLAGGED] Operator $ID failed to acknowledge within the timeout window!"
    else
        echo "  [OK] Operator $ID acknowledged successfully."
    fi
done
