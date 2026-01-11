// Player profile and ELO rating for Liar's Dice

use async_graphql::scalar;
use async_graphql_derive::SimpleObject;
use linera_sdk::linera_base_types::{AccountOwner, Amount, ChainId, Timestamp};
use serde::{Deserialize, Serialize};

/// Starting ELO rating for new players
pub const STARTING_ELO: u32 = 1200;

/// K-factor for ELO calculations (determines rating volatility)
pub const ELO_K_FACTOR: f64 = 32.0;

scalar!(UserStatus);
/// User status in the system
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub enum UserStatus {
    #[default]
    Idle,
    FindingMatch,
    InQueue,
    InGame {
        game_chain: ChainId,
    },
    SpectatingGame {
        game_chain: ChainId,
    },
}

/// Player profile with stats and ELO
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize, SimpleObject)]
pub struct PlayerProfile {
    pub chain_id: Option<ChainId>,
    pub owner: Option<AccountOwner>,
    pub name: String,
    pub avatar_url: Option<String>,
    /// Current ELO rating
    pub elo: u32,
    /// Lifetime statistics
    pub stats: PlayerLifetimeStats,
    /// Current status
    pub status: UserStatus,
    /// Created at timestamp
    pub created_at: Option<Timestamp>,
    /// Last active timestamp
    pub last_active: Option<Timestamp>,
}

impl PlayerProfile {
    pub fn new(chain_id: ChainId, owner: AccountOwner, name: String, timestamp: Timestamp) -> Self {
        PlayerProfile {
            chain_id: Some(chain_id),
            owner: Some(owner),
            name,
            avatar_url: None,
            elo: STARTING_ELO,
            stats: PlayerLifetimeStats::default(),
            status: UserStatus::Idle,
            created_at: Some(timestamp),
            last_active: Some(timestamp),
        }
    }

    pub fn update_last_active(&mut self, timestamp: Timestamp) {
        self.last_active = Some(timestamp);
    }

    pub fn set_status(&mut self, status: UserStatus) {
        self.status = status;
    }

    /// Update ELO after a match
    /// Returns the ELO change (positive for gain, negative for loss)
    pub fn update_elo_after_match(&mut self, opponent_elo: u32, won: bool) -> i32 {
        let change = calculate_elo_change(self.elo, opponent_elo, won);
        self.elo = (self.elo as i32 + change).max(100) as u32;
        change
    }
}

/// Lifetime statistics for a player
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize, SimpleObject)]
pub struct PlayerLifetimeStats {
    /// Total games played
    pub games_played: u64,
    /// Total games won
    pub games_won: u64,
    /// Total rounds played
    pub rounds_played: u64,
    /// Total rounds won
    pub rounds_won: u64,
    /// Total successful liar calls
    pub successful_liar_calls: u64,
    /// Total failed liar calls
    pub failed_liar_calls: u64,
    /// Total successful bluffs (opponent called liar incorrectly)
    pub successful_bluffs: u64,
    /// Current win streak
    pub current_win_streak: u64,
    /// Best win streak ever
    pub best_win_streak: u64,
    /// Peak ELO achieved
    pub peak_elo: u32,
    /// Total tokens won
    pub total_won: Amount,
    /// Total tokens lost
    pub total_lost: Amount,
}

impl PlayerLifetimeStats {
    pub fn record_game(&mut self, won: bool, rounds: u64) {
        self.games_played += 1;
        self.rounds_played += rounds;

        if won {
            self.games_won += 1;
            self.current_win_streak += 1;
            if self.current_win_streak > self.best_win_streak {
                self.best_win_streak = self.current_win_streak;
            }
        } else {
            self.current_win_streak = 0;
        }
    }

    pub fn record_round_win(&mut self) {
        self.rounds_won += 1;
    }

    pub fn record_liar_call(&mut self, successful: bool) {
        if successful {
            self.successful_liar_calls += 1;
        } else {
            self.failed_liar_calls += 1;
        }
    }

    pub fn record_bluff(&mut self, successful: bool) {
        if successful {
            self.successful_bluffs += 1;
        }
    }

    pub fn update_peak_elo(&mut self, current_elo: u32) {
        if current_elo > self.peak_elo {
            self.peak_elo = current_elo;
        }
    }

    pub fn record_win_loss(&mut self, amount: Amount, won: bool) {
        if won {
            self.total_won = Amount::from_attos(
                self.total_won.to_attos().saturating_add(amount.to_attos())
            );
        } else {
            self.total_lost = Amount::from_attos(
                self.total_lost.to_attos().saturating_add(amount.to_attos())
            );
        }
    }

    /// Calculate win rate as basis points (10000 = 100%)
    pub fn win_rate_bps(&self) -> u64 {
        if self.games_played == 0 {
            0
        } else {
            (self.games_won * 10000) / self.games_played
        }
    }

    /// Calculate liar call accuracy as basis points
    pub fn liar_call_accuracy_bps(&self) -> u64 {
        let total_calls = self.successful_liar_calls + self.failed_liar_calls;
        if total_calls == 0 {
            0
        } else {
            (self.successful_liar_calls * 10000) / total_calls
        }
    }
}

/// Calculate ELO change for a match
/// Uses integer math to avoid WASM-incompatible floating-point operations (powf requires libm)
pub fn calculate_elo_change(player_elo: u32, opponent_elo: u32, won: bool) -> i32 {
    // Use integer-scaled approximation to avoid powf
    // Scale factor: 1000 (so 0.5 = 500, 1.0 = 1000)
    let expected_scaled = expected_score_scaled(player_elo, opponent_elo);
    let actual_scaled: i32 = if won { 1000 } else { 0 };

    // K_FACTOR = 32, calculate: K * (actual - expected) / scale
    let change = (32 * (actual_scaled - expected_scaled)) / 1000;
    change
}

/// Calculate expected score (win probability) scaled by 1000
/// Uses piecewise linear approximation to avoid powf
/// The ELO expected score formula: 1 / (1 + 10^(diff/400))
/// Approximated using lookup points and linear interpolation
fn expected_score_scaled(player_elo: u32, opponent_elo: u32) -> i32 {
    let diff: i32 = opponent_elo as i32 - player_elo as i32;

    // Lookup table: (diff_threshold, expected_score_scaled)
    // Based on actual ELO formula values:
    // diff = -800: expected ≈ 0.99 (990)
    // diff = -400: expected ≈ 0.91 (909)
    // diff = -200: expected ≈ 0.76 (759)
    // diff = -100: expected ≈ 0.64 (640)
    // diff = 0:    expected ≈ 0.50 (500)
    // diff = +100: expected ≈ 0.36 (360)
    // diff = +200: expected ≈ 0.24 (241)
    // diff = +400: expected ≈ 0.09 (91)
    // diff = +800: expected ≈ 0.01 (10)

    if diff <= -800 {
        990
    } else if diff <= -400 {
        // Interpolate between (-800, 990) and (-400, 909)
        909 + ((diff + 400) * (990 - 909)) / 400
    } else if diff <= -200 {
        // Interpolate between (-400, 909) and (-200, 759)
        759 + ((diff + 200) * (909 - 759)) / 200
    } else if diff <= -100 {
        // Interpolate between (-200, 759) and (-100, 640)
        640 + ((diff + 100) * (759 - 640)) / 100
    } else if diff <= 0 {
        // Interpolate between (-100, 640) and (0, 500)
        500 + ((diff) * (640 - 500)) / 100
    } else if diff <= 100 {
        // Interpolate between (0, 500) and (100, 360)
        500 - (diff * (500 - 360)) / 100
    } else if diff <= 200 {
        // Interpolate between (100, 360) and (200, 241)
        360 - ((diff - 100) * (360 - 241)) / 100
    } else if diff <= 400 {
        // Interpolate between (200, 241) and (400, 91)
        241 - ((diff - 200) * (241 - 91)) / 200
    } else if diff <= 800 {
        // Interpolate between (400, 91) and (800, 10)
        91 - ((diff - 400) * (91 - 10)) / 400
    } else {
        10
    }
}

/// Queued player for matchmaking
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, SimpleObject)]
pub struct QueuedPlayer {
    pub chain_id: ChainId,
    pub owner: AccountOwner,
    pub name: String,
    pub elo: u32,
    pub queued_at: Timestamp,
}

impl QueuedPlayer {
    pub fn new(chain_id: ChainId, owner: AccountOwner, name: String, elo: u32, timestamp: Timestamp) -> Self {
        QueuedPlayer {
            chain_id,
            owner,
            name,
            elo,
            queued_at: timestamp,
        }
    }

    /// Calculate ELO distance to another player
    pub fn elo_distance(&self, other: &QueuedPlayer) -> u32 {
        if self.elo > other.elo {
            self.elo - other.elo
        } else {
            other.elo - self.elo
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_elo_calculation() {
        // Player with 1200 ELO wins against 1200 opponent
        // Using integer approximation: expected=500, actual=1000, change=32*(1000-500)/1000=16
        let change = calculate_elo_change(1200, 1200, true);
        assert_eq!(change, 16); // Should gain ~16 ELO

        // Player with 1200 ELO loses against 1200 opponent
        let change = calculate_elo_change(1200, 1200, false);
        assert_eq!(change, -16); // Should lose ~16 ELO

        // Player with 1200 ELO wins against 1400 opponent (upset)
        // diff = 200, expected ≈ 241, change = 32*(1000-241)/1000 = 24
        let change = calculate_elo_change(1200, 1400, true);
        assert!(change >= 20); // Should gain more for upset

        // Player with 1400 ELO loses against 1200 opponent
        // diff = -200, expected ≈ 759, change = 32*(0-759)/1000 = -24
        let change = calculate_elo_change(1400, 1200, false);
        assert!(change <= -20); // Should lose more for upset loss
    }

    #[test]
    fn test_expected_score_scaled() {
        // Equal ELOs should give 50% (500 scaled)
        assert_eq!(expected_score_scaled(1200, 1200), 500);

        // Higher opponent ELO should give lower expected score
        assert!(expected_score_scaled(1200, 1400) < 500);

        // Lower opponent ELO should give higher expected score
        assert!(expected_score_scaled(1400, 1200) > 500);
    }

    #[test]
    fn test_win_rate() {
        let mut stats = PlayerLifetimeStats::default();
        stats.games_played = 100;
        stats.games_won = 60;

        assert_eq!(stats.win_rate_bps(), 6000); // 60%
    }
}
