use core::traits::Into;
// for interface
use starknet::ContractAddress;
use array::ArrayTrait;
use launchpad::bluemove_launchpad::bluemove_launchpad::Phase;
#[starknet::interface]
trait IBlueMoveLaunchpad<TState> {
    fn mints(ref self: TState, group_name: felt252, quantity: u64);
    fn burn(ref self: TState, token_id: u256);
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    // fn token_uri(self: @TState, token_id: u256) -> felt252;
    fn add_phase(
        ref self: TState,
        group_name: felt252,
        start_time: u64,
        expired_time: u64,
        total_nft: u64,
        nft_per_user: u64,
        price_per_item: u256,
        is_wl_pool: bool
    );
    fn add_wl_for_phase(ref self: TState, group_name: felt252, members: Array<ContractAddress>);
    fn get_phase(self: @TState, group_name: felt252) -> Phase;
    fn check_wl(self: @TState, address: ContractAddress, group_name: felt252) -> bool;
    fn get_minted_by_user(self: @TState, address: ContractAddress) -> u64;
    fn get_mint_info(self: @TState, token_id: u256) -> ContractAddress;
    fn get_admin(self: @TState) -> ContractAddress;

    // test eth contract
    // fn balance_of(self: @TState, address: ContractAddress) -> u256;
    // fn transfer_eth(ref self: TState, recipient: ContractAddress, amount: u256);
}


#[starknet::interface]
trait IERC20<TState> {
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    );
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender:ContractAddress) -> u256;
}


// contract

#[starknet::contract]
mod bluemove_launchpad {
    use starknet::ContractAddress;
    use starknet::get_contract_address;
    use starknet::contract_address_try_from_felt252;
    use starknet::get_block_timestamp;
    use starknet::get_caller_address;
    use starknet::contract_address_to_felt252;

    use openzeppelin::token::erc721::erc721;
    use openzeppelin::introspection::src5;

    use zeroable::Zeroable;
    use option::OptionTrait;
    use array::ArrayTrait;
    use traits::TryInto;
    use traits::Into;


    use super::IERC20DispatcherTrait;
    use super::IERC20Dispatcher;

    use launchpad::helper;

    #[storage]
    struct Storage {
        admin: ContractAddress,
        collection_name: felt252,
        collection_symbol: felt252,
        collection_supply: u256,
        phases: LegacyMap<felt252, Phase>,
        member: LegacyMap<(ContractAddress, felt252), bool>, // map member address to phase index
        minter: LegacyMap<ContractAddress, u64>,
        mint_info: LegacyMap<u256, ContractAddress>,
        current_id: u256,
        fund_address: ContractAddress
    }


    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Phase {
        name: felt252,
        start_time: u64,
        expired_time: u64,
        total_nft: u64,
        nft_per_user: u64,
        price_per_item: u256,
        is_wl_pool: bool
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MintEvent: MintEvent, 
    }

    #[derive(Drop, starknet::Event)]
    struct MintEvent {
        #[key]
        minter: ContractAddress,
        collection: ContractAddress,
        token_id: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, symbol: felt252, supply: u256) {
        // init oz er721
        let mut unsafe_state = erc721::ERC721::unsafe_new_contract_state();
        erc721::ERC721::InternalImpl::initializer(ref unsafe_state, name, symbol);

        let admin_address = contract_address_try_from_felt252(
            0x01EB945a1b881A2D8f8D8EA5eaDa7Ec42C999ab5e5ED225af7b62F00865BAfBd
        )
            .unwrap();

        let fund_address = contract_address_try_from_felt252(
            0x01EB945a1b881A2D8f8D8EA5eaDa7Ec42C999ab5e5ED225af7b62F00865BAfBd
        )
            .unwrap();

        // store data
        self.admin.write(admin_address);
        self.collection_name.write(name);
        self.collection_symbol.write(symbol);
        self.collection_supply.write(supply);
        self.current_id.write(1);
        self.fund_address.write(fund_address);
    }
    #[external(v0)]
    impl BluemoveLaunchpadImpl of super::IBlueMoveLaunchpad<ContractState> {
        // admin function
        fn add_phase(
            ref self: ContractState,
            group_name: felt252,
            start_time: u64,
            expired_time: u64,
            total_nft: u64,
            nft_per_user: u64,
            price_per_item: u256,
            is_wl_pool: bool
        ) {
            let caller = get_caller_address();
            let admin = self.admin.read();
            assert(admin == caller, 'InvalidAdmin');
            let phase = Phase {
                name: group_name,
                start_time: start_time,
                expired_time: expired_time,
                total_nft: total_nft,
                nft_per_user: nft_per_user,
                price_per_item: price_per_item,
                is_wl_pool: is_wl_pool
            };
            self.phases.write(group_name, phase);
        }


        fn add_wl_for_phase(
            ref self: ContractState, group_name: felt252, mut members: Array<ContractAddress>
        ) {
            let caller = get_caller_address();
            let admin = self.admin.read();
            assert(admin == caller, 'InvalidAdmin');
            helper::check_gas();
            if !members.is_empty() {
                let address = members.pop_front().unwrap();
                self.member.write((address, group_name), true);
                BluemoveLaunchpadImpl::add_wl_for_phase(ref self, group_name, members);
            }
        }

        // ---------------------------------------------------------//

        // setter

        fn mints(ref self: ContractState, group_name: felt252, mut quantity: u64) {
            helper::check_gas();
            let caller = get_caller_address();
            let fund_address = self.fund_address.read();
            let eth_address: ContractAddress = contract_address_try_from_felt252(
                0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
            )
                .unwrap();
            let balance = IERC20Dispatcher { contract_address: eth_address }.balanceOf(caller);

            let phase = self.phases.read(group_name);
            let user_minted = self.minter.read(caller);
            assert(user_minted + quantity <= phase.nft_per_user, 'Full Slot');

            let must_pay = phase.price_per_item * quantity.into();
            // check allowance
            let this_contract = get_contract_address();
            let allowance = IERC20Dispatcher {contract_address: eth_address}.allowance(caller, this_contract);
            assert(allowance >= must_pay, 'approve not enough');

            if quantity > 0 && balance > phase.price_per_item {
                let current_id = self.current_id.read();
                let supply = self.collection_supply.read();

                assert(current_id < supply, 'Sold out');

                let is_wl_pool = phase.is_wl_pool;
                let on_wl = self.member.read((caller, group_name));

                let current_time: u64 = get_block_timestamp() * 1000;
                assert(
                    current_time >= phase.start_time && current_time <= phase.expired_time,
                    'Not time to mint'
                );

                if is_wl_pool {
                    assert(on_wl, 'Not on WL');
                }

                // mint
                let mut unsafe_state = erc721::ERC721::unsafe_new_contract_state();
                // let mut token_uri: felt252 = 'dino-dreamz/metadata/';
                erc721::ERC721::InternalImpl::_mint(ref unsafe_state, caller, current_id);
                // erc721::ERC721::InternalImpl::_set_token_uri(ref unsafe_state, token_id, token_uri);

                //update mint_info
                self.mint_info.write(current_id, caller);

                // transfer eth
                IERC20Dispatcher {
                    contract_address: eth_address
                }.transferFrom(caller, fund_address, phase.price_per_item);

                // emit event
                self
                    .emit(
                        Event::MintEvent(
                            MintEvent {
                                minter: caller,
                                collection: get_contract_address(),
                                token_id: current_id
                            }
                        )
                    );

                // update state
                quantity = quantity - 1;
                self.current_id.write(current_id + 1);
                self.minter.write(caller, user_minted + 1);

                //Recursions to loop
                BluemoveLaunchpadImpl::mints(ref self, group_name, quantity);
            }
        }
        fn burn(ref self: ContractState, token_id: u256) {
            let mut unsafe_state = erc721::ERC721::unsafe_new_contract_state();
            erc721::ERC721::InternalImpl::_burn(ref unsafe_state, token_id);
        }


        // getter
        fn name(self: @ContractState) -> felt252 {
            let unsafe_state = erc721::ERC721::unsafe_new_contract_state();
            erc721::ERC721::ERC721MetadataImpl::name(@unsafe_state)
        }
        fn symbol(self: @ContractState) -> felt252 {
            let unsafe_state = erc721::ERC721::unsafe_new_contract_state();
            erc721::ERC721::ERC721MetadataImpl::symbol(@unsafe_state)
        }
        // fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
        //     let unsafe_state = erc721::ERC721::unsafe_new_contract_state();
        //     erc721::ERC721::ERC721MetadataImpl::token_uri(@unsafe_state, token_id)
        // }

        fn get_phase(self: @ContractState, group_name: felt252) -> Phase {
            self.phases.read(group_name)
        }

        fn check_wl(self: @ContractState, address: ContractAddress, group_name: felt252) -> bool {
            // let caller = get_caller_address();
            self.member.read((address, group_name))
        }

        fn get_minted_by_user(self: @ContractState, address: ContractAddress) -> u64 {
            self.minter.read(address)
        }
        fn get_mint_info(self: @ContractState, token_id: u256) -> ContractAddress {
            self.mint_info.read(token_id)
        }
        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        // test
        // fn balance_of(self: @ContractState, address: ContractAddress) -> u256 {
        //     // let caller = get_caller_address();
        //     let eth_address: ContractAddress = contract_address_try_from_felt252(
        //         0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
        //     )
        //         .unwrap();
        //     let balance = IERC20Dispatcher { contract_address: eth_address }.balanceOf(address);
        //     return balance;
        // }
        // fn transfer_eth(ref self: ContractState, recipient: ContractAddress, amount: u256){
        //     let caller = get_caller_address();
        //     let eth_address: ContractAddress = contract_address_try_from_felt252(
        //         0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
        //     )
        //         .unwrap();
        //     IERC20Dispatcher {
        //         contract_address: eth_address
        //     }.transferFrom(caller, recipient, amount);
        // }
    }
}
