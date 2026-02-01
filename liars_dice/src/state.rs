// Liar's Dice state management
// Multi-chain state: Master (0), Lobby (1), Game (2), User (3)

use abi::dice::PlayerDice;
use abi::game::LiarsDiceGame;
use abi::leaderboard::SimpleLeaderboardEntry;
use abi::management::{GameChainInfo, LobbyChainInfo};
use abi::player::{PlayerProfile, QueuedPlayer};
use bankroll::BankrollAbi;
use linera_sdk::linera_base_types::{Amount, ApplicationId, ChainId};
use linera_sdk::views::{linera_views, MapView, QueueView, RegisterView, RootView, ViewStorageContext};

#[derive(RootView, async_graphql::SimpleObject)]
#[view(context = ViewStorageContext)]
pub struct LiarsDiceState {
    // ============================================
    // ALL CHAINS - Common state
    // ============================================
    /// Current chain type (set during instantiation)
    pub chain_type: RegisterView<u64>,

    // ============================================
    // MASTER CHAIN STATE (instantiate_value = 0)
    // ============================================
    /// Registered lobby chains
    pub lobby_chains: MapView<ChainId, LobbyChainInfo>,
    /// Global leaderboard entries
    pub leaderboard: MapView<ChainId, SimpleLeaderboardEntry>,
    /// All registered player profiles (for global lookups)
    pub registered_players: MapView<ChainId, PlayerProfile>,

    // ============================================
    // LOBBY CHAIN STATE (instantiate_value = 1)
    // ============================================
    /// Matchmaking queue
    pub matchmaking_queue: QueueView<QueuedPlayer>,
    /// Available game chains pool
    pub available_game_chains: QueueView<ChainId>,
    /// Game chains currently in use
    pub active_game_chains: MapView<ChainId, GameChainInfo>,
    /// Queue count for quick access
    pub queue_count: RegisterView<u32>,

    // ============================================
    // GAME CHAIN STATE (instantiate_value = 2)
    // ============================================
    /// Current active game on this chain
    pub current_game: RegisterView<Option<LiarsDiceGame>>,
    /// Players in current game (chain_id -> index)
    pub game_players: MapView<ChainId, u8>,
    /// Is this game chain available?
    pub game_chain_available: RegisterView<bool>,
    /// Total games hosted on this chain
    pub games_hosted: RegisterView<u64>,

    // ============================================
    // USER CHAIN STATE (instantiate_value = 3)
    // ============================================
    /// User's profile
    pub user_profile: RegisterView<Option<PlayerProfile>>,
    /// User's private dice (NEVER sent to other chains - only hash)
    pub user_dice: RegisterView<Option<PlayerDice>>,
    /// User's private salt (NEVER sent to other chains)
    pub user_salt: RegisterView<Option<[u8; 32]>>,
    /// Current game chain user is connected to
    pub user_game_chain: RegisterView<Option<ChainId>>,
    /// Current lobby chain
    pub lobby_chain: RegisterView<Option<ChainId>>,
    /// User's token balance (cached from bankroll)
    pub user_balance: RegisterView<Amount>,
    /// Last received game state (from event subscription)
    pub channel_game_state: RegisterView<Option<LiarsDiceGame>>,
    /// Private nonce for RNG entropy (incremented each dice generation)
    #[graphql(skip)]
    pub rng_nonce: RegisterView<u64>,

    // ============================================
    // PARAMETERS (ALL CHAINS) - Cached to avoid runtime.application_parameters() in Linera 0.15.7
    // ============================================
    /// Cached master chain ID
    #[graphql(skip)]
    pub cached_master_chain: RegisterView<Option<ChainId>>,
    /// Cached bankroll application ID
    #[graphql(skip)]
    pub cached_bankroll: RegisterView<Option<ApplicationId<BankrollAbi>>>,
    /// Cached lobby chain ID
    #[graphql(skip)]
    pub cached_lobby_chain: RegisterView<Option<ChainId>>,
}
