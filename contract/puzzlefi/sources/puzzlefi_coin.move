module puzzlefi::puzzlefi_coin {
    use std::string;
    use moveos_std::object;
    use rooch_framework::coin::{CoinInfo, mint_extend, Coin};
    use moveos_std::object::Object;
    use moveos_std::signer::{module_signer, address_of};
    use moveos_std::account::{move_resource_to, borrow_mut_resource, borrow_resource};
    use rooch_framework::gas_coin::{GasCoin, decimals};
    use rooch_framework::coin;
    friend puzzlefi::puzzle_game;

    /// PuzzleFi Coin
    struct PFC<phantom CoinType: key+store> has key, store {}

    struct NativeCoinInfo<phantom CoinType: key+store> has key {
        coin_info_obj: Object<CoinInfo<PFC<CoinType>>>
    }
    fun init (){
        let coin_info_obj = coin::register_extend<PFC<GasCoin>>(
            string::utf8(b"PuzzleFi Coin"),
            string::utf8(b"PFC"),
            decimals(),
        );
        let module_signer = module_signer<NativeCoinInfo<GasCoin>>();
        move_resource_to(&module_signer, NativeCoinInfo<GasCoin>{
            coin_info_obj
        })
    }

    public entry fun register_extend<CoinType: key+store>(){
        let coin_info_obj = coin::register_extend<PFC<CoinType>>(
            string::utf8(b"PuzzleFi Coin"),
            string::utf8(b"PFC"),
            decimals(),
        );
        let module_signer = module_signer<NativeCoinInfo<CoinType>>();
        move_resource_to(&module_signer, NativeCoinInfo<CoinType>{
            coin_info_obj
        })
    }

    public(friend) fun borrow_coin_info<CoinType: key+store>(): &CoinInfo<PFC<CoinType>>{
        let module_signer = module_signer<PFC<CoinType>>();
        object::borrow(&borrow_resource<NativeCoinInfo<CoinType>>(address_of(&module_signer)).coin_info_obj)
    }
    public(friend) fun mint<CoinType: key+store>(amount: u256): Coin<PFC<CoinType>>{
        let module_signer = module_signer<PFC<CoinType>>();
        let coin_info_obj = borrow_mut_resource<NativeCoinInfo<CoinType>>(address_of(&module_signer));
        mint_extend<PFC<CoinType>>(&mut coin_info_obj.coin_info_obj, amount)
    }

    public fun burn<CoinType: key+store>(amount: Coin<PFC<CoinType>>) {
        let module_signer = module_signer<PFC<CoinType>>();
        let coin_info_obj = borrow_mut_resource<NativeCoinInfo<CoinType>>(address_of(&module_signer));
        coin::burn<PFC<CoinType>>(&mut coin_info_obj.coin_info_obj, amount)
    }
}
