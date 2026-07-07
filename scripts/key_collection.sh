#!/bin/bash
# ==============================================================================
# Midnight FNO Key Collection Script (Option A)
# Description: Given a mock list of FNO operator identifiers, sends a structured 
#              request for their public keys and logs which operators responded.
#              Output is a machine-readable JSON file. Re-runnable & idempotent.
# Usage: ./key_collection.sh
# ==============================================================================

DATA_DIR="$(dirname "$0")/data"
mkdir -p "$DATA_DIR"

OPERATORS_FILE="$DATA_DIR/operators.json"
STATE_FILE="$DATA_DIR/key_collection_state.json"

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

# Initialize state if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
  echo "[]" > "$STATE_FILE"
fi

echo "[*] Starting Key Collection Process..."

NEW_STATE=$(cat "$STATE_FILE")

# Iterate through operators safely
for row in $(cat "$OPERATORS_FILE" | jq -r '.[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    
    ID=$(_jq '.id')
    EMAIL=$(_jq '.email')
    
    # Check if already responded
    HAS_RESPONDED=$(echo "$NEW_STATE" | jq -e "[.[] | select(.id == \"$ID\" and .responded == true)] | length > 0" > /dev/null; echo $?)
    
    if [ "$HAS_RESPONDED" -eq 0 ]; then
        echo "  [SKIP] Operator $ID already provided their public key."
        continue
    fi
    
    echo "  [REQUEST] Sending public key request to $ID ($EMAIL)..."
    
    # Simulate network request/response (mocking a 66% chance of response for demo purposes)
    RAND=$((RANDOM % 3))
    if [ "$RAND" -ne 0 ]; then
        echo "    [+] Response received from $ID!"
        # Update state (remove old record if exists, add new successful record)
        NEW_STATE=$(echo "$NEW_STATE" | jq "map(select(.id != \"$ID\")) + [{\"id\": \"$ID\", \"email\": \"$EMAIL\", \"responded\": true, \"pub_key\": \"mock_pubkey_$(date +%s)_$RAND\"}]")
    else
        echo "    [-] No response from $ID yet."
        # Update state (remove old record if exists, add new failed record)
        NEW_STATE=$(echo "$NEW_STATE" | jq "map(select(.id != \"$ID\")) + [{\"id\": \"$ID\", \"email\": \"$EMAIL\", \"responded\": false, \"pub_key\": null}]")
    fi
done

echo "$NEW_STATE" | jq . > "$STATE_FILE"
echo ""
echo "[*] Current Key Collection State saved to $STATE_FILE:"
cat "$STATE_FILE" | jq .
