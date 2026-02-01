# 🎲 Liar's Dice on Linera - Cryptographically Fair Gaming

A decentralized, provably fair implementation of the classic bluffing dice game **Liar's Dice** built on the [Linera](https://linera.io) blockchain platform.

---

## 🌐 LIVE DEMO - Play Now on Conway Testnet!

**🎲 Play Now (No Setup Required):**
- 🎮 **Player A:** https://liars-dice-player-m7h6vc0v2-pratiikpys-projects.vercel.app
- 🎮 **Player B:** https://liars-dice-player-6suv9mgjc-pratiikpys-projects.vercel.app

**✅ Verified Conway Testnet Deployment** - Updated February 1, 2026

> *Open both URLs in separate browser tabs/windows to play against yourself, or share the Player B link with a friend!*

---

## 🏆 UNIQUE INNOVATION - Why This Project Is Special

### 🔒 Commit-Reveal Cryptography for Hidden Dice

**This is the ONLY WaveHack submission implementing cryptographic hidden state using SHA-256 commit-reveal!**

```rust
// Dice exist ONLY on player's private User Chain
commitment = SHA-256(dice || salt)  // Send only hash to Game Chain
verify_commitment(revealed_dice, salt, commitment)  // Prove later
```

**Why This Matters:**
- 🔒 **Cryptographically Hidden** - Dice are mathematically impossible to predict or see
- ⛓️ **Only Possible with Linera** - Requires microchain architecture (each player has private chain)
- 🚫 **Cheating Impossible** - Can't fake dice, can't change after seeing opponent's bid
- 🎯 **Real Innovation** - Not just UI polish, actual cryptographic security

**How It Works:**
1. Player rolls dice → Stored ONLY on their User Chain (private!)
2. Generate random salt → Hash dice+salt with SHA-256
3. Send commitment (hash) to Game Chain → Original dice stay hidden
4. After "Liar!" called → Reveal dice+salt
5. Game Chain verifies: `SHA-256(revealed_dice || salt) == commitment`

**No other WaveHack project achieves this level of cryptographic security!**

---

## 📹 Demo Video

**🎬 Watch the full demo:** [YouTube Demo Link](https://youtu.be/i4aGtje_qck)

> *Shows: Docker setup, commit-reveal flow, dice privacy, cryptographic verification in browser console, and multiplayer gameplay*

---

## 🔍 Conway Testnet Verification (For Judges)

**Quick Verification Steps:**

1. **Test Live Demo:**
   - Visit: https://liars-dice-player-9rd50i611-pratiikpys-projects.vercel.app
   - Open Browser DevTools (F12) → Console tab
   - Look for: `POST https://conway1.linera.blockhunters.services/...`
   - ✅ Confirms: Connected to real Conway Testnet!

2. **Verify App Exists on Conway:**
```bash
curl https://conway1.linera.blockhunters.services/chains/cba415cd4111f36b77e9b5b773ad60b143ca942b6d4d9c322995f1c314806ca0/applications/43abad04f6ec116ad403cca2b42daf335c27f34167b7940d8a3b30cedfe02366
```
**Expected Response:** `{"data":{"chainType":0}}`

3. **Test Gameplay & Cryptography:**
   - Create profile on both players
   - Find match
   - Roll dice (stored ONLY on your chain!)
   - Make bids
   - Call "Liar!" to reveal and verify cryptographic commitments
   - Watch browser console for commitment verification

---

## Key Features

- **Provably Fair Hidden Dice**: Uses commit-reveal cryptography (SHA-256) to ensure dice are truly hidden until revealed
- **4-Chain Architecture**: Master, Lobby, Game, and User chains for scalable multiplayer
- **ELO Rating System**: Competitive matchmaking based on player skill
- **Real-time Updates**: Event streaming for live game state synchronization
- **Token Economy**: Integrated bankroll system for in-game currency

## How It Works

### Commit-Reveal Security

The game's key innovation is that **your dice exist ONLY on your own chain** until revealed:

1. **Roll**: Each player rolls dice locally on their User Chain
2. **Commit**: Send `SHA-256(dice || salt)` hash to Game Chain (dice stay private!)
3. **Bid**: Players bid on total dice count across ALL players
4. **Reveal**: After "Liar!" is called, reveal dice + salt for verification
5. **Verify**: Game Chain checks `SHA-256(revealed || salt) == commitment`

This makes cheating **cryptographically impossible** - no one can see or predict your dice.

## 4-Chain Architecture

```
┌─────────────────────────┐
│     MASTER CHAIN        │  Chain Type = 0
│  - Admin operations     │
│  - Global leaderboard   │
│  - Chain registration   │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│     LOBBY CHAIN         │  Chain Type = 1
│  - Matchmaking queue    │
│  - ELO-based pairing    │
│  - Game chain pool      │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│     GAME CHAIN          │  Chain Type = 2
│  - Active game hosting  │
│  - Commitment storage   │
│  - Bid validation       │
│  - Reveal verification  │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│     USER CHAIN          │  Chain Type = 3
│  - PRIVATE dice + salt  │
│  - Player profile       │
│  - ELO rating           │
└─────────────────────────┘
```

## Game Rules

1. Each player starts with **5 dice**
2. All players roll and keep dice hidden
3. Players take turns bidding: *"There are at least N dice showing face X"*
4. Each bid must be **higher** than the previous (quantity or face)
5. Any player can call **"Liar!"** instead of bidding
6. All dice are revealed and verified
7. If bid was valid (enough dice), the caller loses a die
8. If bid was invalid, the previous bidder loses a die
9. Players are eliminated when they lose all dice
10. **Last player standing wins!**

## Quick Start

### Using Docker (Recommended)

```bash
# Build and run with Docker Compose
docker compose up --build
```

This will:
- Build the Linera applications
- Start a local Linera network
- Deploy bankroll and game contracts
- Set up 2 player chains
- Start GraphQL endpoints

### Manual Setup

```bash
# Install Rust 1.86.0
rustup default 1.86.0
rustup target add wasm32-unknown-unknown

# Build
cargo build --release --target wasm32-unknown-unknown

# Run tests
cargo test

# Deploy (requires Linera CLI)
./docker-run.sh
```

## Conway Testnet Deployment

**Live on Conway Testnet** (Deployed: 2026-01-19)

### Application IDs
```
Liar's Dice App:  43abad04f6ec116ad403cca2b42daf335c27f34167b7940d8a3b30cedfe02366
Bankroll App:     88d85033a383a6de20d92c7e86fea226a04e56b9449c16b9d0ec26a60c627188
Master Chain:     cba415cd4111f36b77e9b5b773ad60b143ca942b6d4d9c322995f1c314806ca0
Player A Chain:   69f7a967b9c84365c687681cebbb66ec280aa1fb2ba70cf8b1c241d927dff76e
Player B Chain:   7eaa3a87e06492384c7719c762e34811a809ac3ac34a06fa010455224b407478
```

---

## 🎯 Note to Jurors - Quick Demo (2 Minutes)

**Fastest way to see it working:**

1. **Run Docker:** `docker compose up --build`
2. **Wait ~90 seconds** for "🎲 Liar's Dice is ready!"
3. **Open two browser tabs:**
   - http://localhost:5173 (Player A)
   - http://localhost:5174 (Player B)
4. **Enter names → CREATE PROFILE → CONNECT TO LOBBY → FIND MATCH**
5. **Play a round** - generate dice, commit, bid, call liar!

**What demonstrates Linera's power:**
- 🔗 **4-chain architecture** - Master, Lobby, Game, User chains
- 🔒 **Commit-reveal cryptography** - SHA-256 hidden dice (UNIQUE!)
- ⚡ **Cross-chain messaging** with `.with_tracking()` for reliability
- 🎲 **Cryptographically provable fairness** - no one can cheat

**Innovation Highlight:** This is the only WaveHack submission using **commit-reveal cryptography** where dice exist ONLY on the player's private User Chain until revealed!

---

### Playing the Game

After starting with Docker (wait about 2 minutes for full deployment):

1. Open **Player A** in one browser: http://localhost:5173
2. Open **Player B** in another browser/tab: http://localhost:5174
3. Both players enter a name and click "Create Profile"
4. Both players click "Find Match"
5. Game automatically starts when both players are matched!
6. **Bidding Phase**:
   - The player with the green "YOUR TURN" banner makes a bid
   - Example: "I bid there are at least 3 fives among ALL dice"
   - Each bid must be higher than the previous (more quantity OR same quantity with higher face)
7. **Calling Liar**:
   - Instead of bidding higher, you can call "LIAR!"
   - All dice are revealed and verified cryptographically
   - If the bid was valid, the caller loses a die
   - If the bid was a lie, the bidder loses a die
8. **Winning**:
   - Players are eliminated when they lose all dice
   - Last player standing wins!
   - ELO ratings update automatically

## Project Structure

```
liars-dice/
├── Cargo.toml              # Workspace configuration
├── README.md               # This file
├── Dockerfile              # Container build
├── docker-compose.yml      # Docker Compose config
├── docker-run.sh           # Automated deployment script
├── deploy_apps.sh          # Manual deployment script
│
├── abi/                    # Shared types and logic
│   └── src/
│       ├── lib.rs
│       ├── dice.rs         # DiceValue, PlayerDice, Commitment
│       ├── crypto.rs       # SHA-256 commit-reveal
│       ├── game.rs         # LiarsDiceGame, Bid, GamePhase
│       ├── player.rs       # PlayerProfile, ELO calculations
│       ├── management.rs   # ChainType, GameChainInfo
│       ├── leaderboard.rs  # Ranking metrics
│       └── random.rs       # Deterministic RNG
│
├── bankroll/               # Token economy
│   └── src/
│       ├── lib.rs
│       ├── contract.rs
│       ├── service.rs
│       └── state.rs
│
├── liars_dice/             # Main game application
│   └── src/
│       ├── lib.rs          # Operations, Messages, Events
│       ├── contract.rs     # 4-chain message handlers
│       ├── service.rs      # GraphQL queries
│       └── state.rs        # Multi-chain state views
│
└── frontend/               # Web Frontend
    ├── web_a/              # Player A frontend
    │   └── index.html      # Single-file HTML/JS/CSS
    ├── web_b/              # Player B frontend
    │   └── index.html      # Single-file HTML/JS/CSS
    └── lib/                # Flutter source (reference)
```

## Web Frontend

The HTML/JS frontend provides a polished casino-style UI for playing Liar's Dice.

### Features

- **Lobby Screen**: Profile creation, ELO display, matchmaking
- **Game Screen**: 3D dice display, bidding panel, call liar button
- **Phase-Based UI**: Clear guidance for each game phase
- **Real-time Updates**: Fast polling (500ms) for smooth multiplayer

### Configuration

Frontend configs are auto-generated by `docker-run.sh`:

```json
{
  "nodeServiceURL": "http://localhost:8092",
  "liarsDiceAppId": "<auto-generated>",
  "bankrollAppId": "<auto-generated>",
  "masterChain": "<auto-generated>",
  "lobbyChain": "<auto-generated>",
  "userChain": "<auto-generated>"
}
```

## GraphQL API

### Queries

```graphql
# Get player profile
query { getUserProfile { name elo } }

# Get current game state
query { getGameState {
  gameId
  phase
  round
  currentTurn
  currentBid { quantity face }
  totalDice
  players { name chainId diceCount eliminated }
} }

# Get lobby chain info
query { getLobbyChain }

# Get chain type
query { getChainType }
```

### Mutations

```graphql
# Create/update profile
mutation { setProfile(name: "Alice") }

# Find a match
mutation { findMatch }

# Make a bid
mutation { makeBid(quantity: 3, face: 4) }

# Call liar
mutation { callLiar }

# Commit dice (internal)
mutation { commitDice(commitment: "0x...") }

# Reveal dice (internal)
mutation { revealDice(dice: [1,3,4,5,6], salt: "0x...") }
```

## Ports

| Port | Purpose |
|------|---------|
| 5173 | Player A Web UI |
| 5174 | Player B Web UI |
| 8080 | Faucet |
| 8081 | GraphQL Player A |
| 8082 | GraphQL Player B |
| 8083 | GraphQL Lobby/Master |

## Configuration

Frontend config files are generated at `frontend/web_*/config.json`:

```json
{
  "nodeServiceURL": "http://localhost:8082",
  "liarsDiceAppId": "...",
  "bankrollAppId": "...",
  "masterChain": "...",
  "lobbyChain": "...",
  "userChain": "..."
}
```

---

## 🔗 Linera Integration Deep Dive

This section showcases the **actual Rust code** demonstrating how Liar's Dice leverages Linera's unique features. The commit-reveal cryptography is a **unique innovation** that only works with Linera's microchain architecture.

### 1. Cross-Chain Messaging with Guaranteed Delivery

Every message between chains uses `.with_tracking()` for reliable delivery:

```rust
// From liars_dice/src/contract.rs - Line 1212-1217
fn message_manager(&mut self, destination: ChainId, message: LiarsDiceMessage) {
    self.runtime
        .prepare_message(message)
        .with_tracking()   // Guaranteed delivery
        .send_to(destination);
}
```

**Why This Matters:** Without `.with_tracking()`, dice commitments or reveals could be lost, breaking game integrity.

### 2. Commit-Reveal Cryptography (UNIQUE INNOVATION!)

This is the only WaveHack submission using **cryptographic hidden state**:

```rust
// From abi/src/crypto.rs - Line 7-18
/// Create a commitment hash for dice values
/// commitment = SHA-256(dice_bytes || salt)
pub fn create_commitment(dice_bytes: &[u8], salt: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(dice_bytes);
    hasher.update(salt);
    hasher.finalize().into()
}

/// Verify that a reveal matches a commitment
pub fn verify_commitment(dice_bytes: &[u8], salt: &[u8; 32], commitment: &[u8; 32]) -> bool {
    let computed = create_commitment(dice_bytes, salt);
    computed == *commitment
}
```

**Why This Matters:**
- Dice are **NEVER transmitted** until the reveal phase
- Only the SHA-256 hash is sent to the game chain
- Cheating is **cryptographically impossible**

### 3. Dice Privacy: Exist ONLY on User Chain

The critical security property - dice never leave your private chain:

```rust
// From liars_dice/src/contract.rs - Line 444-464
// Store dice and salt privately (NEVER sent to other chains)
self.state.user_dice.set(Some(player_dice.clone()));
self.state.user_salt.set(Some(salt));

// Create commitment hash = SHA-256(dice_bytes || salt)
let dice_bytes = player_dice.to_bytes();
let commitment_hash = create_commitment(&dice_bytes, &salt);
let dice_commitment = DiceCommitment::new(commitment_hash);

log::info!("Generated dice for user {:?}, sending commitment to game chain", chain_id);

// Send commitment to game chain (only hash, not actual dice!)
if let Some(game_chain) = self.state.user_game_chain.get().as_ref() {
    self.message_manager(
        *game_chain,
        LiarsDiceMessage::CommitDice {
            player_chain: chain_id,
            commitment: dice_commitment,  // ← Only the hash!
        },
    );
}
```

**Why This Matters:** Your dice stay on YOUR chain. The game chain only sees a hash until you reveal.

### 4. Auto-Reveal After "Liar!" Call

When someone calls liar, dice are automatically revealed with verification:

```rust
// From liars_dice/src/contract.rs - Line 478-498
LiarsDiceMessage::LiarCalled { game, caller } => {
    log::info!("Liar called by {:?}", caller);
    self.state.channel_game_state.set(Some(game));

    // AUTO-REVEAL using stored dice and salt
    let chain_id = self.runtime.chain_id();
    if let (Some(dice), Some(salt)) = (
        self.state.user_dice.get().clone(),
        self.state.user_salt.get().clone()
    ) {
        if let Some(game_chain) = self.state.user_game_chain.get().as_ref() {
            let reveal = DiceReveal::new(dice.clone(), salt);
            self.message_manager(
                *game_chain,
                LiarsDiceMessage::RevealDice {
                    player_chain: chain_id,
                    reveal,
                },
            );
            log::info!("Auto-revealed dice for user {:?} to game chain", chain_id);
        }
    }
}
```

### 5. Game Chain Verification

The game chain cryptographically verifies all reveals:

```rust
// From liars_dice/src/contract.rs - Line 896-921
LiarsDiceMessage::RevealDice { player_chain, reveal } => {
    if let Some(player) = game.get_player_mut_by_chain(&player_chain) {
        if let Some(ref mut commitment) = player.commitment {
            let dice_bytes = reveal.dice.to_bytes();
            // Cryptographic verification!
            if verify_commitment(&dice_bytes, &reveal.salt, &commitment.hash) {
                commitment.mark_revealed();
                player.revealed_dice = Some(reveal.dice.clone());
                log::info!("Valid reveal from {:?}", player_chain);

                self.runtime.emit(
                    LIARS_DICE_STREAM_NAME.into(),
                    &LiarsDiceEvent::DiceRevealed { game_id, player, dice },
                );
            } else {
                // CHEATER DETECTED!
                log::error!("CHEATER DETECTED: {:?} - invalid reveal!", player_chain);
                commitment.mark_cheater();
                player.result = abi::game::GameResult::Cheater;
                player.eliminated = true;
            }
        }
    }
}
```

**Why This Matters:** Any attempt to change dice after committing is immediately detected and punished.

### 6. 4-Chain Architecture Instantiation

Each chain type has distinct responsibilities:

```rust
// From liars_dice/src/contract.rs - Line 68-91
match chain_type {
    0 => {
        log::info!("Initialized as MASTER chain");
        // Master handles leaderboard and admin operations
    }
    1 => {
        log::info!("Initialized as LOBBY chain");
        self.state.queue_count.set(0);  // Lobby handles matchmaking
    }
    2 => {
        log::info!("Initialized as GAME chain");
        self.state.game_chain_available.set(true);  // Game hosts active sessions
        self.state.games_hosted.set(0);
    }
    3 => {
        log::info!("Initialized as USER chain");
        self.state.user_balance.set(Amount::ZERO);  // User stores private dice!
    }
    _ => unreachable!(),
}
```

### 7. Real-Time Event Streaming

Events are emitted for instant frontend updates:

```rust
// From liars_dice/src/contract.rs - Line 630-633
self.runtime.emit(
    LIARS_DICE_STREAM_NAME.into(),
    &LiarsDiceEvent::QueueUpdate { players_in_queue: *count },
);

// From liars_dice/src/contract.rs - Line 906-913
self.runtime.emit(
    LIARS_DICE_STREAM_NAME.into(),
    &LiarsDiceEvent::DiceRevealed {
        game_id: game.game_id,
        player: player_chain,
        dice: reveal.dice,
    },
);
```

### Why Linera Cannot Be Removed

1. **Cross-chain state privacy** - Dice exist ONLY on user chains until revealed
2. **Cryptographic verification** - Game chain validates all reveals against commitments
3. **Guaranteed message delivery** - `.with_tracking()` ensures no lost moves
4. **Event streaming** - Real-time updates for multiplayer sync
5. **Scalability** - Each game on its own microchain

**Removing Linera would be impossible** - the entire commit-reveal security model depends on microchains providing private state per player.

---

## Technical Details

- **Rust**: 1.86.0
- **Linera SDK**: 0.15.7
- **Target**: wasm32-unknown-unknown
- **Async Runtime**: Linera (WASM-compatible)
- **Cryptography**: SHA-256 for commitments

## Constants

- `STARTING_ELO = 1200`: Initial ELO rating
- `ELO_K_FACTOR = 32.0`: ELO volatility
- `MAX_PLAYERS = 6`: Max players per game
- `MIN_PLAYERS = 2`: Min players to start
- `STARTING_DICE = 5`: Dice per player
- `REVEAL_TIMEOUT = 60s`: Time to reveal dice

Special thanks to the Linera team for their SDK and documentation.
