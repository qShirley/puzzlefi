module puzzlefi::puzzle_game {

    use std::u256;
    use moveos_std::event::emit;
    use puzzlefi::puzzlefi_coin;
    use puzzlefi::puzzlefi_coin::{PFC, borrow_coin_info};
    use moveos_std::table;
    use moveos_std::table::Table;
    use rooch_framework::simple_rng;
    use rooch_framework::coin;
    use rooch_framework::account_coin_store;
    use moveos_std::tx_context::sender;
    use moveos_std::object;
    use moveos_std::timestamp::now_milliseconds;
    use moveos_std::object::{Object, transfer};
    use rooch_framework::coin_store;
    use moveos_std::account::{move_resource_to, borrow_mut_resource, borrow_resource};
    use moveos_std::signer::{module_signer, address_of};
    use rooch_framework::gas_coin::GasCoin;
    use rooch_framework::coin_store::CoinStore;

    const DEFAULT_PROTOCOL_FEE: u256 = 5;
    const PROTOCOL_FEE_PRECISION: u256 = 1000;
    const ErrorNotOpen: u64 = 1;
    const ErrorStakeAmount: u64 = 2;
    const ErrorGuessingNumber: u64 = 3;
    const ErrorBetAmount: u64 = 4;
    const ErrorGameNotExists: u64 = 5;

    struct Global<phantom CoinType: key+store> has key {
        current_round: u64,
        coin_store: Object<CoinStore<CoinType>>,
        // The total amount of PuzzleFi Coin(PFC<CoinType>) currently in circulation
        // total_pfc_amount: u256,
        last_update_timestamp: u64,
        minimum_stake_amount: u256,
        maximum_stake_amount: u256,
        minimum_bet_amount: u256,
        maximum_bet_amount: u256,
        finger_game_record: Table<u64, FingerGame<CoinType>>,
        // 100 is 1%
        protocol_fee: u256,
        protocol_fee_store: Object<CoinStore<CoinType>>,
        is_open: bool
    }

    struct FingerGame<phantom CoinType: key+store> has key, store {
        round: u64,
        is_fininsh: bool,
        coin: Object<CoinStore<CoinType>>,
        amount: u256,
        player_guessing: u64,
        protocol_result: u64,
        player: address,
        winner: address
    }

    /// Capability to modify parameter
    struct AdminCap has key, store, drop {}


    struct SettleGameEvent has copy, drop {
        round: u64,
        amount: u256,
        winner: address
    }

    fun init() {
        let signer = module_signer<Global<GasCoin>>();
        move_resource_to(&signer, Global<GasCoin>{
            current_round: 0,
            coin_store: coin_store::create_coin_store<GasCoin>(),
            last_update_timestamp: now_milliseconds(),
            // 1 RGC
            minimum_stake_amount: 1 * u256::pow(10, 8),
            // 100 RGC
            maximum_stake_amount: 100 * u256::pow(10, 8),
            // 1 RGC
            minimum_bet_amount: 1 * u256::pow(10, 8),
            // 500 RGC
            maximum_bet_amount: 500 * u256::pow(10, 8),
            finger_game_record: table::new(),
            protocol_fee: DEFAULT_PROTOCOL_FEE,
            protocol_fee_store: coin_store::create_coin_store<GasCoin>(),
            is_open: true
        });
        let admin_cap = object::new_named_object(AdminCap {});
        transfer(admin_cap, sender())
    }

    public entry fun stake<CoinType: key+store>(
        signer: &signer,
        amount: u256
    ){
        do_stake<CoinType>(signer, amount)
    }

    public fun do_stake<CoinType: key+store>(
        signer: &signer,
        amount: u256
    ){
        settlement_finger_game<CoinType>();
        let module_signer = module_signer<Global<CoinType>>();
        let global = borrow_mut_resource<Global<CoinType>>(address_of(&module_signer));
        assert!(global.is_open, ErrorNotOpen);
        let stake_coin = account_coin_store::withdraw<CoinType>(signer, amount);
        let coin_value = coin::value(&stake_coin);
        assert!(coin_value>= global.minimum_stake_amount, ErrorStakeAmount);
        assert!(coin_value<= global.maximum_stake_amount, ErrorStakeAmount);

        let total_pfc_supply = coin::supply(borrow_coin_info<CoinType>());
        let new_pfc_amount =  calculate_pfc_amount(coin_value, coin_store::balance(&global.coin_store), total_pfc_supply);
        global.last_update_timestamp = now_milliseconds();
        // stake coin into coin store
        coin_store::deposit(&mut global.coin_store, stake_coin);
        // mint pfc coin
        account_coin_store::deposit(sender(), puzzlefi_coin::mint<CoinType>(new_pfc_amount));
    }
    public entry fun redeem<CoinType: key+store>(
        signer: &signer,
        pfc_amount: u256
    ){
        do_redeem<CoinType>(signer, pfc_amount)
    }

    public fun do_redeem<CoinType: key+store>(
        signer: &signer,
        pfc_amount: u256
    ){
        settlement_finger_game<CoinType>();
        let total_pfc_supply = coin::supply(borrow_coin_info<CoinType>());
        let module_signer = module_signer<Global<CoinType>>();
        let global = borrow_mut_resource<Global<CoinType>>(address_of(&module_signer));
        assert!(global.is_open, ErrorNotOpen);
        let redeem_coin_amount = calculate_coin_amount(pfc_amount, coin_store::balance(&global.coin_store), total_pfc_supply);
        let redeem_coin =  coin_store::withdraw(&mut global.coin_store, redeem_coin_amount);
        let protocol_fee = calculate_protocol_fee(redeem_coin_amount, global.protocol_fee);
        let protocol_coin = coin::extract(&mut redeem_coin, protocol_fee);
        coin_store::deposit(&mut global.protocol_fee_store, protocol_coin);
        account_coin_store::deposit(sender(), redeem_coin);
        // withdrow and burn pfc coin
        puzzlefi_coin::burn(account_coin_store::withdraw<PFC<CoinType>>(signer, pfc_amount));
        global.last_update_timestamp = now_milliseconds();
    }

    /// the finger-guessing game,
    /// The lucky star is 0
    /// The stone is 1-3
    /// The Scissor is 4-6
    /// The paper is 7-9
    public entry fun new_finger_game<CoinType: key+store>(
        signer: &signer,
        player_guessing: u64,
        bet_amount: u256,
    ){
        settlement_finger_game<CoinType>();
        assert!(player_guessing <= 9, ErrorGuessingNumber);
        let module_signer = module_signer<Global<CoinType>>();
        let global = borrow_mut_resource<Global<CoinType>>(address_of(&module_signer));
        assert!(global.is_open, ErrorNotOpen);

        if (!table::contains(&global.finger_game_record, global.current_round)) {
            let bet_coin = account_coin_store::withdraw<CoinType>(signer, bet_amount);
            let coin_value = coin::value(&bet_coin);
            assert!(coin_value>= global.minimum_bet_amount, ErrorBetAmount);
            assert!(coin_value<= global.maximum_bet_amount, ErrorBetAmount);
            let protocol_coin = if (player_guessing == 0) {
                coin_store::withdraw(&mut global.coin_store, bet_amount * 8)
            }else {
                coin_store::withdraw(&mut global.coin_store, bet_amount)
            };
            let new_game = FingerGame<CoinType>{
                round: global.current_round,
                is_fininsh: false,
                coin: coin_store::create_coin_store(),
                amount: bet_amount,
                player_guessing,
                protocol_result: 10000,
                player: sender(),
                winner: @rooch_framework
            };
            coin_store::deposit(&mut new_game.coin, bet_coin);
            coin_store::deposit(&mut new_game.coin, protocol_coin);
            table::add(&mut global.finger_game_record, global.current_round, new_game);
            global.last_update_timestamp = now_milliseconds()
        }
    }

    fun settlement_finger_game<CoinType: key+store>(){
        let module_signer = module_signer<Global<CoinType>>();
        let global = borrow_mut_resource<Global<CoinType>>(address_of(&module_signer));
        assert!(global.is_open, ErrorNotOpen);
        if (table::contains(&global.finger_game_record, global.current_round)){
            let game = table::borrow_mut(&mut global.finger_game_record, global.current_round);
            game.is_fininsh = true;
            let reward_amount = coin_store::balance(&game.coin);
            let reward_coin = coin_store::withdraw(&mut game.coin, reward_amount);
            let protocol_result = simple_rng::rand_u64_range(0, 10);
            game.protocol_result = protocol_result;
            if (protocol_result == 0) {
                let winner = if (game.player_guessing == 0) {
                    if (account_coin_store::is_accept_coin<CoinType>(game.player)){
                        account_coin_store::deposit(game.player, reward_coin);
                    }else {
                        coin_store::deposit(&mut global.coin_store, reward_coin)
                    };
                    game.winner = game.player;
                    game.winner
                }else {
                    coin_store::deposit(&mut global.coin_store, reward_coin);
                    game.winner = @0x0;
                    game.winner
                };
                emit(SettleGameEvent{
                    round: global.current_round,
                    amount: reward_amount,
                    winner,

                })
            }else {
                let winner = if (game.player_guessing == 0){
                    // player guessing is Lucky star
                    @0x0
                }else if (game.player_guessing < 4){
                    // player guessing is stone
                    if (protocol_result < 4) {
                        @rooch_framework
                    }else if(protocol_result < 7) {
                        game.player
                    }else {
                        @0x0
                    }
                }else if (game.player_guessing < 7) {
                    // player guessing is scissors
                    if (protocol_result < 4) {
                        @0x0
                    }else if(protocol_result < 7) {
                        @rooch_framework
                    }else {
                        game.player
                    }
                }else {
                    // player guessing is paper
                    if (protocol_result < 4) {
                        game.player
                    }else if(protocol_result < 7) {
                        @0x0
                    }else {
                        @rooch_framework
                    }
                };
                game.winner = winner;
                if (winner == game.player) {
                    if (account_coin_store::is_accept_coin<CoinType>(game.player)){
                        account_coin_store::deposit(game.player, reward_coin)
                    }else {
                        coin_store::deposit(&mut global.coin_store, reward_coin)
                    }
                }else if (winner == @0x0) {
                    coin_store::deposit(&mut global.coin_store, reward_coin)
                }else {
                    if (account_coin_store::is_accept_coin<CoinType>(game.player)){
                        account_coin_store::deposit(game.player, coin::extract(&mut reward_coin, reward_amount/2));
                    };
                    coin_store::deposit(&mut global.coin_store, reward_coin)
                };
                emit(SettleGameEvent{
                    round: global.current_round,
                    amount: reward_amount,
                    winner,

                })
            };

            global.current_round = global.current_round + 1;
            global.last_update_timestamp = now_milliseconds()
        }


    }

    /// Ensure the exchange rate remains unchanged
    /// current_stake_coin/current_pfc_amount == (coin_amount+current_stake_coin)/(new_pfc_amount + current_pfc_amount)
    /// Precision retention 0.0001
    public fun calculate_pfc_amount(
        coin_amount: u256,
        current_stake_coin: u256,
        current_pfc_amount: u256
    ): u256 {
        if (current_pfc_amount == 0) {
            return coin_amount + current_stake_coin
        };
        if (current_stake_coin == 0) {
            return coin_amount + current_pfc_amount
        };
        return ((coin_amount+current_stake_coin)*current_pfc_amount * 1000)/(current_stake_coin * 1000) - current_pfc_amount

    }
    /// Ensure the exchange rate remains unchanged
    /// current_pfc_amount/current_stake_coin == (current_pfc_amount-pfc_amount)/(current_stake_coin-redeem_coin)
    /// Precision retention 0.0001
    public fun calculate_coin_amount(
        pfc_amount: u256,
        current_stake_coin: u256,
        current_pfc_amount: u256
    ): u256 {
        if (current_pfc_amount != 0) {
            return current_stake_coin - (current_stake_coin * 1000 * (current_pfc_amount-pfc_amount) / (current_pfc_amount * 1000))
        };
        return 0
    }

    /// If (fee * amount) < PROTOCOL_FEE_PRECISION no protocol_fee
    public fun calculate_protocol_fee(
        amount: u256,
        fee: u256,
    ): u256{
        return (fee * amount / PROTOCOL_FEE_PRECISION)
    }

    public fun get_round_and_result<CoinType: key+store>(): (u64, u64, address){
        let module_signer = module_signer<Global<CoinType>>();
        let global = borrow_resource<Global<CoinType>>(address_of(&module_signer));
        if (global.current_round > 0 && table::contains(&global.finger_game_record, global.current_round - 1)) {
            let last_record = table::borrow(&global.finger_game_record, global.current_round - 1);
            return (global.current_round, last_record.protocol_result, last_record.winner)
        };
        (global.current_round, 1000, @std)
    }

    public fun get_coin_amount<CoinType: key+store>():(u256, u256){
        let module_signer = module_signer<Global<CoinType>>();
        let global = borrow_resource<Global<CoinType>>(address_of(&module_signer));
        (coin_store::balance(&global.coin_store), coin::supply(borrow_coin_info<CoinType>()))
    }


}
