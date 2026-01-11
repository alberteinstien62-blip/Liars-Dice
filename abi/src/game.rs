// Game state and bid types for Liar's Dice

use crate::dice::{DiceCommitment, DiceValue, PlayerDice};
use async_graphql::scalar;
use async_graphql_derive::SimpleObject;
use linera_sdk::linera_base_types::{AccountOwner, ChainId, Timestamp};
use serde::{Deserialize, Serialize};

pub type GameId = u64;

/// A bid in Liar's Dice: "I bet there are at least N dice showing face X"
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize, SimpleObject)]
pub struct Bid {
    /// How many dice of the given face
    pub quantity: u8,
    /// The face value being bid
    pub face: DiceValue,
    /// Who made this bid
    pub bidder: Option<ChainId>,
    /// When the bid was made
    pub timestamp: Option<Timestamp>,
}

impl Bid {
    pub fn new(quantity: u8, face: DiceValue, bidder: ChainId, timestamp: Timestamp) -> Self {
        Bid {
            quantity,
            face,
            bidder: Some(bidder),
            timestamp: Some(timestamp),
        }
    }

    /// Check if this bid is higher than another (valid raise)
    /// A bid is higher if:
    /// 1. Quantity is higher, OR
    /// 2. Same quantity but higher face value
    pub fn is_higher_than(&self, other: &Bid) -> bool {
        if self.quantity > other.quantity {
            return true;
        }
        if self.quantity == other.quantity && self.face > other.face {
            return true;
        }
        false
    }

    /// Check if this is a valid first bid
    pub fn is_valid_initial(&self) -> bool {
        self.quantity >= 1 && self.face.value() >= 1 && self.face.value() <= 6
    }
}

scalar!(GamePhase);
/// The current phase of the game
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub enum GamePhase {
    #[default]
    /// Waiting for players to join
    WaitingForPlayers,
    /// Waiting for all players to commit their dice
    Committing,
    /// Active bidding phase
    Bidding,
    /// Someone called liar, waiting for reveals
    Revealing,
    /// Round ended, determining loser
    RoundEnd,
    /// Game is over
    GameOver,
}

scalar!(GameResult);
/// The result of a game for a player
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub enum GameResult {
    #[default]
    Pending,
    Won,
    Lost,
    /// Player was caught cheating (invalid reveal)
    Cheater,
    /// Player timed out during reveal
    TimedOut,
}

/// Information about a player in a game
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize, SimpleObject)]
pub struct GamePlayer {
    pub chain_id: Option<ChainId>,
    pub owner: Option<AccountOwner>,
    pub name: String,
    /// Player's ELO rating (preserved from matchmaking)
    pub elo: u32,
    /// Commitment hash (public during game)
    pub commitment: Option<DiceCommitment>,
    /// Revealed dice (only set after reveal phase)
    pub revealed_dice: Option<PlayerDice>,
    /// Current dice count (public info - how many dice left)
    pub dice_count: u8,
    /// Is this player eliminated?
    pub eliminated: bool,
    /// Is this player's turn?
    pub is_turn: bool,
    /// Result of the game for this player
    pub result: GameResult,
}

impl GamePlayer {
    pub fn new(chain_id: ChainId, owner: AccountOwner, name: String, elo: u32) -> Self {
        GamePlayer {
            chain_id: Some(chain_id),
            owner: Some(owner),
            name,
            elo,
            commitment: None,
            revealed_dice: None,
            dice_count: PlayerDice::STARTING_DICE,
            eliminated: false,
            is_turn: false,
            result: GameResult::Pending,
        }
    }

    pub fn set_commitment(&mut self, commitment: DiceCommitment) {
        self.commitment = Some(commitment);
    }

    pub fn set_revealed(&mut self, dice: PlayerDice) {
        self.dice_count = dice.count;
        self.revealed_dice = Some(dice);
        if let Some(ref mut c) = self.commitment {
            c.mark_revealed();
        }
    }

    pub fn lose_die(&mut self) {
        if self.dice_count > 0 {
            self.dice_count -= 1;
        }
        if self.dice_count == 0 {
            self.eliminated = true;
            self.result = GameResult::Lost;
        }
    }
}

/// The complete state of a Liar's Dice game
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize, SimpleObject)]
pub struct LiarsDiceGame {
    pub game_id: GameId,
    pub players: Vec<GamePlayer>,
    pub phase: GamePhase,
    /// Current round number (1-indexed)
    pub round: u32,
    /// Index of player whose turn it is
    pub current_turn: u8,
    /// History of bids in current round
    pub bid_history: Vec<Bid>,
    /// The current (highest) bid
    pub current_bid: Option<Bid>,
    /// Who called "Liar!" (if in reveal phase)
    pub liar_caller: Option<ChainId>,
    /// Total dice in play (sum of all players' dice counts)
    pub total_dice: u8,
    /// Reveal deadline timestamp (for timeout handling)
    pub reveal_deadline: Option<Timestamp>,
    /// Winner of the game
    pub winner: Option<ChainId>,
    /// When the game started
    pub started_at: Option<Timestamp>,
    /// When the game ended
    pub ended_at: Option<Timestamp>,
}

impl LiarsDiceGame {
    pub const MAX_PLAYERS: usize = 6;
    pub const MIN_PLAYERS: usize = 2;
    pub const REVEAL_TIMEOUT_MICROS: u64 = 60_000_000; // 60 seconds

    pub fn new(game_id: GameId) -> Self {
        LiarsDiceGame {
            game_id,
            players: Vec::new(),
            phase: GamePhase::WaitingForPlayers,
            round: 0,
            current_turn: 0,
            bid_history: Vec::new(),
            current_bid: None,
            liar_caller: None,
            total_dice: 0,
            reveal_deadline: None,
            winner: None,
            started_at: None,
            ended_at: None,
        }
    }

    pub fn add_player(&mut self, player: GamePlayer) -> bool {
        if self.players.len() >= Self::MAX_PLAYERS {
            return false;
        }
        if self.phase != GamePhase::WaitingForPlayers {
            return false;
        }
        self.total_dice += player.dice_count;
        self.players.push(player);
        true
    }

    pub fn can_start(&self) -> bool {
        self.players.len() >= Self::MIN_PLAYERS && self.phase == GamePhase::WaitingForPlayers
    }

    pub fn start_game(&mut self, timestamp: Timestamp) {
        if self.can_start() {
            self.phase = GamePhase::Committing;
            self.round = 1;
            self.started_at = Some(timestamp);
            self.current_turn = 0;
            if !self.players.is_empty() {
                self.players[0].is_turn = true;
            }
        }
    }

    pub fn all_committed(&self) -> bool {
        self.players
            .iter()
            .filter(|p| !p.eliminated)
            .all(|p| p.commitment.is_some())
    }

    pub fn start_bidding(&mut self) {
        if self.all_committed() {
            self.phase = GamePhase::Bidding;
        }
    }

    pub fn get_current_player(&self) -> Option<&GamePlayer> {
        self.players.get(self.current_turn as usize)
    }

    pub fn get_player_by_chain(&self, chain_id: &ChainId) -> Option<&GamePlayer> {
        self.players.iter().find(|p| p.chain_id.as_ref() == Some(chain_id))
    }

    pub fn get_player_mut_by_chain(&mut self, chain_id: &ChainId) -> Option<&mut GamePlayer> {
        self.players.iter_mut().find(|p| p.chain_id.as_ref() == Some(chain_id))
    }

    pub fn make_bid(&mut self, bid: Bid) -> bool {
        if self.phase != GamePhase::Bidding {
            return false;
        }

        // Check if bid is valid
        if let Some(ref current) = self.current_bid {
            if !bid.is_higher_than(current) {
                return false;
            }
        } else if !bid.is_valid_initial() {
            return false;
        }

        // Update turn
        let old_turn = self.current_turn as usize;
        if old_turn < self.players.len() {
            self.players[old_turn].is_turn = false;
        }

        // Record bid
        self.bid_history.push(bid.clone());
        self.current_bid = Some(bid);

        // Move to next non-eliminated player
        // ✅ FIX: Handle Result from advance_turn
        if self.advance_turn().is_err() {
            // Failed to advance turn (all players eliminated)
            return false;
        }

        true
    }

    pub fn call_liar(&mut self, caller: ChainId, timestamp: Timestamp) -> bool {
        if self.phase != GamePhase::Bidding {
            return false;
        }
        if self.current_bid.is_none() {
            return false; // Can't call liar on first turn
        }

        self.liar_caller = Some(caller);
        self.phase = GamePhase::Revealing;
        self.reveal_deadline = Some(Timestamp::from(
            timestamp.micros() + Self::REVEAL_TIMEOUT_MICROS,
        ));

        true
    }

    pub fn all_revealed(&self) -> bool {
        self.players
            .iter()
            .filter(|p| !p.eliminated)
            .all(|p| {
                p.commitment
                    .as_ref()
                    // ✅ FIX: Check both revealed AND not a cheater
                    .map(|c| c.revealed && !c.cheater)
                    .unwrap_or(false)
            })
    }

    /// Count total dice of a given face across all revealed dice
    pub fn count_total_dice(&self, face: DiceValue, wilds_count: bool) -> u8 {
        self.players
            .iter()
            .filter(|p| !p.eliminated)
            .filter_map(|p| p.revealed_dice.as_ref())
            .map(|d| d.count_face(face, wilds_count))
            .sum()
    }

    /// Resolve the round after all reveals
    /// Returns the ChainId of the player who loses a die
    pub fn resolve_round(&mut self) -> Option<ChainId> {
        if !self.all_revealed() {
            return None;
        }

        let bid = self.current_bid.as_ref()?;
        let actual_count = self.count_total_dice(bid.face, true); // wilds count

        // If actual count >= bid quantity, the caller was wrong (loses a die)
        // If actual count < bid quantity, the bidder was wrong (loses a die)
        let loser = if actual_count >= bid.quantity {
            self.liar_caller.clone()
        } else {
            bid.bidder.clone()
        };

        // Apply penalty
        if let Some(ref loser_chain) = loser {
            if let Some(player) = self.get_player_mut_by_chain(loser_chain) {
                player.lose_die();
            }
        }

        // Update total dice
        self.total_dice = self.players.iter().map(|p| p.dice_count).sum();

        // Check for winner
        let active_players: Vec<_> = self
            .players
            .iter()
            .filter(|p| !p.eliminated)
            .collect();

        if active_players.len() == 1 {
            let winner_chain = active_players[0].chain_id.clone();
            self.winner = winner_chain.clone();
            if let Some(ref wc) = winner_chain {
                if let Some(player) = self.get_player_mut_by_chain(wc) {
                    player.result = GameResult::Won;
                }
            }
            self.phase = GamePhase::GameOver;
        } else {
            self.phase = GamePhase::RoundEnd;
        }

        loser
    }

    /// Start a new round
    pub fn new_round(&mut self) {
        self.round += 1;
        self.bid_history.clear();
        self.current_bid = None;
        self.liar_caller = None;
        self.reveal_deadline = None;

        // Clear revealed dice and commitments
        for player in &mut self.players {
            player.revealed_dice = None;
            player.commitment = None;
            player.is_turn = false;
        }

        // Set first non-eliminated player's turn
        for (i, player) in self.players.iter_mut().enumerate() {
            if !player.eliminated {
                player.is_turn = true;
                self.current_turn = i as u8;
                break;
            }
        }

        self.phase = GamePhase::Committing;
    }

    fn advance_turn(&mut self) -> Result<(), String> {
        let num_players = self.players.len();
        let starting_next = (self.current_turn as usize + 1) % num_players;
        let mut next = starting_next;

        // Find next non-eliminated player
        loop {
            if !self.players[next].eliminated {
                // ✅ Found non-eliminated player
                self.current_turn = next as u8;
                self.players[next].is_turn = true;
                return Ok(());
            }

            next = (next + 1) % num_players;

            // ✅ FIX: Check if we've looped back to start
            if next == starting_next {
                // All players eliminated - game should end
                return Err("No active players remaining - all eliminated".to_string());
            }
        }
    }

    pub fn active_player_count(&self) -> usize {
        self.players.iter().filter(|p| !p.eliminated).count()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bid_comparison() {
        let bid1 = Bid {
            quantity: 3,
            face: DiceValue::new(4).unwrap(),
            bidder: None,
            timestamp: None,
        };

        let bid2 = Bid {
            quantity: 4,
            face: DiceValue::new(2).unwrap(),
            bidder: None,
            timestamp: None,
        };

        let bid3 = Bid {
            quantity: 3,
            face: DiceValue::new(5).unwrap(),
            bidder: None,
            timestamp: None,
        };

        // Higher quantity wins
        assert!(bid2.is_higher_than(&bid1));
        // Same quantity, higher face wins
        assert!(bid3.is_higher_than(&bid1));
        // Lower in both ways
        assert!(!bid1.is_higher_than(&bid2));
    }
}
