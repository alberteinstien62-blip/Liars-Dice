// Chain and room management types for Liar's Dice

use async_graphql::scalar;
use async_graphql_derive::SimpleObject;
use linera_sdk::linera_base_types::{AccountOwner, ChainId, Timestamp};
use serde::{Deserialize, Serialize};

pub type RoomId = u64;

scalar!(ActivityStatus);
#[derive(Debug, Clone, Default, Deserialize, Eq, Ord, PartialOrd, PartialEq, Serialize)]
#[repr(u8)]
pub enum ActivityStatus {
    #[default]
    Active = 0,
    Inactive = 1,
    MaintenanceMode = 2,
}

scalar!(ChainType);
/// Type of chain in the 4-chain architecture
#[derive(Debug, Clone, Default, Deserialize, Eq, Ord, PartialOrd, PartialEq, Serialize)]
#[repr(u8)]
pub enum ChainType {
    #[default]
    Master = 0,
    Lobby = 1,
    Game = 2,
    User = 3,
}

impl ChainType {
    pub fn from_instantiate_value(value: u64) -> Self {
        match value {
            0 => ChainType::Master,
            1 => ChainType::Lobby,
            2 => ChainType::Game,
            3 => ChainType::User,
            _ => ChainType::User, // Default to user chain for unknown values
        }
    }
}

/// Information about a lobby chain
#[derive(Debug, Clone, Default, Deserialize, Eq, PartialEq, Serialize, SimpleObject)]
pub struct LobbyChainInfo {
    pub chain_id: Option<ChainId>,
    pub chain_status: ActivityStatus,
    pub players_in_queue: u32,
    pub games_in_progress: u32,
    pub created_at: Option<Timestamp>,
    pub last_update: Option<Timestamp>,
}

impl LobbyChainInfo {
    pub fn new(chain_id: ChainId, current_time: Timestamp) -> Self {
        LobbyChainInfo {
            chain_id: Some(chain_id),
            chain_status: ActivityStatus::Active,
            players_in_queue: 0,
            games_in_progress: 0,
            created_at: Some(current_time),
            last_update: Some(current_time),
        }
    }

    pub fn update_queue_count(&mut self, count: u32, current_time: Timestamp) {
        self.players_in_queue = count;
        self.last_update = Some(current_time);
    }
}

/// Information about a game chain
#[derive(Debug, Clone, Default, Deserialize, Eq, PartialEq, Serialize, SimpleObject)]
pub struct GameChainInfo {
    pub chain_id: Option<ChainId>,
    pub chain_status: ActivityStatus,
    /// Is this chain currently hosting a game?
    pub in_use: bool,
    /// Current game ID if in use
    pub current_game_id: Option<u64>,
    /// Total games hosted on this chain
    pub games_hosted: u64,
    pub created_at: Option<Timestamp>,
    pub last_update: Option<Timestamp>,
}

impl GameChainInfo {
    pub fn new(chain_id: ChainId, current_time: Timestamp) -> Self {
        GameChainInfo {
            chain_id: Some(chain_id),
            chain_status: ActivityStatus::Active,
            in_use: false,
            current_game_id: None,
            games_hosted: 0,
            created_at: Some(current_time),
            last_update: Some(current_time),
        }
    }

    pub fn start_game(&mut self, game_id: u64, current_time: Timestamp) {
        self.in_use = true;
        self.current_game_id = Some(game_id);
        self.games_hosted += 1;
        self.last_update = Some(current_time);
    }

    pub fn end_game(&mut self, current_time: Timestamp) {
        self.in_use = false;
        self.current_game_id = None;
        self.last_update = Some(current_time);
    }

    pub fn is_available(&self) -> bool {
        !self.in_use && self.chain_status == ActivityStatus::Active
    }
}

scalar!(RoomType);
#[derive(Debug, Clone, Default, Deserialize, Eq, Ord, PartialOrd, PartialEq, Serialize)]
#[repr(u8)]
pub enum RoomType {
    #[default]
    Public = 0,
    Private {
        password_hash: String,
    } = 1,
    Ranked = 2,
}

/// Information about a game room
#[derive(Debug, Clone, Default, Deserialize, Eq, PartialEq, Serialize, SimpleObject)]
pub struct RoomInfo {
    pub room_id: RoomId,
    pub name: String,
    pub room_type: RoomType,
    pub room_status: ActivityStatus,
    /// Game chain assigned to this room
    pub game_chain: Option<ChainId>,
    /// Players currently in this room
    pub player_count: u8,
    /// Maximum players allowed
    pub max_players: u8,
    /// Host/creator of the room
    pub host: Option<AccountOwner>,
    /// Total games played in this room
    pub games_played: u64,
    pub created_at: Option<Timestamp>,
    pub last_update: Option<Timestamp>,
}

impl RoomInfo {
    pub fn new(
        room_id: RoomId,
        name: String,
        room_type: RoomType,
        host: AccountOwner,
        max_players: u8,
        current_time: Timestamp,
    ) -> Self {
        RoomInfo {
            room_id,
            name,
            room_type,
            room_status: ActivityStatus::Active,
            game_chain: None,
            player_count: 1, // Host is first player
            max_players,
            host: Some(host),
            games_played: 0,
            created_at: Some(current_time),
            last_update: Some(current_time),
        }
    }

    pub fn is_joinable(&self) -> bool {
        self.room_status == ActivityStatus::Active && self.player_count < self.max_players
    }

    pub fn add_player(&mut self, current_time: Timestamp) -> bool {
        if !self.is_joinable() {
            return false;
        }
        self.player_count += 1;
        self.last_update = Some(current_time);
        true
    }

    pub fn remove_player(&mut self, current_time: Timestamp) {
        if self.player_count > 0 {
            self.player_count -= 1;
        }
        self.last_update = Some(current_time);
    }

    pub fn assign_game_chain(&mut self, chain_id: ChainId, current_time: Timestamp) {
        self.game_chain = Some(chain_id);
        self.last_update = Some(current_time);
    }

    pub fn game_ended(&mut self, current_time: Timestamp) {
        self.games_played += 1;
        self.game_chain = None;
        self.last_update = Some(current_time);
    }
}
