#!/bin/bash

# ==============================================================================
# Midnight Node Health Checker
# Description: Polls the node's RPC endpoint, evaluates health conditions, 
#              and writes a structured JSON health report to disk.
#              Diffs against the previous report to surface any regressions.
# Usage: ./health_check.sh [rpc_url]
# ==============================================================================

RPC_URL=${1:-"http://localhost:9944"}
REPORT_FILE="node_health_report.json"
PREV_REPORT_FILE="node_health_report_prev.json"

# Move the current report to previous if it exists
if [ -f "$REPORT_FILE" ]; then
    cp "$REPORT_FILE" "$PREV_REPORT_FILE"
fi

echo "[*] Polling Midnight Node at $RPC_URL..."

# Fetch system_health
HEALTH_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "system_health"}' "$RPC_URL")

# Check if curl succeeded
if [ $? -ne 0 ] || [ -z "$HEALTH_RESPONSE" ]; then
    echo "[-] Error: Failed to connect to RPC endpoint."
    STATUS="offline"
    PEERS=0
    IS_SYNCING="unknown"
else
    # Parse values using jq
    PEERS=$(echo "$HEALTH_RESPONSE" | jq -r '.result.peers // 0')
    IS_SYNCING=$(echo "$HEALTH_RESPONSE" | jq -r '.result.isSyncing // false')
    
    # Simple evaluation
    if [ "$PEERS" -gt 0 ] && [ "$IS_SYNCING" == "false" ]; then
        STATUS="healthy"
    elif [ "$IS_SYNCING" == "true" ]; then
        STATUS="syncing"
    else
        STATUS="degraded"
    fi
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Write structured JSON report
cat <<JSON > "$REPORT_FILE"
{
  "timestamp": "$TIMESTAMP",
  "status": "$STATUS",
  "peers": $PEERS,
  "is_syncing": $IS_SYNCING,
  "rpc_url": "$RPC_URL"
}
JSON

echo "[+] Health report generated: $REPORT_FILE"
cat "$REPORT_FILE" | jq .

# Regressions / Diff check
if [ -f "$PREV_REPORT_FILE" ]; then
    echo ""
    echo "[*] Comparing with previous report..."
    PREV_STATUS=$(jq -r '.status' "$PREV_REPORT_FILE")
    PREV_PEERS=$(jq -r '.peers' "$PREV_REPORT_FILE")
    
    if [ "$PREV_STATUS" == "healthy" ] && [ "$STATUS" != "healthy" ]; then
        echo "  [!] REGRESSION DETECTED: Status degraded from healthy to $STATUS"
    fi
    
    if [ "$PREV_PEERS" -gt 5 ] && [ "$PEERS" -lt 5 ]; then
        echo "  [!] REGRESSION DETECTED: Peer count dropped significantly (was $PREV_PEERS, now $PEERS)"
    fi
else
    echo "[*] No previous report found to compare against."
fi
