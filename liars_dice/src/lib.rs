// Liar's Dice - Main game contract ABI
// 4-Chain Architecture: Master (0), Lobby (1), Game (2), User (3)

use abi::dice::{DiceCommitment, DiceReveal, PlayerDice};
use abi::game::{Bid, GameId, LiarsDiceGame};
use abi::leaderboard::SimpleLeaderboardEntry;
// Note: GameChainInfo, LobbyChainInfo used in state.rs
use abi::player::{PlayerProfile, QueuedPlayer};
use async_graphql::{Request, Response};
use bankroll::BankrollAbi;
use linera_sdk::linera_base_types::{Amount, ApplicationId, ChainId, Timestamp};
use linera_sdk::{
    graphql::GraphQLMutationRoot,
    linera_base_types::{ContractAbi, ServiceAbi},
};
use serde::{Deserialize, Serialize};

/// Stream name for game events
pub const LIARS_DICE_STREAM_NAME: &[u8] = b"liars_dice";

#[derive(Debug, Deserialize, Serialize)]
pub struct LiarsDiceAbi;

impl ContractAbi for LiarsDiceAbi {
    type Operation = LiarsDiceOperation;
    type Response = ();
}

impl ServiceAbi for LiarsDiceAbi {
    type Query = Request;
    type QueryResponse = Response;
}

/// Operations that can be called on the contract
#[derive(Debug, Deserialize, Serialize, GraphQLMutationRoot)]
pub enum LiarsDiceOperation {
    // ============================================
    // USER CHAIN OPERATIONS (instantiate_value = 3)
    // ============================================
    /// Set or update player profile
    SetProfile { name: String },
    /// Find a match through the lobby
    FindMatch {},
    /// Cancel matchmaking
    CancelMatch {},
    /// Commit dice for the current round (sends hash to game chain)
    CommitDice { commitment: [u8; 32] },
    /// Reveal dice after liar is called
    RevealDice { dice: Vec<u8>, salt: [u8; 32] },
    /// Make a bid
    MakeBid { quantity: u8, face: u8 },
    /// Call "Liar!" on the previous bidder
    CallLiar {},
    /// Exit current game
    ExitGame {},
    /// Get balance from bankroll
    GetBalance {},
    /// Initial setup - subscribe to lobby
    InitialSetup {},

    // ============================================
    // LOBBY CHAIN OPERATIONS (instantiate_value = 1)
    // ============================================
    // (Lobby chain receives messages, not direct operations)

    // ============================================
    // GAME CHAIN OPERATIONS (instantiate_value = 2)
    // ============================================
    /// Check for reveal timeout and eliminate non-revealers (can be called by anyone)
    CheckTimeout {},

    // ============================================
    // MASTER CHAIN OPERATIONS (instantiate_value = 0)
    // ============================================
    /// Add a new lobby chain (admin only)
    AddLobbyChain { chain_id: ChainId },
    /// Add a new game chain to the pool (admin only)
    AddGameChain { chain_id: ChainId },
    /// Mint tokens for a chain (admin only)
    MintToken { chain_id: ChainId, amount: Amount },
}

/// Cross-chain messages
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum LiarsDiceMessage {
    // ============================================
    // SUBSCRIPTION CONTROL (Universal)
    // ============================================
    /// Request to subscribe to events from this chain
    Subscribe,
    /// Request to unsubscribe from events
    Unsubscribe,

    // ============================================
    // TO USER CHAIN
    // ============================================
    /// Match has been found, game is starting
    MatchFound {
        game_chain: ChainId,
        game_id: GameId,
        opponent_name: String,
        opponent_elo: u32,
    },
    /// Game has started, commit your dice
    GameStarted { game: LiarsDiceGame },
    /// A bid was made
    BidMade { game: LiarsDiceGame, bidder: ChainId, bid: Bid },
    /// Someone called liar - reveal your dice
    LiarCalled { game: LiarsDiceGame, caller: ChainId },
    /// Reveal required (timeout warning)
    RevealRequired { deadline: Timestamp },
    /// Round result
    RoundResult {
        game: LiarsDiceGame,
        loser: ChainId,
        actual_count: u8,
        bid_was_valid: bool,
    },
    /// Game is over
    GameResult {
        game: LiarsDiceGame,
        winner: ChainId,
        loser: ChainId,
        elo_change: i32,
    },
    /// Profile update confirmation
    ProfileUpdated { profile: PlayerProfile },
    /// Lobby chain info for subscription
    LobbyInfo { lobby_chain: ChainId },

    // ============================================
    // TO LOBBY CHAIN
    // ============================================
    /// Player wants to find a match
    FindMatch { player: QueuedPlayer },
    /// Player wants to cancel matchmaking
    CancelMatch { player_chain: ChainId },
    /// Game has ended, return game chain to pool
    GameEnded {
        game_chain: ChainId,
        winner: ChainId,
        loser: ChainId,
    },
    /// Register a new game chain
    RegisterGameChain { chain_id: ChainId },

    // ============================================
    // TO GAME CHAIN
    // ============================================
    /// Assign players to this game chain
    AssignMatch {
        game_id: GameId,
        player1: QueuedPlayer,
        player2: QueuedPlayer,
    },
    /// Player commits their dice (hash only)
    CommitDice {
        player_chain: ChainId,
        commitment: DiceCommitment,
    },
    /// Player makes a bid
    MakeBid {
        player_chain: ChainId,
        bid: Bid,
    },
    /// Player calls liar
    CallLiar { player_chain: ChainId },
    /// Player reveals their dice
    RevealDice {
        player_chain: ChainId,
        reveal: DiceReveal,
    },
    /// Player exits/forfeits
    PlayerForfeit { player_chain: ChainId },

    // ============================================
    // TO MASTER CHAIN
    // ============================================
    /// Request lobby chain info
    RequestLobbyInfo { user_chain: ChainId },
    /// Update leaderboard with game result
    UpdateLeaderboard {
        winner: ChainId,
        winner_name: String,
        winner_new_elo: u32,
        loser: ChainId,
        loser_name: String,
        loser_new_elo: u32,
    },
}

/// Application parameters
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct LiarsDiceParameters {
    /// Master chain for admin operations
    pub master_chain: ChainId,
    /// Lobby chain for matchmaking
    pub lobby_chain: ChainId,
    /// Bankroll application for token management
    pub bankroll: ApplicationId<BankrollAbi>,
}

/// Events emitted for real-time updates
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum LiarsDiceEvent {
    /// Game state update (sent to subscribers)
    GameState { game: LiarsDiceGame },
    /// Matchmaking queue update
    QueueUpdate { players_in_queue: u32 },
    /// Leaderboard update
    LeaderboardUpdate { entries: Vec<SimpleLeaderboardEntry> },
    /// Player profile update
    ProfileUpdate { profile: PlayerProfile },
    /// Bid made in game
    BidUpdate { game_id: GameId, bid: Bid },
    /// Liar called
    LiarCalledEvent { game_id: GameId, caller: ChainId },
    /// Dice revealed
    DiceRevealed {
        game_id: GameId,
        player: ChainId,
        dice: PlayerDice,
    },
    /// Round ended
    RoundEnded {
        game_id: GameId,
        loser: ChainId,
        round: u32,
    },
    /// Game ended
    GameEnded {
        game_id: GameId,
        winner: ChainId,
        loser: ChainId,
    },
}
