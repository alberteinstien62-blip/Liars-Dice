// Leaderboard types for Liar's Dice

use crate::player::PlayerLifetimeStats;
use async_graphql::scalar;
use async_graphql_derive::SimpleObject;
use linera_sdk::linera_base_types::{Amount, ChainId};
use serde::{Deserialize, Serialize};

scalar!(RankingMetric);
#[derive(Debug, Clone, Default, Deserialize, Eq, Ord, PartialOrd, PartialEq, Serialize)]
pub enum RankingMetric {
    /// ELO rating (primary ranking)
    #[default]
    Elo,
    /// Net profit using composite ranking
    NetProfit,
    /// Total winnings
    TotalWinnings,
    /// Win rate in basis points
    WinRate,
    /// Total games played
    GamesPlayed,
    /// Current win streak
    CurrentStreak,
    /// Successful liar calls percentage
    LiarCallAccuracy,
}

/// Offset used for composite ranking of profit/loss values.
const RANKING_MIDPOINT: u128 = 1u128 << 127;

impl RankingMetric {
    /// Calculate the metric value for ranking purposes.
    pub fn calculate_value(&self, stats: &PlayerLifetimeStats, elo: u32) -> u128 {
        match self {
            RankingMetric::Elo => elo as u128,
            RankingMetric::NetProfit => {
                let won_attos = stats.total_won.to_attos();
                let lost_attos = stats.total_lost.to_attos();

                if won_attos >= lost_attos {
                    let profit = won_attos.saturating_sub(lost_attos);
                    RANKING_MIDPOINT.saturating_add(profit)
                } else {
                    let loss = lost_attos.saturating_sub(won_attos);
                    (RANKING_MIDPOINT - 1).saturating_sub(loss)
                }
            }
            RankingMetric::TotalWinnings => stats.total_won.to_attos(),
            RankingMetric::WinRate => stats.win_rate_bps() as u128,
            RankingMetric::GamesPlayed => stats.games_played as u128,
            RankingMetric::CurrentStreak => stats.current_win_streak as u128,
            RankingMetric::LiarCallAccuracy => stats.liar_call_accuracy_bps() as u128,
        }
    }
}

/// A single entry in the leaderboard
#[derive(Debug, Clone, Default, Deserialize, Eq, Ord, PartialOrd, PartialEq, Serialize, SimpleObject)]
pub struct LeaderboardEntry {
    pub player_id: Option<ChainId>,
    pub player_name: String,
    pub rank: u32,
    pub metric_type: RankingMetric,

    // ELO info
    pub elo: u32,
    pub peak_elo: u32,

    // Win/Loss info
    pub games_played: u64,
    pub games_won: u64,
    pub win_rate: u64, // Basis points (0-10000)

    // Net profit as (amount, is_profit) tuple
    pub net_profit_amount: Amount,
    pub is_profit: bool,

    // Liar's Dice specific stats
    pub successful_liar_calls: u64,
    pub liar_call_accuracy: u64, // Basis points
    pub successful_bluffs: u64,
    pub current_streak: u64,
    pub best_streak: u64,
}

/// Calculate net profit tuple from stats
fn calculate_net_profit_tuple(stats: &PlayerLifetimeStats) -> (u128, bool) {
    let won_attos = stats.total_won.to_attos();
    let lost_attos = stats.total_lost.to_attos();

    if won_attos >= lost_attos {
        (won_attos - lost_attos, true)
    } else {
        (lost_attos - won_attos, false)
    }
}

/// Calculate a ranked leaderboard from player data
///
/// # Arguments
/// * `player_data` - Vec of (ChainId, name, elo, PlayerLifetimeStats) tuples
/// * `metric` - The ranking metric to use
/// * `limit` - Maximum number of entries to return (0 = unlimited)
///
/// # Returns
/// Vec of LeaderboardEntry sorted by rank (1 = best)
pub fn calculate_ranking(
    player_data: Vec<(ChainId, String, u32, PlayerLifetimeStats)>,
    metric: RankingMetric,
    limit: usize,
) -> Vec<LeaderboardEntry> {
    // Calculate metric values
    let mut entries: Vec<(ChainId, String, u32, PlayerLifetimeStats, u128)> = player_data
        .into_iter()
        .map(|(chain_id, name, elo, stats)| {
            let metric_value = metric.calculate_value(&stats, elo);
            (chain_id, name, elo, stats, metric_value)
        })
        .collect();

    // Sort by metric value (descending)
    entries.sort_by(|a, b| b.4.cmp(&a.4));

    // Apply limit
    if limit > 0 && entries.len() > limit {
        entries.truncate(limit);
    }

    // Convert to leaderboard entries
    entries
        .into_iter()
        .enumerate()
        .map(|(idx, (player_id, player_name, elo, stats, _))| {
            let (net_profit_amount, is_profit) = calculate_net_profit_tuple(&stats);

            LeaderboardEntry {
                player_id: Some(player_id),
                player_name,
                rank: (idx + 1) as u32,
                metric_type: metric.clone(),
                elo,
                peak_elo: stats.peak_elo,
                games_played: stats.games_played,
                games_won: stats.games_won,
                win_rate: stats.win_rate_bps(),
                net_profit_amount: Amount::from_attos(net_profit_amount),
                is_profit,
                successful_liar_calls: stats.successful_liar_calls,
                liar_call_accuracy: stats.liar_call_accuracy_bps(),
                successful_bluffs: stats.successful_bluffs,
                current_streak: stats.current_win_streak,
                best_streak: stats.best_win_streak,
            }
        })
        .collect()
}

/// Simple leaderboard for event updates (lighter weight)
#[derive(Debug, Clone, Default, Deserialize, Eq, PartialEq, Serialize, SimpleObject)]
pub struct SimpleLeaderboardEntry {
    pub player_id: Option<ChainId>,
    pub player_name: String,
    pub rank: u32,
    pub elo: u32,
    pub games_won: u64,
    pub games_played: u64,  // ✅ FIX: Track total games for proper win_rate calculation
    pub win_rate: u64,
}

pub fn calculate_simple_ranking(
    player_data: Vec<(ChainId, String, u32, u64, u64)>, // (chain_id, name, elo, games_won, games_played)
    limit: usize,
) -> Vec<SimpleLeaderboardEntry> {
    let mut entries: Vec<_> = player_data
        .into_iter()
        .map(|(chain_id, name, elo, games_won, games_played)| {
            let win_rate = if games_played == 0 {
                0
            } else {
                (games_won * 10000) / games_played
            };
            (chain_id, name, elo, games_won, games_played, win_rate)
        })
        .collect();

    // Sort by ELO descending
    entries.sort_by(|a, b| b.2.cmp(&a.2));

    if limit > 0 && entries.len() > limit {
        entries.truncate(limit);
    }

    entries
        .into_iter()
        .enumerate()
        .map(|(idx, (player_id, player_name, elo, games_won, games_played, win_rate))| {
            SimpleLeaderboardEntry {
                player_id: Some(player_id),
                player_name,
                rank: (idx + 1) as u32,
                elo,
                games_won,
                games_played,
                win_rate,
            }
        })
        .collect()
}
