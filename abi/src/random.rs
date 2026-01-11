// Deterministic random number generation for Liar's Dice
// Each call creates a fresh RNG from the provided seed parameters

use rand::{rngs::StdRng, Rng, SeedableRng};
use sha2::{Digest, Sha256};

/// Generate a 32-byte seed array using SHA-256 hashing
/// This is safe from UTF-8 boundary issues and always produces valid 32 bytes
fn get_seed_array(hash: &str, timestamp: &str) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(hash.as_bytes());
    hasher.update(timestamp.as_bytes());
    let result = hasher.finalize();
    let mut seed = [0u8; 32];
    seed.copy_from_slice(&result);
    seed
}

/// Create a fresh RNG seeded from the hash and timestamp
/// Each call creates a new independent RNG for deterministic results
pub fn get_custom_rng(hash: String, timestamp: String) -> Result<StdRng, getrandom::Error> {
    Ok(StdRng::from_seed(get_seed_array(&hash, &timestamp)))
}

/// Get a random value in the range [min, max)
/// Creates a fresh RNG each time for deterministic results
pub fn get_random_value(min: u8, max: u8, hash: String, timestamp: String) -> Result<u8, getrandom::Error> {
    let mut rng = StdRng::from_seed(get_seed_array(&hash, &timestamp));
    Ok(rng.gen_range(min..max))
}

/// Generate a random die roll (1-6)
pub fn roll_die(hash: String, timestamp: String) -> Result<u8, getrandom::Error> {
    get_random_value(1, 7, hash, timestamp) // 1..7 gives us 1-6
}

/// Generate N dice rolls
pub fn roll_dice(count: u8, hash: String, timestamp: String) -> Result<Vec<u8>, getrandom::Error> {
    let mut rng = get_custom_rng(hash, timestamp)?;
    let dice: Vec<u8> = (0..count).map(|_| rng.gen_range(1..=6)).collect();
    Ok(dice)
}

/// Generate a random 32-byte salt
pub fn generate_random_salt(hash: String, timestamp: String) -> Result<[u8; 32], getrandom::Error> {
    let mut rng = get_custom_rng(hash, timestamp)?;
    let mut salt = [0u8; 32];
    for byte in &mut salt {
        *byte = rng.gen();
    }
    Ok(salt)
}
