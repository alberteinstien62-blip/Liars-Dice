// Dice types for Liar's Dice

use async_graphql::scalar;
use async_graphql_derive::SimpleObject;
use serde::{Deserialize, Serialize};

/// The face value of a single die (1-6)
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct DiceValue(u8);

scalar!(DiceValue);

impl DiceValue {
    pub fn new(value: u8) -> Option<Self> {
        if (1..=6).contains(&value) {
            Some(DiceValue(value))
        } else {
            None
        }
    }

    pub fn value(&self) -> u8 {
        self.0
    }

    /// In Liar's Dice, 1s are often wild (count as any value)
    pub fn is_wild(&self) -> bool {
        self.0 == 1
    }
}

impl Default for DiceValue {
    fn default() -> Self {
        DiceValue(1)
    }
}

/// A player's complete hand of dice (typically 5 dice)
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize, SimpleObject)]
pub struct PlayerDice {
    /// The actual dice values (only visible to the owner until revealed)
    pub dice: Vec<DiceValue>,
    /// Number of dice remaining (starts at 5, decreases when losing rounds)
    pub count: u8,
}

impl PlayerDice {
    pub const STARTING_DICE: u8 = 5;

    pub fn new(dice: Vec<DiceValue>) -> Self {
        let count = dice.len() as u8;
        PlayerDice { dice, count }
    }

    /// Count how many dice match a specific face value (including wilds)
    pub fn count_face(&self, face: DiceValue, wilds_count: bool) -> u8 {
        self.dice
            .iter()
            .filter(|d| {
                d.value() == face.value() || (wilds_count && d.is_wild() && face.value() != 1)
            })
            .count() as u8
    }

    /// Count only exact matches (no wilds)
    pub fn count_exact(&self, face: DiceValue) -> u8 {
        self.dice.iter().filter(|d| d.value() == face.value()).count() as u8
    }

    /// Remove one die (when losing a round)
    pub fn lose_die(&mut self) {
        if self.count > 0 {
            self.count -= 1;
            if !self.dice.is_empty() {
                self.dice.pop();
            }
        }
    }

    pub fn is_eliminated(&self) -> bool {
        self.count == 0
    }

    /// Convert dice to bytes for commitment hashing
    pub fn to_bytes(&self) -> Vec<u8> {
        self.dice.iter().map(|d| d.value()).collect()
    }

    /// Create from byte representation
    pub fn from_bytes(bytes: &[u8]) -> Option<Self> {
        let dice: Option<Vec<DiceValue>> = bytes.iter().map(|&b| DiceValue::new(b)).collect();
        dice.map(PlayerDice::new)
    }
}

/// Dice commitment for commit-reveal scheme
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize, SimpleObject)]
pub struct DiceCommitment {
    /// SHA-256 hash of (dice_bytes || salt)
    pub hash: [u8; 32],
    /// Has this commitment been revealed?
    pub revealed: bool,
    /// Was the player caught cheating (invalid reveal)?
    pub cheater: bool,
}

impl DiceCommitment {
    pub fn new(hash: [u8; 32]) -> Self {
        DiceCommitment {
            hash,
            revealed: false,
            cheater: false,
        }
    }

    pub fn mark_revealed(&mut self) {
        self.revealed = true;
    }

    pub fn mark_cheater(&mut self) {
        self.cheater = true;
        // ✅ FIX: Mark cheaters as revealed so all_revealed() returns true
        // The cheater check in all_revealed() handles the logic: revealed && !cheater
        // Setting revealed=true ensures round can resolve after cheater detected
        self.revealed = true;
    }
}

/// Revealed dice with salt for verification
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize, SimpleObject)]
pub struct DiceReveal {
    pub dice: PlayerDice,
    pub salt: [u8; 32],
}

impl DiceReveal {
    pub fn new(dice: PlayerDice, salt: [u8; 32]) -> Self {
        DiceReveal { dice, salt }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dice_value_creation() {
        assert!(DiceValue::new(0).is_none());
        assert!(DiceValue::new(1).is_some());
        assert!(DiceValue::new(6).is_some());
        assert!(DiceValue::new(7).is_none());
    }

    #[test]
    fn test_count_with_wilds() {
        let dice = PlayerDice::new(vec![
            DiceValue::new(1).unwrap(), // wild
            DiceValue::new(3).unwrap(),
            DiceValue::new(3).unwrap(),
            DiceValue::new(5).unwrap(),
            DiceValue::new(6).unwrap(),
        ]);

        // Count 3s with wilds: two 3s + one wild = 3
        assert_eq!(dice.count_face(DiceValue::new(3).unwrap(), true), 3);
        // Count 3s exact: only two 3s
        assert_eq!(dice.count_exact(DiceValue::new(3).unwrap()), 2);
        // Count 1s (wilds don't count as wilds when counting 1s)
        assert_eq!(dice.count_face(DiceValue::new(1).unwrap(), true), 1);
    }
}
