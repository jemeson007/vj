/// Interface representing `HelloContract`.
/// This interface allows modification and retrieval of the contract balance.
// #[starknet::interface]
// pub trait IHelloStarknet<TContractState> {
    /// Increase contract balance.
//    fn increase_balance(ref self: TContractState, amount: felt252);
    /// Retrieve contract balance.
//    fn get_balance(self: @TContractState) -> felt252;
// }

#[starknet::interface]
pub trait IPriceFeedExample<TContractState> {
    fn buy_item(ref self: TContractState);
    fn get_asset_price(self: @TContractState, asset_id: felt252) -> u128;
}


/// Simple contract for managing balance.
#[starknet::contract]
mod HelloStarknet {
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        balance: felt252,
    }

    #[abi(embed_v0)]
    impl HelloStarknetImpl of super::IHelloStarknet<ContractState> {
        fn increase_balance(ref self: ContractState, amount: felt252) {
            assert(amount != 0, 'Amount cannot be 0');
            self.balance.write(self.balance.read() + amount);
        }

        fn get_balance(self: @ContractState) -> felt252 {
            self.balance.read()
        }
    }
}

#[starknet::contract]
mod PriceFeedExample {
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{ContractAddress, IPriceFeedExample};
    use pragma_lib::abi::{IPragmaABIDispatcher, IPragmaABIDispatcherTrait};
    use pragma_lib::types::{DataType, PragmaPricesResponse};
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use core::starknet::contract_address::contract_address_const;
    use core::starknet::get_caller_address;

    const ETH_USD: felt252 = 19514442401534788;
    const EIGHT_DECIMAL_FACTOR: u256 = 100000000;

    #[storage]
    struct Storage {
        pragma_contract: ContractAddress,
        product_price_in_usd: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, pragma_contract: ContractAddress) {
        self.pragma_contract.write(pragma_contract);
        self.product_price_in_usd.write(100);
    }

    #[abi(embed_v0)]
    impl PriceFeedExampleImpl of IPriceFeedExample<ContractState> {
        fn buy_item(ref self: ContractState) {
            let caller_address = get_caller_address();
            let eth_price = self.get_asset_price(ETH_USD).into();
            let product_price = self.product_price_in_usd.read();

            // Calculate the amount of ETH needed
            let eth_needed = product_price * EIGHT_DECIMAL_FACTOR / eth_price;

            let eth_dispatcher = ERC20ABIDispatcher {
                contract_address: contract_address_const::<
                    0x2a85bd616f912537c50a49a4076db02c00b29b2cdc8a197ce92ed1837fa875b,
           //         0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7,
                >() // ETH Contract Address
            };

            // Transfer the ETH to the caller
            eth_dispatcher
                .transfer_from(
                    caller_address,
                    contract_address_const::<
                        0x6E9E53016aF407ddEC357Aa8f6F1C5a6Cb751fAA,
                   //     0x0237726d12d3c7581156e141c1b132f2db9acf788296a0e6e4e9d0ef27d092a2,
                    >(),
                    eth_needed,
                );
        }

        fn get_asset_price(self: @ContractState, asset_id: felt252) -> u128 {
            // Retrieve the oracle dispatcher
            let oracle_dispatcher = IPragmaABIDispatcher {
                contract_address: self.pragma_contract.read(),
            };

            // Call the Oracle contract, for a spot entry
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data_median(DataType::SpotEntry(asset_id));

            return output.price;
        }
    }
}

