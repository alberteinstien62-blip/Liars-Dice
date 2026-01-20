# Liars Dice Demo Video Script

**Duration**: 3-5 minutes
**Target**: Wave 6 judges

## Equipment Setup
- OBS Studio or QuickTime Screen Recording
- 1080p resolution minimum
- Split screen: Terminal (left 40%) + Browser (right 60%)
- Clear audio narration

---

## Script (Narrate while showing actions)

### 00:00-00:30 - Introduction
**Visual**: Show project README on GitHub
**Narration**:
"This is Liars Dice - a fully decentralized implementation of the classic bluffing dice game, built on Linera microchains. What makes this unique is our commit-reveal cryptographic scheme that ensures fair play without trusted third parties."

**Show on screen**:
- Project title
- GitHub repository URL
- Conway Testnet App ID

### 00:30-01:15 - Architecture & Cryptography
**Visual**: Show architecture diagram from README
**Narration**:
"Liars Dice uses a sophisticated 4-chain architecture with commit-reveal cryptography:

1. Master Chain: Global configuration and bankroll management
2. Lobby Chain: Game matchmaking and room creation
3. Game Chains: Individual game instances with commit-reveal logic
4. User Chains: Player-specific state and dice rolls

The commit-reveal scheme prevents cheating:
- Phase 1: Players roll dice and commit a hash (SHA-256)
- Phase 2: Players reveal their actual rolls
- Game validates reveals against commitments
- No player can see others' dice until all commits are in

This is provably fair gaming on the blockchain."

**Highlight**: Show commit-reveal flow diagram

### 01:15-02:00 - Docker Startup & Deployment
**Visual**: Switch to terminal
**Narration**:
"Starting the game is simple with Docker and our Conway testnet deployment."

**Terminal commands**:
```bash
docker compose up
```

**Show**:
- Services starting
- Node running on port 8080
- Frontend on port 5173

**Narration while starting**:
"Deployed to Conway Testnet:
- App ID: [INSERT APP ID]
- Bankroll App ID: [INSERT BANKROLL ID]
- Master Chain: [INSERT CHAIN ID]

This is a real blockchain deployment with on-chain game state."

### 02:00-02:30 - Wallet Connection & Bankroll
**Visual**: Switch to browser at localhost:5173
**Narration**:
"Let's connect and get some chips from the bankroll."

**Actions**:
1. Click "Connect Wallet"
2. Approve wallet connection
3. Show wallet address connected
4. Click "Get Free Chips" (if available)
5. Show balance updating

**Narration**:
"The bankroll contract manages the chip economy across all games. Players can get starter chips and win more by playing."

### 02:30-04:00 - Gameplay Demonstration
**Visual**: Play a full round of Liars Dice
**Narration**:
"Let's play a game to demonstrate the commit-reveal flow."

**Actions**:
1. Click "Create Game" or "Join Game"
2. Wait for opponent (or show two browser windows)
3. **Commit Phase**:
   - Click "Roll Dice" (generates random roll + commits hash)
   - Show "Waiting for other players to commit..."
   - Show commitment hash displayed
4. **Reveal Phase**:
   - Click "Reveal Dice"
   - Show dice revealed
   - Show other player's dice revealed
5. **Bidding Phase**:
   - Make a bid (e.g., "Three 4s")
   - Show bid options in UI
   - Opponent calls "Liar" or raises bid
6. **Resolution**:
   - Show dice count verification
   - Show winner announcement
   - Show chip transfer

**Narration during gameplay**:
"Watch the commit-reveal process:
1. First, both players commit their dice rolls as cryptographic hashes
2. Once both commits are in, players reveal their actual rolls
3. The game validates each reveal matches its commitment
4. Then bidding begins with all information transparent but fair

Every step is a cross-chain message verified on-chain. No centralized server, no trust required."

### 04:00-04:30 - Technical Highlights
**Visual**: Open browser DevTools
**Narration**:
"Let me show you the technical implementation."

**Show**:
1. Network tab: GraphQL subscriptions for game events
2. Console: Commit-reveal logs showing hashes
3. Application tab: No localStorage/sessionStorage
4. Show game state updates in real-time

**Narration**:
"All game state is on-chain:
- Commits stored as SHA-256 hashes
- Reveals validated cryptographically
- Bids tracked with timestamps
- All state persists across page refresh because it's blockchain state
- Zero localStorage per Wave 6 requirements"

### 04:30-05:00 - Conclusion
**Visual**: Show README with deployment info
**Narration**:
"Liars Dice demonstrates:
- Commit-reveal cryptography for fair play
- 4-chain architecture for scalability
- Real-time cross-chain game logic
- Production-ready code with comprehensive testing

Conway Testnet:
- App ID: [INSERT APP ID]
- Bankroll App ID: [INSERT BANKROLL ID]

GitHub: [REPOSITORY URL]
Built with Linera SDK 0.15.7

Thank you for watching!"

---

## Post-Recording Checklist
- [ ] Video is 3-5 minutes long
- [ ] Commit-reveal flow clearly demonstrated
- [ ] Full game round shown (commit → reveal → bid → resolution)
- [ ] Cryptographic hashes visible
- [ ] App IDs shown clearly
- [ ] No localStorage in DevTools
- [ ] Video uploaded to YouTube
- [ ] YouTube link added to README

---

## YouTube Video Details

**Title**: Liars Dice - Provably Fair Blockchain Gaming | Wave 6 Linera Buildathon

**Description**:
Liars Dice - A decentralized implementation of the classic bluffing dice game with commit-reveal cryptography, built on Linera microchains.

🔗 Conway Testnet:
- App ID: [INSERT]
- Bankroll App ID: [INSERT]
- Master Chain: [INSERT]

📁 GitHub: [REPOSITORY URL]
⚡ Built with Linera SDK 0.15.7

Features:
✅ Commit-reveal cryptography (SHA-256)
✅ 4-chain architecture (Master/Lobby/Game/User)
✅ Provably fair gaming
✅ On-chain game state
✅ Real-time cross-chain messaging
✅ Zero localStorage/sessionStorage
✅ Bankroll contract for chip economy
✅ Docker one-command setup

Wave 6 Linera Buildathon submission.

**Tags**: linera, blockchain-gaming, commit-reveal, cryptography, microchains, web3, dice, buildathon, fairplay

**Thumbnail**: Screenshot of dice with "Commit-Reveal" text and Linera logo
