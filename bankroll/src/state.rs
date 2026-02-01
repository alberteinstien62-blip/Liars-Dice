use bankroll::{DailyBonus, DebtRecord, PublicChainBalances, TokenPotRecord};
use linera_sdk::linera_base_types::{AccountOwner, Amount, ChainId};
use linera_sdk::views::{linera_views, MapView, RegisterView, RootView, ViewStorageContext};

#[derive(RootView, async_graphql::SimpleObject)]
#[view(context = ViewStorageContext)]
pub struct BankrollState {
    // All Chain
    pub game_token: RegisterView<Amount>,
    pub debt_log: MapView<u64, DebtRecord>,
    // Public Chain
    pub token_pot_log: MapView<u64, TokenPotRecord>,
    // User Chain
    pub daily_bonus: RegisterView<DailyBonus>,
    pub accounts: MapView<AccountOwner, Amount>,
    // Master Chain
    pub balances: MapView<ChainId, PublicChainBalances>,
    // Parameters (stored to avoid runtime.application_parameters() calls in Linera 0.15.7)
    pub master_chain: RegisterView<Option<ChainId>>,
    pub bonus_amount: RegisterView<Option<Amount>>,
}
