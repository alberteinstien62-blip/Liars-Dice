// Cryptographic primitives for commit-reveal scheme

use sha2::{Digest, Sha256};

/// Create a commitment hash for dice values
/// commitment = SHA-256(dice_bytes || salt)
pub fn create_commitment(dice_bytes: &[u8], salt: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(dice_bytes);
    hasher.update(salt);
    hasher.finalize().into()
}

/// Verify that a reveal matches a commitment
pub fn verify_commitment(dice_bytes: &[u8], salt: &[u8; 32], commitment: &[u8; 32]) -> bool {
    let computed = create_commitment(dice_bytes, salt);
    computed == *commitment
}

/// Generate a deterministic salt from chain data
/// salt = SHA-256(block_hash || timestamp || player_chain_id || round_number)
pub fn generate_salt(
    block_hash: &str,
    timestamp: u64,
    player_chain_id: &str,
    round_number: u32,
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(block_hash.as_bytes());
    hasher.update(timestamp.to_le_bytes());
    hasher.update(player_chain_id.as_bytes());
    hasher.update(round_number.to_le_bytes());
    hasher.finalize().into()
}

/// Convert a 32-byte hash to hex string for display
pub fn hash_to_hex(hash: &[u8; 32]) -> String {
    hash.iter().map(|b| format!("{:02x}", b)).collect()
}

/// Parse a hex string to 32-byte array
pub fn hex_to_hash(hex: &str) -> Option<[u8; 32]> {
    if hex.len() != 64 {
        return None;
    }

    let bytes: Result<Vec<u8>, _> = (0..64)
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16))
        .collect();

    bytes.ok().and_then(|b| b.try_into().ok())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_commit_reveal() {
        let dice_bytes = vec![1u8, 3, 3, 5, 6];
        let salt = [42u8; 32];

        let commitment = create_commitment(&dice_bytes, &salt);

        // Valid reveal should verify
        assert!(verify_commitment(&dice_bytes, &salt, &commitment));

        // Invalid dice should not verify
        let wrong_dice = vec![2u8, 3, 3, 5, 6];
        assert!(!verify_commitment(&wrong_dice, &salt, &commitment));

        // Invalid salt should not verify
        let wrong_salt = [43u8; 32];
        assert!(!verify_commitment(&dice_bytes, &wrong_salt, &commitment));
    }

    #[test]
    fn test_hex_conversion() {
        let hash = [0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78, 0x90,
                    0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78, 0x90,
                    0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78, 0x90,
                    0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78, 0x90];

        let hex = hash_to_hex(&hash);
        let recovered = hex_to_hash(&hex).unwrap();

        assert_eq!(hash, recovered);
    }
}
