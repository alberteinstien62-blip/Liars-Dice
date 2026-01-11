#!/usr/bin/env bash
set -eu

source ~/.cargo/env

# Read chain IDs
CHAIN_DATA=$(cat /tmp/chain_ids_new.txt)
MASTER=$(echo "$CHAIN_DATA" | cut -d'|' -f1)
LOBBY=$(echo "$CHAIN_DATA" | cut -d'|' -f2)
USER_A=$(echo "$CHAIN_DATA" | cut -d'|' -f3)

echo "Master: $MASTER"
echo "Lobby: $LOBBY"
echo "User A: $USER_A"

# Set wallet paths
LINERA_TMP=/tmp/linera
W1="$LINERA_TMP/wallet_1.json"
S1="rocksdb:$LINERA_TMP/client_1.db"
K1="$LINERA_TMP/keystore_1.json"

W2="$LINERA_TMP/wallet_2.json"
S2="rocksdb:$LINERA_TMP/client_2.db"
K2="$LINERA_TMP/keystore_2.json"

cd "/mnt/c/Users/prate/Downloads/new prejt or buildahtin/liars-dice"

echo ""
echo "=== Deploying Bankroll ==="
BANKROLL_APP_ID=$(linera --wallet "$W1" --storage "$S1" --keystore "$K1" \
  --wait-for-outgoing-messages \
  project publish-and-create . bankroll \
  --json-argument "{\"master_chain\": \"$MASTER\", \"bonus\": \"25000\"}")
echo "Bankroll: $BANKROLL_APP_ID"
sleep 2

echo ""
echo "=== Deploying Liar's Dice on Lobby Chain (type 1) ==="
LOBBY_APP=$(linera --wallet "$W1" --storage "$S1" --keystore "$K1" \
  --wait-for-outgoing-messages \
  project publish-and-create . liars_dice \
  --required-application-ids "$BANKROLL_APP_ID" \
  --json-argument "1" \
  --json-parameters "{\"master_chain\": \"$MASTER\", \"lobby_chain\": \"$LOBBY\", \"bankroll\": \"$BANKROLL_APP_ID\"}")
echo "Lobby App: $LOBBY_APP"
sleep 2

echo ""
echo "=== Initializing Wallet 2 for Player A ==="
# Remove old wallet files if they exist
rm -f "$W2" "$K2" 2>/dev/null || true
rm -rf "$LINERA_TMP/client_2.db" 2>/dev/null || true

linera --wallet "$W2" --storage "$S2" --keystore "$K2" \
  wallet init --faucet http://localhost:8080
echo "Wallet 2 initialized"

# Request a user chain for Player A and set as default
USER_A_NEW=$(linera --wallet "$W2" --storage "$S2" --keystore "$K2" \
  wallet request-chain --faucet http://localhost:8080 | head -1)
echo "User A Chain created: $USER_A_NEW"

# Set it as default chain
linera --wallet "$W2" --storage "$S2" --keystore "$K2" \
  wallet set-default "$USER_A_NEW"
echo "User A chain set as default"
sleep 1

echo ""
echo "=== Deploying Liar's Dice for Player A (type 3) ==="
USER_A_APP=$(linera --wallet "$W2" --storage "$S2" --keystore "$K2" \
  --wait-for-outgoing-messages \
  project publish-and-create . liars_dice \
  --required-application-ids "$BANKROLL_APP_ID" \
  --json-argument "3" \
  --json-parameters "{\"master_chain\": \"$MASTER\", \"lobby_chain\": \"$LOBBY\", \"bankroll\": \"$BANKROLL_APP_ID\"}")
echo "User A App: $USER_A_APP"
sleep 2

echo ""
echo "=== Initializing Wallet 3 for User B ==="
W3="$LINERA_TMP/wallet_3.json"
S3="rocksdb:$LINERA_TMP/client_3.db"
K3="$LINERA_TMP/keystore_3.json"

# Remove old wallet files if they exist
rm -f "$W3" "$K3" 2>/dev/null || true
rm -rf "$LINERA_TMP/client_3.db" 2>/dev/null || true

linera --wallet "$W3" --storage "$S3" --keystore "$K3" \
  wallet init --faucet http://localhost:8080
echo "Wallet 3 initialized"

# Create User B chain from wallet 3
USER_B=$(linera --wallet "$W3" --storage "$S3" --keystore "$K3" \
  wallet request-chain --faucet http://localhost:8080 | head -1)
echo "User B Chain created: $USER_B"

# Set it as default
linera --wallet "$W3" --storage "$S3" --keystore "$K3" \
  wallet set-default "$USER_B"
echo "User B chain set as default"
sleep 1

echo ""
echo "=== Deploying Liar's Dice for Player B (type 3) ==="
USER_B_APP=$(linera --wallet "$W3" --storage "$S3" --keystore "$K3" \
  --wait-for-outgoing-messages \
  project publish-and-create . liars_dice \
  --required-application-ids "$BANKROLL_APP_ID" \
  --json-argument "3" \
  --json-parameters "{\"master_chain\": \"$MASTER\", \"lobby_chain\": \"$LOBBY\", \"bankroll\": \"$BANKROLL_APP_ID\"}")
echo "User B App: $USER_B_APP"
sleep 2

echo ""
echo "=== Starting Services ==="

pkill -f "linera.*service.*8092" || true
pkill -f "linera.*service.*8093" || true
sleep 1

nohup linera --wallet "$W2" --storage "$S2" --keystore "$K2" \
  service --port 8092 > /tmp/user_a_service.log 2>&1 &
echo "Player A service: port 8092 (PID $!)"
sleep 2

nohup linera --wallet "$W3" --storage "$S3" --keystore "$K3" \
  service --port 8093 > /tmp/user_b_service.log 2>&1 &
echo "Player B service: port 8093 (PID $!)"
sleep 3

echo ""
echo "=== Generating Frontend Configs ==="

mkdir -p frontend/web_a frontend/web_b

cat > frontend/web_a/config.json << EOF
{
  "nodeServiceURL": "http://localhost:8092",
  "liarsDiceAppId": "$USER_A_APP",
  "bankrollAppId": "$BANKROLL_APP_ID",
  "masterChain": "$MASTER",
  "lobbyChain": "$LOBBY",
  "userChain": "$USER_A"
}
EOF

cat > frontend/web_b/config.json << EOF
{
  "nodeServiceURL": "http://localhost:8093",
  "liarsDiceAppId": "$USER_B_APP",
  "bankrollAppId": "$BANKROLL_APP_ID",
  "masterChain": "$MASTER",
  "lobbyChain": "$LOBBY",
  "userChain": "$USER_B"
}
EOF

echo "✓ Configs created"

echo ""
echo "============================================="
echo "LIAR'S DICE - DEPLOYMENT COMPLETE!"
echo "============================================="
echo ""
echo "Application IDs:"
echo "  Bankroll:     $BANKROLL_APP_ID"
echo "  Lobby (type 1): $LOBBY_APP"
echo "  User A (type 3): $USER_A_APP"
echo "  User B (type 3): $USER_B_APP"
echo ""
echo "Chain IDs:"
echo "  Master: $MASTER"
echo "  Lobby:  $LOBBY"
echo "  User A: $USER_A"
echo "  User B: $USER_B"
echo ""
echo "Services:"
echo "  http://localhost:8092 - Player A"
echo "  http://localhost:8093 - Player B"
echo ""
echo "Frontend:"
echo "  http://localhost:5173 - Player A"
echo "  http://localhost:5174 - Player B"
echo ""
