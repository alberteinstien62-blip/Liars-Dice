#![cfg_attr(target_arch = "wasm32", no_main)]

mod state;

use std::sync::Arc;

use abi::dice::PlayerDice;
use abi::game::LiarsDiceGame;
use abi::leaderboard::SimpleLeaderboardEntry;
use abi::player::PlayerProfile;
use async_graphql::{EmptySubscription, Object, Schema};
use liars_dice::LiarsDiceOperation;
use linera_sdk::linera_base_types::ChainId;
use linera_sdk::{
    graphql::GraphQLMutationRoot, linera_base_types::WithServiceAbi, views::View, Service,
    ServiceRuntime,
};

use self::state::LiarsDiceState;

pub struct LiarsDiceService {
    state: Arc<LiarsDiceState>,
    runtime: Arc<ServiceRuntime<Self>>,
}

linera_sdk::service!(LiarsDiceService);

impl WithServiceAbi for LiarsDiceService {
    type Abi = liars_dice::LiarsDiceAbi;
}

impl Service for LiarsDiceService {
    type Parameters = ();

    async fn new(runtime: ServiceRuntime<Self>) -> Self {
        let state = LiarsDiceState::load(runtime.root_view_storage_context())
            .await
            .expect("Failed to load state");
        LiarsDiceService {
            state: Arc::new(state),
            runtime: Arc::new(runtime),
        }
    }

    async fn handle_query(&self, query: Self::Query) -> Self::QueryResponse {
        Schema::build(
            QueryRoot {
                state: self.state.clone(),
                runtime: self.runtime.clone(),
            },
            LiarsDiceOperation::mutation_root(self.runtime.clone()),
            EmptySubscription,
        )
        .finish()
        .execute(query)
        .await
    }
}

#[allow(dead_code)]
struct QueryRoot {
    state: Arc<LiarsDiceState>,
    runtime: Arc<ServiceRuntime<LiarsDiceService>>,
}

#[Object]
impl QueryRoot {
    /// Get the chain type (0=Master, 1=Lobby, 2=Game, 3=User)
    async fn get_chain_type(&self) -> u64 {
        *self.state.chain_type.get()
    }

    // ============================================
    // USER CHAIN QUERIES
    // ============================================

    /// Get the user's profile
    async fn get_user_profile(&self) -> Option<PlayerProfile> {
        self.state.user_profile.get().clone()
    }

    /// Get the user's dice (only available on user chain, used for reveal)
    async fn get_user_dice(&self) -> Option<PlayerDice> {
        self.state.user_dice.get().clone()
    }

    /// Get the user's salt (only available on user chain, used for reveal)
    async fn get_user_salt(&self) -> Option<Vec<u8>> {
        self.state.user_salt.get().map(|s| s.to_vec())
    }

    /// Get the current game state (from subscription)
    async fn get_game_state(&self) -> Option<LiarsDiceGame> {
        self.state.channel_game_state.get().clone()
    }

    /// Get the lobby chain ID
    async fn get_lobby_chain(&self) -> Option<ChainId> {
        *self.state.lobby_chain.get()
    }

    /// Get the user's current game chain
    async fn get_user_game_chain(&self) -> Option<ChainId> {
        *self.state.user_game_chain.get()
    }

    // ============================================
    // LOBBY CHAIN QUERIES
    // ============================================

    /// Get the number of players in matchmaking queue
    async fn get_queue_count(&self) -> u32 {
        *self.state.queue_count.get()
    }

    // ============================================
    // GAME CHAIN QUERIES
    // ============================================

    /// Get the current game on this game chain
    async fn get_current_game(&self) -> Option<LiarsDiceGame> {
        self.state.current_game.get().clone()
    }

    /// Check if this game chain is available
    async fn is_game_chain_available(&self) -> bool {
        *self.state.game_chain_available.get()
    }

    /// Get total games hosted on this chain
    async fn get_games_hosted(&self) -> u64 {
        *self.state.games_hosted.get()
    }

    // ============================================
    // MASTER CHAIN QUERIES
    // ============================================

    /// Get all leaderboard entries
    async fn get_leaderboard(&self) -> Vec<SimpleLeaderboardEntry> {
        let keys = self
            .state
            .leaderboard
            .indices()
            .await
            .expect("Failed to get leaderboard keys");

        let mut entries = Vec::new();
        for key in keys {
            if let Some(entry) = self
                .state
                .leaderboard
                .get(&key)
                .await
                .expect("Failed to get leaderboard entry")
            {
                entries.push(entry);
            }
        }

        // Sort by rank
        entries.sort_by(|a, b| a.rank.cmp(&b.rank));
        entries
    }

    /// Get registered player count
    async fn get_registered_player_count(&self) -> u64 {
        self.state
            .registered_players
            .indices()
            .await
            .expect("Failed to count players")
            .len() as u64
    }
}
