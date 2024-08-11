module puzzlefi::btc_swap {
    use std::option;
    use std::option::Option;
    use std::string::String;
    use moveos_std::object;
    use rooch_framework::coin::{Self, Coin};
    use std::vector;
    use moveos_std::table_vec;
    use moveos_std::table_vec::TableVec;
    use rooch_framework::bitcoin_address::{to_rooch_address, new_p2pkh};
    use bitcoin_move::types::{Transaction, tx_output, txout_value, tx_input, txout_object_address,
        txin_script_sig
    };
    use bitcoin_move::bitcoin;
    use moveos_std::event;
    use rooch_framework::account_coin_store;
    use puzzlefi::linked_table;
    use puzzlefi::linked_table::LinkedTable;
    use rooch_framework::coin_store;
    use moveos_std::tx_context::sender;
    use moveos_std::type_info::type_name;
    use moveos_std::object::{Object, ObjectID, to_shared, new_named_object, transfer, new};
    use rooch_framework::coin_store::{CoinStore, create_coin_store};
    use moveos_std::timestamp::{now_milliseconds, now_seconds};
    use puzzlefi::critbit::{CritbitTree, find_leaf, borrow_leaf_by_index, borrow_mut_leaf_by_index,
        remove_leaf_by_index
    };
    use puzzlefi::critbit;
    use moveos_std::table;
    use moveos_std::table::Table;

    const VERSION: u64 = 1;


    const BASE_MARKET_FEE: u256 = 20;
    const TRADE_FEE_BASE_RATIO: u256 = 1000;

    const MIN_BID_ORDER_ID: u64 = 1;
    const MIN_ASK_ORDER_ID: u64 = 1 << 63;

    const ErrorWrongVersion: u64 = 0;
    const ErrorWrongPaused: u64 = 1;
    const ErrorInputCoin: u64 = 2;
    const ErrorWrongMarket: u64 = 3;
    const ErrorPriceTooLow: u64 = 4;
    const ErrorWrongCreateBid: u64 = 5;
    const ErrorFeeTooHigh: u64 = 6;
    const ErrorInvalidOrderId: u64 = 7;
    const ErrorUnauthorizedCancel: u64 = 8;
    const ErrorOrderIsLock: u64 = 9;
    const ErrorTransactionInputLen: u64 = 10;
    const ErrorTransactionSender: u64 = 11;
    const ErrorOrderIsPendingCancel: u64 = 9;




    /// listing info in the market
    struct Order has key, store, drop {
        /// The order id of the order
        order_id: u64,
        /// The unit_price of the order
        unit_price: u64,
        /// the quantity of order
        quantity: u256,
        /// The owner of order
        owner: address,
        /// Last update timestamp
        last_update_time: u64,
        /// Is order lock
        is_lock: bool,
        /// Is pending cancel
        is_pending_cancel: bool,
        /// is bid order or listing order, now no bid
        is_bid: bool,
    }

    struct TickLevel has store {
        price: u64,
        // The key is order order id.
        open_orders: Object<LinkedTable<u64, Order>>,
        // other price level info
    }


    ///Record some important information of the market
    struct Marketplace<phantom BaseAsset: key + store> has key {
        /// is paused of market
        is_paused: bool,
        /// version of market
        version: u64,
        /// All open bid orders.
        bids: CritbitTree<TickLevel>,
        /// All open ask orders.
        asks: CritbitTree<TickLevel>,
        /// Order id of the next bid order, starting from 0.
        next_bid_order_id: u64,
        /// Order id of the next ask order, starting from 1<<63.
        next_ask_order_id: u64,
        /// Marketplace fee  of the marketplace
        fee: u256,
        /// User order info
        user_order_info: Table<address, Object<LinkedTable<u64, u64>>>,
        base_asset: Object<CoinStore<BaseAsset>>,
        /// Stores the trading fees paid in `BaseAsset`.
        base_asset_trading_fees: Object<CoinStore<BaseAsset>>,
        confirm_tx: TableVec<Transaction>,
        trade_info: TradeInfo
    }

    struct TradeInfo has store {
        timestamp: u64,
        yesterday_volume: u256,
        today_volume: u256,
        total_volume: u256,
        txs: u64
    }

    struct AdminCap has key, store {}

    struct MarketplaceHouse has key {
        market_info: Object<LinkedTable<String, ObjectID>>,
    }



    public entry fun create_market<BaseAsset: key + store>(
        market_house_obj: &mut Object<MarketplaceHouse>,
    ) {
        let market_obj = new(Marketplace {
            is_paused: false,
            version: VERSION,
            bids: critbit::new(),
            asks: critbit::new(),
            // Order id of the next bid order, starting from 0.
            next_bid_order_id: MIN_BID_ORDER_ID,
            // Order id of the next ask order, starting from 1<<63.
            next_ask_order_id: MIN_ASK_ORDER_ID,
            fee: BASE_MARKET_FEE,
            user_order_info: table::new(),
            base_asset: create_coin_store<BaseAsset>(),
            base_asset_trading_fees: create_coin_store<BaseAsset>(),
            confirm_tx: table_vec::new(),
            trade_info: TradeInfo{
                timestamp: now_milliseconds(),
                yesterday_volume: 0,
                today_volume: 0,
                total_volume: 0,
                txs: 0
            }
        });
        let object_id = object::id(&market_obj);
        let market_house = object::borrow_mut(market_house_obj);
        let type_name = type_name<BaseAsset>();
        linked_table::push_back(&mut market_house.market_info, type_name, object_id);
        to_shared(market_obj);
    }

    fun init() {
        let market_house = MarketplaceHouse {
            market_info: linked_table::new(),
        };

        //TODO market create event
        transfer(new_named_object(AdminCap{}), sender());
        to_shared(new_named_object(market_house))
    }

    ///Listing BaseAsset in the market
    public fun list<BaseAsset: key + store>(
        market_obj: &mut Object<Marketplace<BaseAsset>>,
        coin: Coin<BaseAsset>,
        unit_price: u64,
    ) {
        let market = object::borrow_mut(market_obj);
        assert!(market.version == VERSION, ErrorWrongVersion);
        assert!(market.is_paused == false, ErrorWrongPaused);
        let quantity = coin::value(&coin);
        let order_id = market.next_ask_order_id;
        market.next_ask_order_id = market.next_ask_order_id + 1;
        assert!(unit_price > 0, ErrorPriceTooLow);
        let asks = Order {
            order_id,
            unit_price,
            quantity,
            owner: sender(),
            is_lock: false,
            last_update_time: now_seconds(),
            is_bid: false,
            is_pending_cancel: false
        };
        coin_store::deposit(&mut market.base_asset, coin);
        let (find_price, index) = critbit::find_leaf(&market.asks, unit_price);
        if (find_price) {
            critbit::insert_leaf(&mut market.asks, unit_price, TickLevel{
                price: unit_price,
                open_orders: linked_table::new()
            });
        };
        let tick_level = critbit::borrow_mut_leaf_by_index(&mut market.asks, index);
        linked_table::push_back(&mut tick_level.open_orders, order_id, asks);

        if (!table::contains(&market.user_order_info, sender())) {
            table::add(&mut market.user_order_info, sender(), linked_table::new());
        };
        linked_table::push_back(table::borrow_mut(&mut market.user_order_info, sender()), order_id, unit_price);

    }



    ///Cancel the listing order
    public entry fun cancel_order<BaseAsset: key + store>(
        market_obj: &mut Object<Marketplace<BaseAsset>>,
        order_id: u64,
    ) {
        //Get the list from the collection
        let market = object::borrow_mut(market_obj);
        assert!(market.version == VERSION, ErrorWrongVersion);

        let usr_open_orders = table::borrow_mut(&mut market.user_order_info, sender());
        let tick_price = *linked_table::borrow(usr_open_orders, order_id);
        let is_bid = order_is_bid(order_id);
        let (tick_exists, tick_index) = find_leaf(if (is_bid) { &market.bids } else { &market.asks }, tick_price);
        assert!(tick_exists, ErrorInvalidOrderId);
        let order_mut = borrow_mut_order(
            if (is_bid) { &mut market.bids } else { &mut market.asks },
            tick_index,
            order_id,
        );
        if (order_mut.is_lock){
            order_mut.is_pending_cancel = true;
            return
        };
        let order = remove_order(
            if (is_bid) { &mut market.bids } else { &mut market.asks },
            usr_open_orders,
            tick_index,
            order_id,
            sender()
        );
        assert!(!order.is_lock, ErrorOrderIsLock);
        account_coin_store::deposit(sender(), coin_store::withdraw(&mut market.base_asset, order.quantity))
    }

    public fun confirm_order<BaseAsset: key + store>(
        market_obj: &mut Object<Marketplace<BaseAsset>>,
        order_id: u64,
        assert_order_exist: bool
    ){
        let market = object::borrow_mut(market_obj);
        assert!(market.is_paused == false, ErrorWrongPaused);
        assert!(market.version == VERSION, ErrorWrongVersion);
        let usr_open_orders = table::borrow_mut(&mut market.user_order_info, sender());
        let tick_price = *linked_table::borrow(usr_open_orders, order_id);
        let (tick_exists, tick_index) = find_leaf(&market.asks, tick_price);
        // Return non-existent orders to none instead of panic during bulk buying
        if (!assert_order_exist && !tick_exists) {
            return
        };
        assert!(tick_exists, ErrorInvalidOrderId);
        let order = borrow_mut_order(&mut market.asks, tick_index, order_id);
        assert!(!order.is_lock, ErrorOrderIsLock);
        assert!(!order.is_pending_cancel, ErrorOrderIsPendingCancel);
        order.is_lock = true;
        order.last_update_time = now_seconds()
    }
    ///purchase
    public fun buy<BaseAsset: key + store>(
        market_obj: &mut Object<Marketplace<BaseAsset>>,
        order_id: u64,
        assert_order_exist: bool,
        txid: address,
    ): Option<Coin<BaseAsset>> {
        let market = object::borrow_mut(market_obj);
        assert!(market.is_paused == false, ErrorWrongPaused);
        assert!(market.version == VERSION, ErrorWrongVersion);
        let usr_open_orders = table::borrow_mut(&mut market.user_order_info, sender());
        let tick_price = *linked_table::borrow(usr_open_orders, order_id);
        let (tick_exists, tick_index) = find_leaf(&market.asks, tick_price);
        // Return non-existent orders to none instead of panic during bulk buying
        if (!assert_order_exist && !tick_exists) {
            return option::none()
        };
        assert!(tick_exists, ErrorInvalidOrderId);
        let order = remove_order(&mut market.asks, usr_open_orders, tick_index, order_id, sender());
        assert!(!order.is_lock, ErrorOrderIsLock);
        let total_price = order.quantity * (order.unit_price as u256);
        let transaction = option::destroy_some(bitcoin::get_tx(txid));
        asset_transaction_sender(&transaction, sender());
        let amount = effective_transaction_amount(&transaction, order.owner);
        table_vec::push_back(&mut market.confirm_tx, transaction);
        assert!((amount as u256) >= total_price, ErrorInputCoin);
        let trade_info = &mut market.trade_info;
        trade_info.total_volume = trade_info.total_volume + total_price;
        trade_info.txs = trade_info.txs + 1;
        if (now_milliseconds() - trade_info.timestamp > 86400000) {
            trade_info.yesterday_volume = trade_info.today_volume;
            trade_info.today_volume = total_price;
            trade_info.timestamp = now_milliseconds();
        }else {
            trade_info.today_volume = trade_info.today_volume + total_price;
        };

        let trade_fee = total_price * market.fee / TRADE_FEE_BASE_RATIO;
        let trade_coin = coin_store::withdraw(&mut market.base_asset, order.quantity);
        coin_store::deposit(&mut market.base_asset_trading_fees, coin::extract(&mut trade_coin, trade_fee));
        option::some(trade_coin)
    }



    public entry fun withdraw_profits<BaseAsset: key + store>(
        _admin: &mut Object<AdminCap>,
        market_obj: &mut Object<Marketplace<BaseAsset>>,
        receiver: address,
    ) {
        let market = object::borrow_mut(market_obj);
        assert!(market.version == VERSION, ErrorWrongVersion);
        let base_amount = coin_store::balance(&market.base_asset_trading_fees);
        account_coin_store::deposit(receiver, coin_store::withdraw(&mut market.base_asset_trading_fees, base_amount));
    }


    public entry fun update_market_fee<BaseAsset: key + store>(
        _admin: &mut Object<AdminCap>,
        market_obj: &mut Object<Marketplace<BaseAsset>>,
        fee: u256,
    ) {
        let market = object::borrow_mut(market_obj);
        assert!(market.version == VERSION, ErrorWrongVersion);
        assert!(fee < TRADE_FEE_BASE_RATIO, ErrorFeeTooHigh);
        market.fee = fee
    }

    public entry fun migrate_marketplace<BaseAsset: key + store>(
        market_obj: &mut Object<Marketplace<BaseAsset>>,
    ) {
        let market = object::borrow_mut(market_obj);
        assert!(market.version <= VERSION, ErrorWrongVersion);
        market.version = VERSION;
    }


    fun borrow_mut_order(
        open_orders: &mut CritbitTree<TickLevel>,
        tick_index: u64,
        order_id: u64,
    ): &mut Order{
        let tick_level = borrow_leaf_by_index(open_orders, tick_index);
        assert!(linked_table::contains(&tick_level.open_orders, order_id), ErrorInvalidOrderId);
        let mut_tick_level = borrow_mut_leaf_by_index(open_orders, tick_index);
        linked_table::borrow_mut(&mut mut_tick_level.open_orders, order_id)
    }

    fun remove_order(
        open_orders: &mut CritbitTree<TickLevel>,
        user_order_info: &mut Object<LinkedTable<u64, u64>>,
        tick_index: u64,
        order_id: u64,
        user: address,
    ): Order {
        linked_table::remove(user_order_info, order_id);
        let tick_level = borrow_leaf_by_index(open_orders, tick_index);
        assert!(linked_table::contains(&tick_level.open_orders, order_id), ErrorInvalidOrderId);
        let mut_tick_level = borrow_mut_leaf_by_index(open_orders, tick_index);
        let order = linked_table::remove(&mut mut_tick_level.open_orders, order_id);
        assert!(order.owner == user, ErrorUnauthorizedCancel);
        if (linked_table::is_empty(&mut_tick_level.open_orders)) {
            destroy_empty_level(remove_leaf_by_index(open_orders, tick_index));
        };
        // only lock 12 hour
        if (now_seconds() > order.last_update_time + 43200){
            order.is_lock = false
        };
        order
    }

    fun destroy_empty_level(level: TickLevel) {
        let TickLevel {
            price: _,
            open_orders: orders,
        } = level;

        linked_table::destroy_empty(orders);
    }

    struct QueryOrderEvent has copy, drop {
        order_ids: vector<u64>,
        unit_prices: vector<u64>,
        quantitys: vector<u256>,
        owners: vector<address>,
        is_bids: vector<bool>
    }

    public fun query_order<BaseAsset: key + store>(
        market_obj: &Object<Marketplace<BaseAsset>>,
        query_bid: bool,
        from_order: Option<u64>,
        start: u64
    ): vector<u64> {
        let market = object::borrow(market_obj);
        let order_ids = vector<u64>[];
        let unit_prices = vector<u64>[];
        let quantitys = vector<u256>[];
        let owners = vector<address>[];
        let is_bids = vector<bool>[];

        if (query_bid) {
            let i = 0;
            let from = if (option::is_none(&from_order)) {
                let (key, _) = critbit::max_leaf(&market.bids);
                key
            }else {
                *option::borrow(&from_order)
            };
            let count = start;
            while (i < 50) {
                let tick_level = critbit::borrow_leaf_by_key(&market.bids, from);
                let order_count = linked_table::length(&tick_level.open_orders);

                while (order_count > count) {
                    let order = linked_table::borrow(&tick_level.open_orders, count);
                    vector::push_back(&mut order_ids, order.order_id);
                    vector::push_back(&mut unit_prices, order.unit_price);
                    vector::push_back(&mut quantitys, order.quantity);
                    vector::push_back(&mut owners, order.owner);
                    vector::push_back(&mut is_bids, order.is_bid);

                    count = count + 1;
                    i = i + 1;
                    if (i >= 50) {
                        event::emit(
                            QueryOrderEvent{
                                order_ids,
                                unit_prices,
                                quantitys,
                                owners,
                                is_bids
                            }
                        );
                        return order_ids
                    }
                };
                count = 0;
                let (key, index) = critbit::previous_leaf(&market.bids, from);
                if (index != 0x8000000000000000) {
                    from = key;
                }else {
                    event::emit(
                        QueryOrderEvent{
                            order_ids,
                            unit_prices,
                            quantitys,
                            owners,
                            is_bids
                        }
                    );
                    return order_ids
                }
            };
        }else {
            let i = 0;
            let from = if (option::is_none(&from_order)) {
                let (key, _) = critbit::min_leaf(&market.asks);
                key
            }else {
                *option::borrow(&from_order)
            };
            let count = start;
            while (i < 50) {
                let tick_level = critbit::borrow_leaf_by_key(&market.asks, from);
                let order_count = linked_table::length(&tick_level.open_orders);

                while (order_count > count) {
                    let order = linked_table::borrow(&tick_level.open_orders, count);
                    vector::push_back(&mut order_ids, order.order_id);
                    vector::push_back(&mut unit_prices, order.unit_price);
                    vector::push_back(&mut quantitys, order.quantity);
                    vector::push_back(&mut owners, order.owner);
                    vector::push_back(&mut is_bids, order.is_bid);

                    count = count + 1;
                    i = i + 1;
                    if (i >= 50) {
                        event::emit(
                            QueryOrderEvent{
                                order_ids,
                                unit_prices,
                                quantitys,
                                owners,
                                is_bids
                            }
                        );
                        return order_ids
                    }
                };
                count = 0;
                let (key, index) = critbit::next_leaf(&market.asks, from);
                if (index != 0x8000000000000000) {
                    from = key;
                }else {
                    event::emit(
                        QueryOrderEvent{
                            order_ids,
                            unit_prices,
                            quantitys,
                            owners,
                            is_bids
                        }
                    );
                    return order_ids
                }
            };
        };
        event::emit(
            QueryOrderEvent{
                order_ids,
                unit_prices,
                quantitys,
                owners,
                is_bids
            }
        );
        return order_ids
    }

    public fun query_user_order<BaseAsset: key + store>(
        market_obj: &Object<Marketplace<BaseAsset>>,
        user: address,
        from_order: Option<u64>,
        count: u64
    ): vector<u64>{
        let market = object::borrow(market_obj);
        let user_table = table::borrow(&market.user_order_info, user);
        let order_ids = vector<u64>[];
        let unit_prices = vector<u64>[];
        let quantitys = vector<u256>[];
        let owners = vector<address>[];
        let is_bids = vector<bool>[];
        let from = if (option::is_none(&from_order)) {
            *option::borrow(linked_table::front(user_table))
        }else {
            *option::borrow(&from_order)
        };

        let i = 0;
        while (i < count) {
            let tick_price = *linked_table::borrow(user_table, from);

            let is_bid = order_is_bid(from);
            let open_orders = if (is_bid) { &market.bids } else { &market.asks };
            let (tick_exists, tick_index) = find_leaf(open_orders, tick_price);
            if (tick_exists) {
                let tick_level = borrow_leaf_by_index(open_orders, tick_index);
                let order = linked_table::borrow(&tick_level.open_orders, from);
                vector::push_back(&mut order_ids, order.order_id);
                vector::push_back(&mut unit_prices, order.unit_price);
                vector::push_back(&mut quantitys, order.quantity);
                vector::push_back(&mut owners, order.owner);
                vector::push_back(&mut is_bids, order.is_bid);
                i = i + 1;
            }else {
                break
            };
            if (option::is_some(linked_table::next(user_table, from))){
                from = *option::borrow(linked_table::next(user_table, from));
            }else {
                break
            }
        };
        event::emit(
            QueryOrderEvent{
                order_ids,
                unit_prices,
                quantitys,
                owners,
                is_bids
            }
        );
        return order_ids
    }


    fun order_is_bid(order_id: u64): bool {
        return order_id < MIN_ASK_ORDER_ID
    }

    fun asset_transaction_sender(transaction: &Transaction, sender: address){
        let tx_inputs = tx_input(transaction);
        assert!(vector::length(tx_inputs) > 0, ErrorTransactionInputLen);
        let script_buf = txin_script_sig(vector::borrow(tx_inputs, 0));
        let script_buf_len = vector::length(script_buf);
        // only support p2pkh
        let p2pkh_pubkey = sub_vector(script_buf, script_buf_len - 20, script_buf_len);
        assert!(to_rooch_address(&new_p2pkh(p2pkh_pubkey)) == sender, ErrorTransactionSender);
    }

    fun effective_transaction_amount(transaction: &Transaction, addr: address): u64 {
        let outputs = tx_output(transaction);
        let len = vector::length(outputs);
        let amount = 0;
        while (len >0){
            let tx_output = vector::borrow(outputs, len-1);
            if (txout_object_address(tx_output) == addr) {
                amount = amount + txout_value(tx_output)
            };
            // let script_buf = txout_script_pubkey(tx_output);
            // if (is_p2pkh(script_buf)) {
            //     let bitcoin_addr_opt = get_address(script_buf);
            //     if (option::is_some(&bitcoin_addr_opt) && to_rooch_address(&option::extract(&mut bitcoin_addr_opt)) == addr) {
            //         amount = amount + txout_value(tx_output)
            //     }
            // };
            len = len-1;
        };
        amount
    }

    fun sub_vector(bytes: &vector<u8>, start: u64, end: u64): vector<u8>{
        let result = vector::empty();
        let i = start;
        while(i < end) {
            vector::push_back(&mut result, *vector::borrow(bytes, i));
            i = i + 1;
        };
        result
    }
}
