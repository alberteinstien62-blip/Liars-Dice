#![cfg_attr(target_arch = "wasm32", no_main)]

mod state;

use self::state::LiarsDiceState;
use abi::crypto::{create_commitment, verify_commitment};
use abi::dice::{DiceCommitment, DiceReveal, DiceValue, PlayerDice};
use abi::random::{generate_random_salt, roll_dice};
use abi::game::{Bid, GamePlayer, GamePhase, LiarsDiceGame};
use abi::leaderboard::SimpleLeaderboardEntry;
use abi::player::{calculate_elo_change, PlayerProfile, QueuedPlayer, UserStatus, STARTING_ELO};
use bankroll::{BankrollAbi, BankrollOperation, BankrollResponse};
use liars_dice::{
    LiarsDiceEvent, LiarsDiceMessage, LiarsDiceOperation, LiarsDiceParameters,
    LIARS_DICE_STREAM_NAME,
};
use linera_sdk::linera_base_types::{Amount, ApplicationId, ChainId};
use linera_sdk::{
    linera_base_types::WithContractAbi,
    views::{RootView, View},
    Contract, ContractRuntime,
};

pub struct LiarsDiceContract {
    state: LiarsDiceState,
    runtime: ContractRuntime<Self>,
}

linera_sdk::contract!(LiarsDiceContract);

impl WithContractAbi for LiarsDiceContract {
    type Abi = liars_dice::LiarsDiceAbi;
}

impl Contract for LiarsDiceContract {
    type Message = LiarsDiceMessage;
    type Parameters = LiarsDiceParameters;
    type InstantiationArgument = u64; // Chain type: 0=Master, 1=Lobby, 2=Game, 3=User
    type EventValue = LiarsDiceEvent;

    async fn load(runtime: ContractRuntime<Self>) -> Self {
        let state = LiarsDiceState::load(runtime.root_view_storage_context())
            .await
            .expect("Failed to load state");
        LiarsDiceContract { state, runtime }
    }

    async fn instantiate(&mut self, chain_type: Self::InstantiationArgument) {
        log::info!("Instantiating Liar's Dice contract with chain_type: {}", chain_type);

        // Validate chain type
        assert!(
            chain_type <= 3,
            "Invalid chain type: {}. Must be 0 (Master), 1 (Lobby), 2 (Game), or 3 (User)",
            chain_type
        );

        self.state.chain_type.set(chain_type);

        // NOTE: Commented out - application_parameters() causes panic in Linera 0.15.7
        // let params = self.runtime.application_parameters();
        // log::info!(
        //     "Application parameters validated: master_chain={}, bankroll={:?}",
        //     params.master_chain,
        //     params.bankroll
        // );

        match chain_type {
            0 => {
                // Master chain - no special initialization needed
                log::info!("Initialized as MASTER chain");
            }
            1 => {
                // Lobby chain
                log::info!("Initialized as LOBBY chain");
                self.state.queue_count.set(0);
            }
            2 => {
                // Game chain
                log::info!("Initialized as GAME chain");
                self.state.game_chain_available.set(true);
                self.state.games_hosted.set(0);
            }
            3 => {
                // User chain
                log::info!("Initialized as USER chain");
                self.state.user_balance.set(Amount::ZERO);
            }
            _ => unreachable!("Chain type already validated to be 0-3"),
        }
    }

    async fn execute_operation(&mut self, operation: Self::Operation) -> Self::Response {
        let chain_type = *self.state.chain_type.get();

        match operation {
            // ============================================
            // USER CHAIN OPERATIONS
            // ============================================
            LiarsDiceOperation::SetProfile { name } => {
                self.assert_user_chain(chain_type);
                let chain_id = self.runtime.chain_id();
                let owner = self.runtime.authenticated_signer().expect("No authenticated signer");
                let timestamp = self.runtime.system_time();

                let profile = PlayerProfile::new(chain_id, owner, name, timestamp);
                self.state.user_profile.set(Some(profile.clone()));

                log::info!("Profile set for user: {:?}", chain_id);

                // Emit profile update event
                self.runtime.emit(
                    LIARS_DICE_STREAM_NAME.into(),
                    &LiarsDiceEvent::ProfileUpdate { profile },
                );
            }

            LiarsDiceOperation::FindMatch {} => {
                self.assert_user_chain(chain_type);
                let profile = self.state.user_profile.get()
                    .as_ref()
                    .expect("Profile not set");

                let queued_player = QueuedPlayer::new(
                    profile.chain_id.expect("No chain ID"),
                    profile.owner.expect("No owner"),
                    profile.name.clone(),
                    profile.elo,
                    self.runtime.system_time(),
                );

                // Send to lobby chain
                if let Some(lobby_chain) = self.state.lobby_chain.get().as_ref() {
                    self.message_manager(*lobby_chain, LiarsDiceMessage::FindMatch { player: queued_player });

                    // Update user status
                    if let Some(ref mut profile) = *self.state.user_profile.get_mut() {
                        profile.set_status(UserStatus::FindingMatch);
                    }
                } else {
                    log::error!("No lobby chain configured!");
                }
            }

            LiarsDiceOperation::CancelMatch {} => {
                self.assert_user_chain(chain_type);
                let chain_id = self.runtime.chain_id();

                if let Some(lobby_chain) = self.state.lobby_chain.get().as_ref() {
                    self.message_manager(
                        *lobby_chain,
                        LiarsDiceMessage::CancelMatch { player_chain: chain_id },
                    );

                    // Update user status
                    if let Some(ref mut profile) = *self.state.user_profile.get_mut() {
                        profile.set_status(UserStatus::Idle);
                    }
                }
            }

            LiarsDiceOperation::CommitDice { commitment } => {
                self.assert_user_chain(chain_type);
                let chain_id = self.runtime.chain_id();

                if let Some(game_chain) = self.state.user_game_chain.get().as_ref() {
                    let dice_commitment = DiceCommitment::new(commitment);
                    self.message_manager(
                        *game_chain,
                        LiarsDiceMessage::CommitDice {
                            player_chain: chain_id,
                            commitment: dice_commitment,
                        },
                    );
                    log::info!("Sent dice commitment to game chain");
                }
            }

            LiarsDiceOperation::RevealDice { dice, salt } => {
                self.assert_user_chain(chain_type);
                let chain_id = self.runtime.chain_id();

                // Create PlayerDice from bytes
                let player_dice = PlayerDice::from_bytes(&dice).expect("Invalid dice bytes");
                let salt_array: [u8; 32] = salt;
                let reveal = DiceReveal::new(player_dice, salt_array);

                if let Some(game_chain) = self.state.user_game_chain.get().as_ref() {
                    self.message_manager(
                        *game_chain,
                        LiarsDiceMessage::RevealDice {
                            player_chain: chain_id,
                            reveal,
                        },
                    );
                    log::info!("Sent dice reveal to game chain");
                }
            }

            LiarsDiceOperation::MakeBid { quantity, face } => {
                self.assert_user_chain(chain_type);
                let chain_id = self.runtime.chain_id();
                let timestamp = self.runtime.system_time();

                // Validate face value before creating DiceValue
                let dice_face = match DiceValue::new(face) {
                    Some(dv) => dv,
                    None => {
                        log::error!("Invalid face value: {}. Must be between 1 and 6.", face);
                        return;
                    }
                };

                let bid = Bid::new(
                    quantity,
                    dice_face,
                    chain_id,
                    timestamp,
                );

                if let Some(game_chain) = self.state.user_game_chain.get().as_ref() {
                    self.message_manager(
                        *game_chain,
                        LiarsDiceMessage::MakeBid {
                            player_chain: chain_id,
                            bid,
                        },
                    );
                }
            }

            LiarsDiceOperation::CallLiar {} => {
                self.assert_user_chain(chain_type);
                let chain_id = self.runtime.chain_id();

                if let Some(game_chain) = self.state.user_game_chain.get().as_ref() {
                    self.message_manager(
                        *game_chain,
                        LiarsDiceMessage::CallLiar { player_chain: chain_id },
                    );
                }
            }

            LiarsDiceOperation::ExitGame {} => {
                self.assert_user_chain(chain_type);
                let chain_id = self.runtime.chain_id();

                if let Some(game_chain) = self.state.user_game_chain.get().as_ref() {
                    self.message_manager(
                        *game_chain,
                        LiarsDiceMessage::PlayerForfeit { player_chain: chain_id },
                    );
                }

                self.state.user_game_chain.set(None);
                if let Some(ref mut profile) = *self.state.user_profile.get_mut() {
                    profile.set_status(UserStatus::Idle);
                }
            }

            LiarsDiceOperation::GetBalance {} => {
                self.assert_user_chain(chain_type);
                let balance = self.bankroll_get_balance();
                self.state.user_balance.set(balance);
                log::info!("GetBalance called - user balance: {}", balance);
            }

            LiarsDiceOperation::InitialSetup { lobby_chain } => {
                // First-time setup: set chain_type to User (3) if not already set
                if chain_type == 0 {
                    self.state.chain_type.set(3);
                    log::info!("InitialSetup: Set chain_type to User (3)");
                }

                // Store the lobby chain provided by the frontend config
                self.state.lobby_chain.set(Some(lobby_chain));
                self.state.cached_lobby_chain.set(Some(lobby_chain));

                log::info!("InitialSetup: Configured lobby chain {}", lobby_chain);
            }

            // ============================================
            // GAME CHAIN OPERATIONS
            // ============================================
            LiarsDiceOperation::CheckTimeout {} => {
                self.assert_game_chain(chain_type);
                log::info!("Checking for reveal timeout");

                let current_time = self.runtime.system_time();
                let should_resolve = {
                    if let Some(ref mut game) = *self.state.current_game.get_mut() {
                        if game.phase == abi::game::GamePhase::Revealing {
                            if let Some(deadline) = game.reveal_deadline {
                                if current_time.micros() > deadline.micros() {
                                    log::info!("Reveal timeout! Eliminating non-revealers");

                                    // Eliminate players who haven't revealed
                                    for player in &mut game.players {
                                        if !player.eliminated {
                                            let revealed = player.commitment
                                                .as_ref()
                                                .map(|c| c.revealed)
                                                .unwrap_or(false);

                                            if !revealed {
                                                log::info!("Player {:?} eliminated for reveal timeout", player.chain_id);
                                                if let Some(ref mut commitment) = player.commitment {
                                                    commitment.revealed = true; // Mark as revealed so all_revealed() works
                                                }
                                                player.result = abi::game::GameResult::TimedOut;
                                                player.eliminated = true;
                                                player.dice_count = 0;
                                            }
                                        }
                                    }

                                    // Update total dice
                                    game.total_dice = game.players.iter().map(|p| p.dice_count).sum();

                                    // Check if we can resolve the round now
                                    true
                                } else {
                                    false
                                }
                            } else {
                                false
                            }
                        } else {
                            false
                        }
                    } else {
                        false
                    }
                };

                if should_resolve {
                    self.resolve_round().await;
                }
            }

            // ============================================
            // MASTER CHAIN OPERATIONS
            // ============================================
            LiarsDiceOperation::AddLobbyChain { chain_id } => {
                self.assert_master_chain(chain_type);
                log::info!("Adding lobby chain: {:?}", chain_id);

                let info = abi::management::LobbyChainInfo::new(chain_id, self.runtime.system_time());
                self.state.lobby_chains.insert(&chain_id, info).expect("Failed to insert lobby chain");
            }

            LiarsDiceOperation::AddGameChain { chain_id } => {
                self.assert_master_chain(chain_type);
                log::info!("Adding game chain: {:?}", chain_id);

                // Get all lobby chains and send to them
                let lobby_keys = self.state.lobby_chains.indices().await.expect("Failed to get lobby chains");
                for lobby_chain in lobby_keys {
                    self.message_manager(
                        lobby_chain,
                        LiarsDiceMessage::RegisterGameChain { chain_id },
                    );
                }
            }

            LiarsDiceOperation::MintToken { chain_id, amount } => {
                self.assert_master_chain(chain_type);
                log::info!("MintToken: {:?} amount: {}", chain_id, amount);
                self.bankroll_mint_token(chain_id, amount);
            }
        }
    }

    async fn execute_message(&mut self, message: Self::Message) {
        let chain_type = *self.state.chain_type.get();
        let origin = self.runtime.message_origin_chain_id().expect("No origin chain");

        match message {
            // ============================================
            // SUBSCRIPTION CONTROL (Universal)
            // ============================================
            LiarsDiceMessage::Subscribe => {
                log::info!("Chain {:?} subscribing to events", origin);
                let app_id = self.runtime.application_id().forget_abi();
                self.runtime.subscribe_to_events(origin, app_id, LIARS_DICE_STREAM_NAME.into());
                log::info!("Subscribed {:?} to events from this chain (type {})", origin, chain_type);
            }

            LiarsDiceMessage::Unsubscribe => {
                log::info!("Chain {:?} unsubscribing from events", origin);
                let app_id = self.runtime.application_id().forget_abi();
                self.runtime.unsubscribe_from_events(origin, app_id, LIARS_DICE_STREAM_NAME.into());
                log::info!("Unsubscribed {:?} from events", origin);
            }

            // ============================================
            // USER CHAIN MESSAGES
            // ============================================
            LiarsDiceMessage::MatchFound {
                game_chain,
                game_id,
                opponent_name,
                opponent_elo,
            } => {
                self.assert_user_chain(chain_type);
                log::info!(
                    "Match found! Game: {}, Opponent: {} (ELO: {})",
                    game_id, opponent_name, opponent_elo
                );

                self.state.user_game_chain.set(Some(game_chain));

                if let Some(ref mut profile) = *self.state.user_profile.get_mut() {
                    profile.set_status(UserStatus::InGame { game_chain });
                }

                // Subscribe to game chain events
                let app_id = self.runtime.application_id().forget_abi();
                self.runtime.subscribe_to_events(game_chain, app_id, LIARS_DICE_STREAM_NAME.into());
            }

            LiarsDiceMessage::GameStarted { game } => {
                self.assert_user_chain(chain_type);
                log::info!("Game started: {:?}", game.game_id);
                self.state.channel_game_state.set(Some(game.clone()));

                // Generate dice and salt for this round
                let chain_id = self.runtime.chain_id();
                let timestamp = self.runtime.system_time();
                let nonce = *self.state.rng_nonce.get();
                // Mix private nonce into seed so observers can't predict dice
                let seed_str = format!("{:?}_{}_{}", chain_id, timestamp.micros(), nonce);
                self.state.rng_nonce.set(nonce + 1);

                // Generate 5 random dice (values 1-6)
                let dice_values = roll_dice(5, seed_str.clone(), String::new())
                    .expect("Failed to generate dice. Game cannot start with predictable dice.");

                let player_dice = PlayerDice::from_bytes(&dice_values)
                    .expect("Failed to parse dice values");

                // Generate salt for commitment - CRITICAL for security
                let salt = generate_random_salt(seed_str, String::new())
                    .expect("Failed to generate salt. Cannot proceed without secure randomness.");

                // Store dice and salt privately (NEVER sent to other chains)
                self.state.user_dice.set(Some(player_dice.clone()));
                self.state.user_salt.set(Some(salt));

                // Create commitment hash = SHA-256(dice_bytes || salt)
                let dice_bytes = player_dice.to_bytes();
                let commitment_hash = create_commitment(&dice_bytes, &salt);
                let dice_commitment = DiceCommitment::new(commitment_hash);

                log::info!("Generated dice for user {:?}, sending commitment to game chain", chain_id);

                // Send commitment to game chain (only hash, not actual dice!)
                if let Some(game_chain) = self.state.user_game_chain.get().as_ref() {
                    self.message_manager(
                        *game_chain,
                        LiarsDiceMessage::CommitDice {
                            player_chain: chain_id,
                            commitment: dice_commitment,
                        },
                    );
                }
            }

            LiarsDiceMessage::BidMade { game, bidder, bid } => {
                self.assert_user_chain(chain_type);
                log::info!("Bid made by {:?}: {} x {}", bidder, bid.quantity, bid.face.value());
                self.state.channel_game_state.set(Some(game));
            }

            LiarsDiceMessage::LiarCalled { game, caller } => {
                self.assert_user_chain(chain_type);
                log::info!("Liar called by {:?}", caller);
                self.state.channel_game_state.set(Some(game));

                // ✅ FIX Bug #10: AUTO-REVEAL using stored dice and salt
                // This ensures reveal happens automatically without frontend intervention
                let chain_id = self.runtime.chain_id();
                if let (Some(dice), Some(salt)) = (
                    self.state.user_dice.get().clone(),
                    self.state.user_salt.get().clone()
                ) {
                    if let Some(game_chain) = self.state.user_game_chain.get().as_ref() {
                        let reveal = DiceReveal::new(dice.clone(), salt);
                        self.message_manager(
                            *game_chain,
                            LiarsDiceMessage::RevealDice {
                                player_chain: chain_id,
                                reveal,
                            },
                        );
                        log::info!("Auto-revealed dice for user {:?} to game chain", chain_id);
                    }
                } else {
                    log::error!("Cannot auto-reveal: dice or salt not found for user {:?}", chain_id);
                }
            }

            LiarsDiceMessage::RoundResult {
                game,
                loser,
                actual_count,
                bid_was_valid: _,
            } => {
                self.assert_user_chain(chain_type);
                log::info!("Round result: loser {:?}, actual count: {}", loser, actual_count);
                self.state.channel_game_state.set(Some(game.clone()));

                // ✅ FIX Bug #11: Auto-generate new dice for next round if phase is Committing
                if game.phase == abi::game::GamePhase::Committing {
                    log::info!("New round started - generating dice for round {}", game.round);

                    let chain_id = self.runtime.chain_id();
                    let timestamp = self.runtime.system_time();
                    let nonce = *self.state.rng_nonce.get();
                    let round_seed = format!("{:?}_{}_{}_round_{}", chain_id, timestamp.micros(), nonce, game.round);
                    self.state.rng_nonce.set(nonce + 1);

                    // Get player's actual dice count from game state (not hardcoded 5)
                    let my_dice_count = game.players.iter()
                        .find(|p| p.chain_id == Some(chain_id))
                        .map(|p| p.dice_count)
                        .unwrap_or(0);

                    // Skip dice generation if player is eliminated
                    if my_dice_count == 0 {
                        log::info!("Player {:?} eliminated, skipping dice generation", chain_id);
                        return;
                    }

                    // Generate dice matching player's current count
                    let dice_values = roll_dice(my_dice_count, round_seed.clone(), String::new())
                        .expect("Failed to generate dice for new round");

                    let player_dice = PlayerDice::from_bytes(&dice_values)
                        .expect("Failed to parse dice values");

                    // Generate new salt for this round
                    let salt = generate_random_salt(round_seed, String::new())
                        .expect("Failed to generate salt for new round");

                    // Store dice and salt privately
                    self.state.user_dice.set(Some(player_dice.clone()));
                    self.state.user_salt.set(Some(salt));

                    // Create and send commitment
                    let dice_bytes = player_dice.to_bytes();
                    let commitment_hash = create_commitment(&dice_bytes, &salt);
                    let dice_commitment = DiceCommitment::new(commitment_hash);

                    log::info!("Generated new dice for round {}, sending commitment", game.round);

                    if let Some(game_chain) = self.state.user_game_chain.get().as_ref() {
                        self.message_manager(
                            *game_chain,
                            LiarsDiceMessage::CommitDice {
                                player_chain: chain_id,
                                commitment: dice_commitment,
                            },
                        );
                    }
                }
            }

            LiarsDiceMessage::GameResult {
                game,
                winner,
                loser: _,
                elo_change,
            } => {
                self.assert_user_chain(chain_type);
                let my_chain = self.runtime.chain_id();
                let won = winner == my_chain;

                log::info!("Game over! Winner: {:?}, ELO change: {}", winner, elo_change);

                if let Some(ref mut profile) = *self.state.user_profile.get_mut() {
                    if won {
                        profile.elo = (profile.elo as i32 + elo_change) as u32;
                    } else {
                        profile.elo = (profile.elo as i32 - elo_change.abs()).max(100) as u32;
                    }
                    profile.set_status(UserStatus::Idle);
                    profile.stats.record_game(won, game.round as u64);
                }

                // Clean up
                self.state.user_game_chain.set(None);
                self.state.user_dice.set(None);
                self.state.user_salt.set(None);
                self.state.channel_game_state.set(None);
            }

            LiarsDiceMessage::LobbyInfo { lobby_chain } => {
                self.assert_user_chain(chain_type);
                log::info!("Received lobby chain info: {:?}", lobby_chain);
                self.state.lobby_chain.set(Some(lobby_chain));

                // Subscribe to lobby chain events (following microcard pattern)
                let app_id = self.runtime.application_id().forget_abi();
                self.runtime.subscribe_to_events(lobby_chain, app_id, LIARS_DICE_STREAM_NAME.into());
                log::info!("User {:?} subscribed to lobby chain {:?} for event updates",
                    self.runtime.chain_id(), lobby_chain);
            }

            LiarsDiceMessage::ProfileUpdated { profile: _ } |
            LiarsDiceMessage::RevealRequired { deadline: _ } => {
                // Handle other user chain messages
                self.assert_user_chain(chain_type);
            }

            // ============================================
            // LOBBY CHAIN MESSAGES
            // ============================================
            LiarsDiceMessage::FindMatch { player } => {
                self.assert_lobby_chain(chain_type);
                log::info!("Player {:?} looking for match", player.chain_id);

                // Add to queue (not async in QueueView)
                self.state.matchmaking_queue.push_back(player.clone());
                let count = self.state.queue_count.get_mut();
                *count += 1;

                // Emit queue update
                self.runtime.emit(
                    LIARS_DICE_STREAM_NAME.into(),
                    &LiarsDiceEvent::QueueUpdate { players_in_queue: *count },
                );

                // Try to match players
                self.try_match_players().await;
            }

            LiarsDiceMessage::CancelMatch { player_chain } => {
                self.assert_lobby_chain(chain_type);
                log::info!("Player {:?} cancelling match", player_chain);

                // ✅ FIX: Optimized queue removal - collect all players first to minimize async calls
                // QueueView doesn't support direct removal, so we need to:
                // 1. Pop all items into a Vec (single pass)
                // 2. Filter and re-add all items except the cancelled player
                let queue_count = *self.state.queue_count.get();

                // Collect all players from queue in one pass
                let all_players: Vec<QueuedPlayer> = {
                    let mut players = Vec::with_capacity(queue_count as usize);
                    for _ in 0..queue_count {
                        if let Ok(Some(player)) = self.state.matchmaking_queue.front().await {
                            self.state.matchmaking_queue.delete_front();
                            players.push(player);
                        }
                    }
                    players
                };

                // Filter and re-add in one pass
                let mut removed = false;
                for player in all_players {
                    if player.chain_id != player_chain {
                        self.state.matchmaking_queue.push_back(player);
                    } else {
                        removed = true;
                        log::info!("Removed player {:?} from queue", player_chain);
                    }
                }

                // Update queue count
                if removed {
                    let count = self.state.queue_count.get_mut();
                    *count = count.saturating_sub(1);

                    // Emit queue update event
                    self.runtime.emit(
                        LIARS_DICE_STREAM_NAME.into(),
                        &LiarsDiceEvent::QueueUpdate { players_in_queue: *count },
                    );
                }
            }

            LiarsDiceMessage::GameEnded {
                game_chain,
                winner: _,
                loser: _,
            } => {
                self.assert_lobby_chain(chain_type);
                log::info!("Game ended on {:?}", game_chain);

                // Return game chain to pool
                self.state.available_game_chains.push_back(game_chain);
                self.state.active_game_chains.remove(&game_chain).expect("Failed to remove game chain");
            }

            LiarsDiceMessage::RegisterGameChain { chain_id } => {
                self.assert_lobby_chain(chain_type);
                log::info!("Registering game chain: {:?}", chain_id);
                self.state.available_game_chains.push_back(chain_id);
            }

            // ============================================
            // GAME CHAIN MESSAGES
            // ============================================
            LiarsDiceMessage::AssignMatch {
                game_id,
                player1,
                player2,
            } => {
                self.assert_game_chain(chain_type);
                log::info!("Assigned match {} with players", game_id);

                // Create new game
                let mut game = LiarsDiceGame::new(game_id);

                // Add players (preserving ELO from matchmaking)
                let gp1 = GamePlayer::new(player1.chain_id, player1.owner, player1.name.clone(), player1.elo);
                let gp2 = GamePlayer::new(player2.chain_id, player2.owner, player2.name.clone(), player2.elo);
                game.add_player(gp1);
                game.add_player(gp2);

                // Start game
                game.start_game(self.runtime.system_time());

                // Store game state
                self.state.current_game.set(Some(game.clone()));
                self.state.game_chain_available.set(false);

                // Notify players
                self.message_manager(player1.chain_id, LiarsDiceMessage::GameStarted { game: game.clone() });
                self.message_manager(player2.chain_id, LiarsDiceMessage::GameStarted { game: game.clone() });

                // Emit game state event
                self.runtime.emit(
                    LIARS_DICE_STREAM_NAME.into(),
                    &LiarsDiceEvent::GameState { game },
                );
            }

            LiarsDiceMessage::CommitDice {
                player_chain,
                commitment,
            } => {
                self.assert_game_chain(chain_type);
                log::info!("Received commitment from {:?}", player_chain);

                if let Some(ref mut game) = *self.state.current_game.get_mut() {
                    // ✅ FIX: Add phase validation
                    if game.phase != abi::game::GamePhase::Committing {
                        log::error!(
                            "Cannot commit dice in {:?} phase - must be in Committing phase",
                            game.phase
                        );
                        return;
                    }

                    if let Some(player) = game.get_player_mut_by_chain(&player_chain) {
                        player.set_commitment(commitment);
                    }

                    // Check if all committed
                    if game.all_committed() {
                        game.start_bidding();
                        log::info!("All players committed, starting bidding phase");

                        // Emit game state
                        self.runtime.emit(
                            LIARS_DICE_STREAM_NAME.into(),
                            &LiarsDiceEvent::GameState { game: game.clone() },
                        );
                    }
                }
            }

            LiarsDiceMessage::MakeBid { player_chain, bid } => {
                self.assert_game_chain(chain_type);
                log::info!("Bid from {:?}: {} x {}", player_chain, bid.quantity, bid.face.value());

                // Collect data while holding mutable borrow, then release it
                let send_data = {
                    if let Some(ref mut game) = *self.state.current_game.get_mut() {
                        // ✅ FIX: Add phase validation
                        if game.phase != abi::game::GamePhase::Bidding {
                            log::error!(
                                "Cannot make bid in {:?} phase - must be in Bidding phase",
                                game.phase
                            );
                            None
                        } else if game.make_bid(bid.clone()) {
                            let player_chains: Vec<ChainId> = game.players
                                .iter()
                                .filter_map(|p| p.chain_id)
                                .collect();
                            Some((game.clone(), player_chains, game.game_id))
                        } else {
                            None
                        }
                    } else {
                        None
                    }
                };

                // Now send messages with collected data
                if let Some((game_state, player_chains, game_id)) = send_data {
                    for chain_id in player_chains {
                        self.message_manager(
                            chain_id,
                            LiarsDiceMessage::BidMade {
                                game: game_state.clone(),
                                bidder: player_chain,
                                bid: bid.clone(),
                            },
                        );
                    }

                    self.runtime.emit(
                        LIARS_DICE_STREAM_NAME.into(),
                        &LiarsDiceEvent::BidUpdate { game_id, bid },
                    );
                }
            }

            LiarsDiceMessage::CallLiar { player_chain } => {
                self.assert_game_chain(chain_type);
                log::info!("Liar called by {:?}", player_chain);

                let timestamp = self.runtime.system_time();

                // Collect data while holding mutable borrow
                let send_data = {
                    if let Some(ref mut game) = *self.state.current_game.get_mut() {
                        // ✅ FIX: Add phase validation
                        if game.phase != abi::game::GamePhase::Bidding {
                            log::error!(
                                "Cannot call liar in {:?} phase - must be in Bidding phase",
                                game.phase
                            );
                            None
                        } else if game.call_liar(player_chain, timestamp) {
                            let player_chains: Vec<ChainId> = game.players
                                .iter()
                                .filter_map(|p| p.chain_id)
                                .collect();
                            Some((game.clone(), player_chains, game.game_id))
                        } else {
                            None
                        }
                    } else {
                        None
                    }
                };

                // Now send messages
                if let Some((game_state, player_chains, game_id)) = send_data {
                    for chain_id in player_chains {
                        self.message_manager(
                            chain_id,
                            LiarsDiceMessage::LiarCalled {
                                game: game_state.clone(),
                                caller: player_chain,
                            },
                        );
                    }

                    self.runtime.emit(
                        LIARS_DICE_STREAM_NAME.into(),
                        &LiarsDiceEvent::LiarCalledEvent {
                            game_id,
                            caller: player_chain,
                        },
                    );
                }
            }

            LiarsDiceMessage::RevealDice {
                player_chain,
                reveal,
            } => {
                self.assert_game_chain(chain_type);
                log::info!("Reveal from {:?}", player_chain);

                let should_resolve = {
                    let game = self.state.current_game.get_mut();
                    if let Some(ref mut game) = *game {
                        // ✅ FIX: Add phase validation
                        if game.phase != abi::game::GamePhase::Revealing {
                            log::error!(
                                "Cannot reveal dice in {:?} phase - must be in Revealing phase",
                                game.phase
                            );
                            return;
                        }

                        if let Some(player) = game.get_player_mut_by_chain(&player_chain) {
                            // Verify commitment
                            if let Some(ref mut commitment) = player.commitment {
                                let dice_bytes = reveal.dice.to_bytes();
                                if verify_commitment(&dice_bytes, &reveal.salt, &commitment.hash) {
                                    commitment.mark_revealed();
                                    player.revealed_dice = Some(reveal.dice.clone());
                                    player.dice_count = reveal.dice.count;
                                    log::info!("Valid reveal from {:?}", player_chain);

                                    self.runtime.emit(
                                        LIARS_DICE_STREAM_NAME.into(),
                                        &LiarsDiceEvent::DiceRevealed {
                                            game_id: game.game_id,
                                            player: player_chain,
                                            dice: reveal.dice,
                                        },
                                    );
                                } else {
                                    // CHEATER DETECTED - mark commitment so all_revealed() returns true
                                    log::error!("CHEATER DETECTED: {:?} - invalid reveal!", player_chain);
                                    commitment.mark_cheater();
                                    player.result = abi::game::GameResult::Cheater;
                                    player.eliminated = true;
                                    player.dice_count = 0;
                                }
                            }
                        }
                        game.all_revealed()
                    } else {
                        false
                    }
                };

                // Check if all revealed
                if should_resolve {
                    self.resolve_round().await;
                }
            }

            LiarsDiceMessage::PlayerForfeit { player_chain } => {
                self.assert_game_chain(chain_type);
                log::info!("Player {:?} forfeited", player_chain);

                // Eliminate the forfeiting player
                let should_end = {
                    if let Some(ref mut game) = *self.state.current_game.get_mut() {
                        if let Some(player) = game.get_player_mut_by_chain(&player_chain) {
                            player.eliminated = true;
                            player.dice_count = 0;
                            player.result = abi::game::GameResult::Lost;
                            log::info!("Player {:?} eliminated due to forfeit", player_chain);
                        }

                        // Update total dice count
                        game.total_dice = game.players.iter().map(|p| p.dice_count).sum();

                        // Check if game should end
                        let active_count = game.players.iter().filter(|p| !p.eliminated).count();
                        active_count == 1
                    } else {
                        false
                    }
                };

                // If only one player left, end the game
                if should_end {
                    let timestamp = self.runtime.system_time();
                    let (game_data, winner_chain, loser_chain) = {
                        let game = self.state.current_game.get_mut();
                        if let Some(ref mut game) = *game {
                            let winner = game.players.iter()
                                .find(|p| !p.eliminated)
                                .and_then(|p| p.chain_id);

                            if let Some(winner_chain) = winner {
                                game.winner = Some(winner_chain);
                                game.phase = GamePhase::GameOver;
                                game.ended_at = Some(timestamp);

                                if let Some(winner_player) = game.get_player_mut_by_chain(&winner_chain) {
                                    winner_player.result = abi::game::GameResult::Won;
                                }

                                (Some(game.clone()), Some(winner_chain), player_chain)
                            } else {
                                (None, None, player_chain)
                            }
                        } else {
                            (None, None, player_chain)
                        }
                    };

                    // Send game result messages
                    if let (Some(game_state), Some(winner)) = (game_data, winner_chain) {
                        // ✅ FIX: Get actual ELOs from players
                        let winner_elo = game_state.players.iter()
                            .find(|p| p.chain_id == Some(winner))
                            .map(|p| p.elo)
                            .unwrap_or(STARTING_ELO);

                        let loser_elo = game_state.players.iter()
                            .find(|p| p.chain_id == Some(loser_chain))
                            .map(|p| p.elo)
                            .unwrap_or(STARTING_ELO);

                        let elo_change = calculate_elo_change(winner_elo, loser_elo, true);
                        let player_chains: Vec<ChainId> = game_state.players
                            .iter()
                            .filter_map(|p| p.chain_id)
                            .collect();

                        for chain_id in player_chains {
                            self.message_manager(
                                chain_id,
                                LiarsDiceMessage::GameResult {
                                    game: game_state.clone(),
                                    winner,
                                    loser: loser_chain,
                                    elo_change,
                                },
                            );
                        }

                        self.runtime.emit(
                            LIARS_DICE_STREAM_NAME.into(),
                            &LiarsDiceEvent::GameEnded {
                                game_id: game_state.game_id,
                                winner,
                                loser: loser_chain,
                            },
                        );

                        // ✅ FIX: Send leaderboard update to master chain
                        let winner_name = game_state.players.iter()
                            .find(|p| p.chain_id == Some(winner))
                            .map(|p| p.name.clone())
                            .unwrap_or_else(|| "Unknown".to_string());

                        let loser_name = game_state.players.iter()
                            .find(|p| p.chain_id == Some(loser_chain))
                            .map(|p| p.name.clone())
                            .unwrap_or_else(|| "Unknown".to_string());

                        let winner_new_elo = (winner_elo as i32 + elo_change) as u32;
                        let loser_new_elo = (loser_elo as i32 - elo_change.abs()).max(100) as u32;

                        let master_chain = self.get_master_chain();
                        self.message_manager(
                            master_chain,
                            LiarsDiceMessage::UpdateLeaderboard {
                                winner,
                                winner_name,
                                winner_new_elo,
                                loser: loser_chain,
                                loser_name,
                                loser_new_elo,
                            },
                        );
                    }
                }
            }

            // ============================================
            // MASTER CHAIN MESSAGES
            // ============================================
            LiarsDiceMessage::RequestLobbyInfo { user_chain } => {
                self.assert_master_chain(chain_type);
                log::info!("Lobby info requested by {:?}", user_chain);

                // Get first lobby chain and send to user
                let lobby_keys = self.state.lobby_chains.indices().await.expect("Failed to get lobby chains");
                if let Some(lobby_chain) = lobby_keys.into_iter().next() {
                    self.message_manager(
                        user_chain,
                        LiarsDiceMessage::LobbyInfo { lobby_chain },
                    );
                }
            }

            LiarsDiceMessage::UpdateLeaderboard {
                winner,
                winner_name,
                winner_new_elo,
                loser,
                loser_name,
                loser_new_elo,
            } => {
                self.assert_master_chain(chain_type);
                log::info!("Updating leaderboard - Winner: {} (ELO: {}), Loser: {} (ELO: {})",
                    winner_name, winner_new_elo, loser_name, loser_new_elo);

                // ✅ FIX: Load existing entry and update cumulatively
                let mut winner_entry = self.state.leaderboard.get(&winner).await
                    .expect("Failed to load winner leaderboard entry")
                    .unwrap_or_else(|| SimpleLeaderboardEntry {
                        player_id: Some(winner),
                        player_name: winner_name.clone(),
                        rank: 0,
                        elo: STARTING_ELO,
                        games_won: 0,
                        games_played: 0,
                        win_rate: 0,
                    });

                // Update cumulative stats for winner
                winner_entry.games_won += 1;
                winner_entry.games_played += 1;
                winner_entry.elo = winner_new_elo;
                // Calculate win rate in basis points (10000 = 100%)
                winner_entry.win_rate = if winner_entry.games_played > 0 {
                    (winner_entry.games_won * 10000) / winner_entry.games_played
                } else {
                    0
                };
                winner_entry.player_name = winner_name; // Update name in case it changed

                // Load existing entry for loser
                let mut loser_entry = self.state.leaderboard.get(&loser).await
                    .expect("Failed to load loser leaderboard entry")
                    .unwrap_or_else(|| SimpleLeaderboardEntry {
                        player_id: Some(loser),
                        player_name: loser_name.clone(),
                        rank: 0,
                        elo: STARTING_ELO,
                        games_won: 0,
                        games_played: 0,
                        win_rate: 0,
                    });

                // Update stats for loser (games_won stays same, ELO decreases)
                loser_entry.games_played += 1;
                loser_entry.elo = loser_new_elo;
                // Recalculate win rate in basis points (10000 = 100%)
                loser_entry.win_rate = if loser_entry.games_played > 0 {
                    (loser_entry.games_won * 10000) / loser_entry.games_played
                } else {
                    0
                };
                loser_entry.player_name = loser_name; // Update name in case it changed

                // Store updated entries (not overwriting - updating cumulative stats)
                self.state.leaderboard.insert(&winner, winner_entry.clone())
                    .expect("Failed to update winner leaderboard entry");
                self.state.leaderboard.insert(&loser, loser_entry.clone())
                    .expect("Failed to update loser leaderboard entry");

                // Emit leaderboard update event
                self.runtime.emit(
                    LIARS_DICE_STREAM_NAME.into(),
                    &LiarsDiceEvent::LeaderboardUpdate {
                        entries: vec![winner_entry, loser_entry],
                    },
                );
            }
        }
    }

    async fn process_streams(&mut self, updates: Vec<linera_sdk::linera_base_types::StreamUpdate>) {
        for update in updates {
            assert_eq!(
                update.stream_id.stream_name,
                LIARS_DICE_STREAM_NAME.into(),
                "Unexpected stream name"
            );

            for index in update.new_indices() {
                let event: LiarsDiceEvent = self
                    .runtime
                    .read_event(update.chain_id, LIARS_DICE_STREAM_NAME.into(), index);

                log::debug!("Received event from chain {}: {:?}", update.chain_id, event);

                match event {
                    LiarsDiceEvent::GameState { game } => {
                        // Update user's view of game state
                        self.state.channel_game_state.set(Some(game.clone()));
                        log::info!("Updated game state: game_id={}, phase={:?}", game.game_id, game.phase);
                    }
                    LiarsDiceEvent::QueueUpdate { players_in_queue } => {
                        self.state.queue_count.set(players_in_queue);
                        log::info!("Queue updated: {} players waiting", players_in_queue);
                    }
                    LiarsDiceEvent::ProfileUpdate { profile } => {
                        log::info!("Profile update received: {}", profile.name);
                    }
                    LiarsDiceEvent::BidUpdate { game_id, bid } => {
                        log::info!("Bid update in game {}: {:?}", game_id, bid);
                    }
                    LiarsDiceEvent::LiarCalledEvent { game_id, caller } => {
                        log::info!("Liar called in game {} by {:?}", game_id, caller);
                    }
                    LiarsDiceEvent::DiceRevealed { game_id, player, dice } => {
                        log::info!("Dice revealed in game {} by {:?}: {:?}", game_id, player, dice);
                    }
                    LiarsDiceEvent::RoundEnded { game_id, loser, round } => {
                        log::info!("Round {} ended in game {}, loser: {:?}", round, game_id, loser);
                    }
                    LiarsDiceEvent::GameEnded { game_id, winner, loser } => {
                        log::info!("Game {} ended: winner={:?}, loser={:?}", game_id, winner, loser);
                    }
                    LiarsDiceEvent::LeaderboardUpdate { entries } => {
                        log::info!("Leaderboard updated with {} entries", entries.len());
                    }
                }
            }
        }
    }

    async fn store(mut self) {
        self.state.save().await.expect("Failed to save state");
    }
}

impl LiarsDiceContract {
    /// Send a message to another chain with tracking
    fn message_manager(&mut self, destination: ChainId, message: LiarsDiceMessage) {
        self.runtime
            .prepare_message(message)
            .with_tracking()
            .send_to(destination);
    }

    /// Assert this is a user chain
    fn assert_user_chain(&self, chain_type: u64) {
        assert_eq!(chain_type, 3, "This operation requires a User chain (type 3)");
    }

    /// Assert this is a master chain
    fn assert_master_chain(&self, chain_type: u64) {
        assert_eq!(chain_type, 0, "This operation requires a Master chain (type 0)");
    }

    /// Assert this is a lobby chain
    fn assert_lobby_chain(&self, chain_type: u64) {
        assert!(
            chain_type == 1 || chain_type == 0,
            "This operation requires a Lobby chain (type 1) or Master chain (type 0), got type {}",
            chain_type
        );
    }

    /// Assert this is a game chain (type 0 allowed for single-chain Docker deployment)
    fn assert_game_chain(&self, chain_type: u64) {
        assert!(
            chain_type == 2 || chain_type == 0,
            "This operation requires a Game chain (type 2) or Master chain (type 0), got type {}",
            chain_type
        );
    }

    // ============================================
    // BANKROLL INTEGRATION HELPERS
    // ============================================

    /// Get balance from bankroll application
    fn bankroll_get_balance(&mut self) -> Amount {
        let owner = self.runtime.application_id().into();
        let bankroll_app_id = self.get_bankroll();
        let response = self.runtime.call_application(true, bankroll_app_id, &BankrollOperation::Balance { owner });
        match response {
            BankrollResponse::Balance(balance) => balance,
            response => {
                log::error!("Unexpected response from Bankroll application: {:?}", response);
                Amount::ZERO
            }
        }
    }

    /// Update balance in bankroll application
    fn bankroll_update_balance(&mut self, amount: Amount) {
        let owner = self.runtime.application_id().into();
        let bankroll_app_id = self.get_bankroll();
        let _ = self.runtime.call_application(true, bankroll_app_id, &BankrollOperation::UpdateBalance { owner, amount });
    }

    /// Mint tokens via bankroll application (master chain only)
    fn bankroll_mint_token(&mut self, chain_id: ChainId, amount: Amount) {
        let bankroll_app_id = self.get_bankroll();
        let _ = self.runtime.call_application(true, bankroll_app_id, &BankrollOperation::MintToken { chain_id, amount });
        log::info!("Minted {} tokens for chain {:?}", amount, chain_id);
    }

    /// Try to match players in the queue
    async fn try_match_players(&mut self) {
        let queue_count = *self.state.queue_count.get();
        if queue_count < 2 {
            return;
        }

        // Get two players from queue
        let player1 = match self.state.matchmaking_queue.front().await {
            Ok(Some(p)) => p,
            _ => return,
        };
        self.state.matchmaking_queue.delete_front();

        let player2 = match self.state.matchmaking_queue.front().await {
            Ok(Some(p)) => p,
            _ => {
                // Put player1 back
                self.state.matchmaking_queue.push_back(player1);
                return;
            }
        };
        self.state.matchmaking_queue.delete_front();

        // Update queue count
        let count = self.state.queue_count.get_mut();
        *count = count.saturating_sub(2);

        // Get available game chain (DEMO: use current chain if none available)
        let game_chain = match self.state.available_game_chains.front().await {
            Ok(Some(gc)) => {
                self.state.available_game_chains.delete_front();
                gc
            },
            _ => {
                // DEMO: Use current chain as game chain for single-chain deployment
                log::info!("No registered game chains, using current chain for game");
                self.runtime.chain_id()
            }
        };

        // Track active game chain
        let game_chain_info = abi::management::GameChainInfo::new(game_chain, self.runtime.system_time());
        self.state.active_game_chains.insert(&game_chain, game_chain_info).expect("Failed to insert game chain");

        // Create game ID
        let game_id = self.runtime.system_time().micros();

        log::info!(
            "Matched {} vs {} on game chain {:?}",
            player1.name, player2.name, game_chain
        );

        // Notify players of match
        self.message_manager(
            player1.chain_id,
            LiarsDiceMessage::MatchFound {
                game_chain,
                game_id,
                opponent_name: player2.name.clone(),
                opponent_elo: player2.elo,
            },
        );
        self.message_manager(
            player2.chain_id,
            LiarsDiceMessage::MatchFound {
                game_chain,
                game_id,
                opponent_name: player1.name.clone(),
                opponent_elo: player1.elo,
            },
        );

        // Assign match to game chain
        self.message_manager(
            game_chain,
            LiarsDiceMessage::AssignMatch {
                game_id,
                player1,
                player2,
            },
        );
    }

    /// Resolve the round after all reveals
    async fn resolve_round(&mut self) {
        let timestamp = self.runtime.system_time();

        // Phase 1: Compute everything and modify game state in one borrow scope
        enum ResolveOutcome {
            None,
            RoundEnd {
                game_state: LiarsDiceGame,
                player_chains: Vec<ChainId>,
                loser: ChainId,
                actual_count: u8,
                bid_was_valid: bool,
                game_id: u64,
                round: u32,
            },
            GameOver {
                game_state: LiarsDiceGame,
                player_chains: Vec<ChainId>,
                loser: ChainId,
                winner: ChainId,
                actual_count: u8,
                bid_was_valid: bool,
                game_id: u64,
                elo_change: i32,
            },
        }

        let outcome = {
            let game = self.state.current_game.get_mut();
            if game.is_none() {
                ResolveOutcome::None
            } else {
                let game = game.as_mut().unwrap();

                let bid = match &game.current_bid {
                    Some(b) => b.clone(),
                    None => return,
                };

                let actual_count = game.count_total_dice(bid.face, true);
                let bid_was_valid = actual_count >= bid.quantity;

                // Determine loser
                let loser = if bid_was_valid {
                    game.liar_caller.clone().expect("No liar caller")
                } else {
                    bid.bidder.clone().expect("No bidder")
                };

                // Apply penalty to loser
                if let Some(player) = game.get_player_mut_by_chain(&loser) {
                    player.lose_die();
                }

                // Update total dice
                game.total_dice = game.players.iter().map(|p| p.dice_count).sum();

                // Collect player chains
                let player_chains: Vec<ChainId> = game.players
                    .iter()
                    .filter_map(|p| p.chain_id)
                    .collect();

                // Check for game over
                let active_count = game.players.iter().filter(|p| !p.eliminated).count();

                if active_count == 1 {
                    // Game over!
                    let winner_player = game.players.iter()
                        .find(|p| !p.eliminated)
                        .expect("No winner player");
                    let winner = winner_player.chain_id.expect("No winner chain ID");
                    let winner_elo = winner_player.elo;

                    let loser_player = game.players.iter()
                        .find(|p| p.chain_id.as_ref() == Some(&loser))
                        .expect("No loser player");
                    let loser_elo = loser_player.elo;

                    game.winner = Some(winner);
                    game.phase = GamePhase::GameOver;
                    game.ended_at = Some(timestamp);

                    // Calculate ELO change using ACTUAL player ELOs
                    let elo_change = calculate_elo_change(winner_elo, loser_elo, true);

                    ResolveOutcome::GameOver {
                        game_state: game.clone(),
                        player_chains,
                        loser,
                        winner,
                        actual_count,
                        bid_was_valid,
                        game_id: game.game_id,
                        elo_change,
                    }
                } else {
                    // Start new round
                    let game_id = game.game_id;
                    game.new_round();
                    let round = game.round - 1;

                    ResolveOutcome::RoundEnd {
                        game_state: game.clone(),
                        player_chains,
                        loser,
                        actual_count,
                        bid_was_valid,
                        game_id,
                        round,
                    }
                }
            }
        };

        // Phase 2: Send messages and emit events (no more mutable borrow)
        match outcome {
            ResolveOutcome::None => {}
            ResolveOutcome::RoundEnd {
                game_state,
                player_chains,
                loser,
                actual_count,
                bid_was_valid,
                game_id,
                round,
            } => {
                for chain_id in player_chains {
                    self.message_manager(
                        chain_id,
                        LiarsDiceMessage::RoundResult {
                            game: game_state.clone(),
                            loser,
                            actual_count,
                            bid_was_valid,
                        },
                    );
                }

                self.runtime.emit(
                    LIARS_DICE_STREAM_NAME.into(),
                    &LiarsDiceEvent::RoundEnded {
                        game_id,
                        loser,
                        round,
                    },
                );
            }
            ResolveOutcome::GameOver {
                game_state,
                player_chains,
                loser,
                winner,
                actual_count,
                bid_was_valid,
                game_id,
                elo_change,
            } => {
                for chain_id in &player_chains {
                    self.message_manager(
                        *chain_id,
                        LiarsDiceMessage::RoundResult {
                            game: game_state.clone(),
                            loser,
                            actual_count,
                            bid_was_valid,
                        },
                    );
                }

                for chain_id in player_chains {
                    self.message_manager(
                        chain_id,
                        LiarsDiceMessage::GameResult {
                            game: game_state.clone(),
                            winner,
                            loser,
                            elo_change,
                        },
                    );
                }

                self.runtime.emit(
                    LIARS_DICE_STREAM_NAME.into(),
                    &LiarsDiceEvent::GameEnded {
                        game_id,
                        winner,
                        loser,
                    },
                );

                // ✅ FIX BUG #25: Send GameEnded to lobby chain to return game chain to pool
                let lobby_chain = self.get_lobby_chain();
                let game_chain = self.runtime.chain_id();
                self.message_manager(
                    lobby_chain,
                    LiarsDiceMessage::GameEnded {
                        game_chain,
                        winner,
                        loser,
                    },
                );
                log::info!("Sent GameEnded to lobby chain {:?} to return game chain {:?}", lobby_chain, game_chain);

                // ✅ FIX BUG #26: Send UpdateLeaderboard to master chain
                let winner_player = game_state.players.iter()
                    .find(|p| p.chain_id == Some(winner));
                let loser_player = game_state.players.iter()
                    .find(|p| p.chain_id == Some(loser));

                if let (Some(wp), Some(lp)) = (winner_player, loser_player) {
                    let winner_new_elo = (wp.elo as i32 + elo_change) as u32;
                    let loser_new_elo = (lp.elo as i32 - elo_change.abs()).max(100) as u32;

                    let master_chain = self.get_master_chain();
                    self.message_manager(
                        master_chain,
                        LiarsDiceMessage::UpdateLeaderboard {
                            winner,
                            winner_name: wp.name.clone(),
                            winner_new_elo,
                            loser,
                            loser_name: lp.name.clone(),
                            loser_new_elo,
                        },
                    );
                    log::info!("Sent UpdateLeaderboard to master chain {:?}", master_chain);
                }

                // Mark game chain as available again
                self.state.game_chain_available.set(true);
                let games_hosted = self.state.games_hosted.get_mut();
                *games_hosted += 1;
                self.state.current_game.set(None);
            }
        }
    }

    // ============================================
    // HELPER METHODS - Parameter caching to avoid runtime.application_parameters() panics
    // ============================================

    /// Get master chain ID with caching
    fn get_master_chain(&mut self) -> ChainId {
        if let Some(chain_id) = *self.state.cached_master_chain.get() {
            chain_id
        } else {
            let params = self.runtime.application_parameters();
            self.state.cached_master_chain.set(Some(params.master_chain));
            params.master_chain
        }
    }

    /// Get bankroll application ID with caching
    fn get_bankroll(&mut self) -> ApplicationId<BankrollAbi> {
        if let Some(app_id) = self.state.cached_bankroll.get().clone() {
            app_id
        } else {
            let params = self.runtime.application_parameters();
            self.state.cached_bankroll.set(Some(params.bankroll.clone()));
            params.bankroll
        }
    }

    /// Get lobby chain ID with caching
    fn get_lobby_chain(&mut self) -> ChainId {
        if let Some(chain_id) = *self.state.cached_lobby_chain.get() {
            chain_id
        } else {
            let params = self.runtime.application_parameters();
            self.state.cached_lobby_chain.set(Some(params.lobby_chain));
            params.lobby_chain
        }
    }
}
