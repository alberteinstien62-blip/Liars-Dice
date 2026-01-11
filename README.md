# Liar's Dice on Linera

A decentralized, provably fair implementation of the classic bluffing dice game **Liar's Dice** built on the [Linera](https://linera.io) blockchain platform.

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

## License

MIT License - See LICENSE file for details.

## Acknowledgments

Built for the **WaveHack Linera Buildathon 2025**.

Special thanks to the Linera team for their SDK and documentation.
