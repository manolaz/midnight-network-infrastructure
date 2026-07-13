# Troubleshooting Guide

This guide covers common issues and resolutions when operating a Midnight FNO node.

## 1. Cardano DB Sync Issues

**Symptom:** The Midnight node fails to start, complaining about database connections or missing schemas.
**Cause:** `cardano-db-sync` has not finished syncing, or the database connection string is incorrect.
**Resolution:**
1. Check the DB Sync logs:
   ```bash
   journalctl -u cardano-db-sync -f
   ```
2. Wait for the sync to complete. It can take up to 6 hours on the preprod network.
3. Ensure the connection string in your `.env` file (`DB_SYNC_POSTGRES_CONNECTION_STRING`) correctly points to `postgresql://midnight:<YOUR_PASSWORD>@localhost:5432/cexplorer`.

## 2. Low Peer Count

**Symptom:** Substrate logs show `libp2p_peers_count` dropping below 5, or the node stops syncing.
**Cause:** Networking issues, bootnode unreachable, or firewalls blocking P2P traffic.
**Resolution:**
1. Verify that your firewall allows inbound TCP traffic on port `30333` (Midnight P2P).
2. Check if the bootnodes specified in the chain spec are reachable.
3. Restart the Midnight service to force peer discovery:
   ```bash
   sudo systemctl restart midnight-node
   ```

## 3. Block Production Stalled

**Symptom:** Alerts trigger for `BlockProductionStalled` and `substrate_block_height` remains static for over 5 minutes.
**Cause:** The Midnight node has lost connection to the Cardano Relay node, or the local DB has become corrupted/unsynced.
**Resolution:**
1. Check the Cardano node status:
   ```bash
   sudo systemctl status cardano-node
   ```
2. Review Midnight logs for substrate consensus errors:
   ```bash
   journalctl -u midnight-node -f
   ```
3. If DB corruption is suspected, you may need to restore from a recent DB snapshot or re-sync `cardano-db-sync`.

## 4. High CPU Usage

**Symptom:** CPU usage sustains >85% for an extended period.
**Cause:** Often caused by RPC spam (if public), initial heavy sync loads, or lack of resources.
**Resolution:**
1. If you are running an archive node with public RPC, consider placing it behind a reverse proxy (like Nginx) with rate limiting.
2. If this is initial sync, wait for it to complete.
3. Ensure the server meets the recommended specifications.
