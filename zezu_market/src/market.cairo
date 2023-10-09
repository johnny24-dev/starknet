use starknet::{ContractAddress, ClassHash};
use zezu_market::order::{CancelOrder, TakeOrderInput, Order};
use zezu_market::collection_offer::{TakeCollectionOffer, CollectionOffer};
use array::{Array};
#[starknet::interface]
trait Imarket<T> {
    // admin function
    fn set_protocol_fee(ref self: T, _new_fee: felt252, _fund_addr: ContractAddress);
    // fn set_delegate_address(ref self: T, _new_delegae: ContractAddress);
    fn set_pool_address(ref self: T, _new_pool: ContractAddress);
    fn increment_nonce(ref self: T);
    fn set_collection_royalty(ref self: T, recipent_address: felt252, rate: felt252);
    fn upgrage(ref self: T, _new_class_hash: ClassHash);

    //---------------------------------------//

    // external function

    fn contract_version(self:@T) -> u8;

    fn validate_oder_public(
        self: @T, order: Order, order_type: felt252, signature: Array<felt252>
    ) -> bool;

    fn validate_collection_offer_public(
        self: @T, collection_offer: CollectionOffer, amount: felt252, signature: Array<felt252>
    ) -> bool;

    fn get_order_message_hash(self: @T, order: Order, order_type: felt252) -> felt252;
    fn get_collection_offer_message_hash(self: @T, collection_offer: CollectionOffer) -> felt252;

    fn cancel_order(ref self: T, cancel_order: CancelOrder);
    fn take_ask(ref self: T, input: TakeOrderInput);
    fn take_bid(ref self: T, input: TakeOrderInput);
    fn take_collection_offer(ref self: T, input: TakeCollectionOffer);

    // view function
    fn get_protocol_fee(self: @T) -> (ContractAddress, felt252);
    fn get_pool_address(self: @T) -> ContractAddress;
    fn get_user_nonce(self: @T, user_address: ContractAddress) -> felt252;
    fn get_collection_royalty(self: @T, collection: felt252) -> (felt252, felt252);
}


#[starknet::interface]
trait IERC721<TState> {
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
}


#[starknet::interface]
trait IPool<TContractState> {
    fn withdraw_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    );
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    ) -> bool;
}

#[starknet::interface]
trait IERC20<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;

    // for eth starknet
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
}

#[starknet::interface]
trait IAccountInterface<T> {
    fn isValidSignature(self: @T, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::contract]
mod Market {
    use zezu_market::order::IStructHash;
    use zezu_market::order::IOffchainMessageHash;
    use zezu_market::collection_offer::IStructHashCollectionOfferr;
    use starknet::{
        contract_address_try_from_felt252, get_tx_info, ContractAddress, get_caller_address,
        get_contract_address, ClassHash, SyscallResultTrait
    };


    use zezu_market::order::{Order, OffchainMessageHashOrderStruct, StarknetDomain};
    use zezu_market::order::{CancelOrder, TakeOrderInput};
    use zezu_market::collection_offer::{
        TakeCollectionOffer, CollectionOffer, OffchainMessageHashCollectionOfferStruct
    };
    use zezu_market::order::IStructHashOrder;

    use super::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait,
        IAccountInterfaceDispatcher, IAccountInterfaceDispatcherTrait, IPoolDispatcher,
        IPoolDispatcherTrait
    };

    use core::clone::Clone;
    use traits::Into;
    use core::option::OptionTrait;
    use array::{Array, ArrayTrait};
    use pedersen::PedersenTrait;
    use hash::{HashStateTrait, HashStateExTrait};
    

    const _BASIS_POINTS: felt252 = 10_000;
    const _MAX_PROTOCOL_FEE_RATE: felt252 = 500;

    #[storage]
    struct Storage {
        _DELEGATE: ContractAddress,
        _POOL: ContractAddress,
        admin: ContractAddress,
        protocol_fee: felt252,
        fund_address: ContractAddress,
        nonces: LegacyMap<ContractAddress, felt252>, // user nonce
        amount_taken: LegacyMap<(ContractAddress, felt252),
        felt252>, // (userAddress, orderhash) => amount_taken
        collection_royalties: LegacyMap<felt252, Royalty>
    }


    #[constructor]
    fn constructor(
        ref self: ContractState,
        // _delegate: felt252,
        _pool: felt252,
        _admin: felt252,
        _protocol_fee: felt252,
        _fund_address: felt252
    ) {
        // let delegate_addr = contract_address_try_from_felt252(_delegate).unwrap();
        let pool_addr = contract_address_try_from_felt252(_pool).unwrap();
        let admin_addr = contract_address_try_from_felt252(_admin).unwrap();
        let fund_addr = contract_address_try_from_felt252(_fund_address).unwrap();
        // self._DELEGATE.write(delegate_addr);
        self._POOL.write(pool_addr);
        self.admin.write(admin_addr);
        self.protocol_fee.write(_protocol_fee);
        self.fund_address.write(fund_addr);
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Royalty {
        recipent: felt252,
        rate: felt252
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        // SetDelegate: SetDelegate,
        SetProtocolFee: SetProtocolFee,
        SetPool: SetPool,
        IncrementNonce: IncrementNonce,
        SetCollectionRoyalty: SetCollectionRoyalty,
        CancelTrade: CancelTrade,
        Execution: Execution,
        ExecutionCollectionOffer: ExecutionCollectionOffer,
        Upgraded:Upgraded
    }

    #[derive(Drop, starknet::Event)]
    struct SetProtocolFee {
        #[key]
        fund_address: ContractAddress,
        #[key]
        rate: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        implementation: ClassHash
    }

    // #[derive(Drop, starknet::Event)]
    // struct SetDelegate {
    //     #[key]
    //     delegate_address: ContractAddress
    // }

    #[derive(Drop, starknet::Event)]
    struct SetPool {
        #[key]
        pool_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct IncrementNonce {
        #[key]
        user_address: ContractAddress,
        #[key]
        nonce: u256
    }
    #[derive(Drop, starknet::Event)]
    struct SetCollectionRoyalty {
        #[key]
        recipent_address: felt252,
        #[key]
        rate: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct CancelTrade {
        #[key]
        user_address: ContractAddress,
        #[key]
        order_hash: felt252,
        amount: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct Execution {
        #[key]
        order_hash: felt252,
        collection: felt252,
        token_id: felt252,
        amount: felt252,
        price: felt252,
        order_type: felt252,
        sender: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct ExecutionCollectionOffer {
        #[key]
        order_hash: felt252,
        collection: felt252,
        token_id: felt252,
        amount: felt252,
        price: felt252,
        order_type: felt252,
        remaining: felt252,
        sender: ContractAddress
    }


    #[external(v0)]
    impl ImpleMarket of super::Imarket<ContractState> {
        // Admin function //
        fn set_protocol_fee(
            ref self: ContractState, _new_fee: felt252, _fund_addr: ContractAddress
        ) {
            let caller = get_caller_address();
            let admin_addr = self.admin.read();
            assert(caller == admin_addr, 'Invalid Admin');
            let _new_fee_u256: u256 = _new_fee.into();
            assert(_new_fee_u256 <= _MAX_PROTOCOL_FEE_RATE.into(), 'Invalid fee');
            self.protocol_fee.write(_new_fee);
            self.fund_address.write(_fund_addr);

            self.emit(SetProtocolFee { fund_address: _fund_addr, rate: _new_fee_u256 });
        }

        fn upgrage(ref self: ContractState, _new_class_hash: ClassHash) {
            let caller = get_caller_address();
            let admin_addr = self.admin.read();
            assert(caller == admin_addr, 'Invalid Admin');

            assert(!_new_class_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(_new_class_hash).unwrap_syscall();
            self.emit(Event::Upgraded(Upgraded { implementation: _new_class_hash }))
           
        }

        // fn set_delegate_address(ref self: ContractState, _new_delegae: ContractAddress) {
        //     let caller = get_caller_address();
        //     let admin_addr = self.admin.read();
        //     assert(caller == admin_addr, 'Invalid Admin');
        //     self._DELEGATE.write(_new_delegae);
        //     self.emit(SetDelegate { delegate_address: _new_delegae });
        // }
        fn set_pool_address(ref self: ContractState, _new_pool: ContractAddress) {
            let caller = get_caller_address();
            let admin_addr = self.admin.read();
            assert(caller == admin_addr, 'Invalid Admin');
            self._POOL.write(_new_pool);
            self.emit(SetPool { pool_address: _new_pool });
        }

        fn set_collection_royalty(
            ref self: ContractState, recipent_address: felt252, rate: felt252
        ) {
            let caller = get_caller_address();
            let admin_addr = self.admin.read();
            assert(caller == admin_addr, 'Invalid Admin');
            let royalty = Royalty { recipent: recipent_address, rate };
            self.collection_royalties.write(recipent_address, royalty);
            self.emit(SetCollectionRoyalty { recipent_address, rate })
        }
        //______________________________________________________________________//

        // external function

        fn validate_oder_public(
            self: @ContractState, order: Order, order_type: felt252, signature: Array<felt252>
        ) -> bool {
            let trader_addr = contract_address_try_from_felt252(order.trader).unwrap();
            let user_nonce = self.nonces.read(trader_addr);
            let mut validate = true;
            let hash_to_sign: felt252 = order.get_message_hash(order_type, user_nonce);

            let _validate = IAccountInterfaceDispatcher { contract_address: trader_addr }
                .isValidSignature(hash_to_sign, signature);
            if (order.asset_type == 0) {
                validate = validate && order.amount == 1;
            }
            _validate == 1 && validate
        }

        fn validate_collection_offer_public(
            self: @ContractState,
            collection_offer: CollectionOffer,
            amount: felt252,
            signature: Array<felt252>
        ) -> bool {
            let trader_addr = contract_address_try_from_felt252(collection_offer.trader).unwrap();
            let user_nonce = self.nonces.read(trader_addr);
            let mut validate = true;
            let hash_to_sign = collection_offer.get_message_hash(2, user_nonce);
            let _validate = IAccountInterfaceDispatcher { contract_address: trader_addr }
                .isValidSignature(hash_to_sign, signature);
            if (collection_offer.asset_type == 0) {
                validate = validate && amount == 1;
            }
            let collection_offer_hash = collection_offer.clone().hash_struct(2, user_nonce);
            let current_amount_taken: u256 = self
                .amount_taken
                .read((trader_addr, collection_offer_hash))
                .into();
            _validate == 1
                && validate
                && ((current_amount_taken + amount.into()) <= collection_offer
                    .num_of_listing
                    .into())
        }

        fn get_order_message_hash(
            self: @ContractState, order: Order, order_type: felt252
        ) -> felt252 {
            let trader_addr = contract_address_try_from_felt252(order.trader).unwrap();
            let user_nonce = self.nonces.read(trader_addr);
            let mut validate = true;
            order.get_message_hash(order_type, user_nonce)
        }
        fn get_collection_offer_message_hash(
            self: @ContractState, collection_offer: CollectionOffer
        ) -> felt252 {
            let trader_addr = contract_address_try_from_felt252(collection_offer.trader).unwrap();
            let user_nonce = self.nonces.read(trader_addr);
            let mut validate = true;
            collection_offer.get_message_hash(2, user_nonce)
        }

        fn increment_nonce(ref self: ContractState) {
            let caller = get_caller_address();
            let current_nonce = self.nonces.read(caller);
            self.nonces.write(caller, (current_nonce + 1));
            self.emit(IncrementNonce { user_address: caller, nonce: (current_nonce + 1).into() });
        }

        fn cancel_order(ref self: ContractState, cancel_order: CancelOrder) {
            let caller = get_caller_address();
            self.amount_taken.write((caller, cancel_order.order_hash), cancel_order.amount);
            self
                .emit(
                    CancelTrade {
                        user_address: caller,
                        order_hash: cancel_order.order_hash,
                        amount: cancel_order.amount
                    }
                );
        }

        fn take_ask(ref self: ContractState, input: TakeOrderInput) {
            let caller = get_caller_address();
            let this_contract = get_contract_address();
            let order = Order {
                trader: input.trader,
                collection: input.collection,
                num_of_listing: input.num_of_listing,
                token_id: input.token_id,
                amount: input.amount,
                price: input.price,
                asset_type: input.asset_type, // 0 is erc721, 1 is erc1155
                salt: input.salt
            };
            self.assert_balance_allowance(order.price, order.amount, caller, this_contract);

            self.validate_oder(order.clone(), 0, input.signature);

            let (protocol_fee, royalty_fee, seller_price) = self
                .computing_fee(order.price, order.amount, order.collection);

            //transer_nft
            let trader_addr = contract_address_try_from_felt252(order.trader).unwrap();
            self
                .transer_nft(
                    order.collection, order.token_id, trader_addr, input.order_type, caller
                );

            //transfer_erc20
            let fund_address = self.fund_address.read();
            let recipent_royalty = self.collection_royalties.read(order.collection).recipent;
            let recipent_royalty_addr = contract_address_try_from_felt252(recipent_royalty)
                .unwrap();
            self.transer_eth_starknet(caller, fund_address, protocol_fee);
            if (royalty_fee != 0) {
                self.transer_eth_starknet(caller, recipent_royalty_addr, royalty_fee);
            }
            self.transer_eth_starknet(caller, trader_addr, seller_price);

            // update fullfil order
            let trader_nonce = self.nonces.read(trader_addr);
            let order_hash = order.hash_struct(input.order_type, trader_nonce);
            let new_amount_taken = self.amount_taken.read((caller, order_hash)) + order.amount;

            self.amount_taken.write((caller, order_hash), new_amount_taken);

            self
                .emit(
                    Execution {
                        order_hash,
                        collection: order.collection,
                        token_id: order.token_id,
                        amount: order.amount,
                        price: order.price,
                        order_type: input.order_type,
                        sender: caller
                    }
                );
        }
        fn take_bid(ref self: ContractState, input: TakeOrderInput) {
            let caller = get_caller_address();
            let this_contract = get_contract_address();
            let order = Order {
                trader: input.trader,
                collection: input.collection,
                num_of_listing: input.num_of_listing,
                token_id: input.token_id,
                amount: input.amount,
                price: input.price,
                asset_type: input.asset_type, // 0 is erc721, 1 is erc1155
                salt: input.salt
            };
            self.validate_oder(order.clone(), 1, input.signature);
            let (protocol_fee, royalty_fee, seller_price) = self
                .computing_fee(order.price, order.amount, order.collection);

            //transer_nft
            let trader_addr = contract_address_try_from_felt252(order.trader).unwrap();
            self
                .transer_nft(
                    order.collection, order.token_id, trader_addr, input.order_type, caller
                );

            //transfer_erc20_from_pool
            let fund_address = self.fund_address.read();
            let recipent_royalty = self.collection_royalties.read(order.collection).recipent;
            let recipent_royalty_addr = contract_address_try_from_felt252(recipent_royalty)
                .unwrap();
            self
                .transfer_eth_starknet_from_pool(
                    trader_addr, fund_address, protocol_fee
                ); // caller is accepter
            if (royalty_fee != 0) {
                self
                    .transfer_eth_starknet_from_pool(
                        trader_addr, recipent_royalty_addr, royalty_fee
                    );
            }
            self.transfer_eth_starknet_from_pool(trader_addr, caller, seller_price);

            // update fullfil order
            let trader_nonce = self.nonces.read(trader_addr);
            let order_hash = order.clone().hash_struct(input.order_type, trader_nonce);
            let new_amount_taken = self.amount_taken.read((trader_addr, order_hash)) + order.amount;

            self.amount_taken.write((trader_addr, order_hash), new_amount_taken);

            self
                .emit(
                    Execution {
                        order_hash,
                        collection: order.collection,
                        token_id: order.token_id,
                        amount: order.amount,
                        price: order.price,
                        order_type: input.order_type,
                        sender: caller
                    }
                );
        }
        fn take_collection_offer(ref self: ContractState, input: TakeCollectionOffer) {
            let caller = get_caller_address();
            let this_contract = get_contract_address();
            let collection_offer = CollectionOffer {
                trader: input.trader,
                collection: input.collection,
                num_of_listing: input.num_of_listing,
                price_per_item: input.price_per_item,
                asset_type: input.asset_type, // 0 is erc721, 1 is erc1155
                salt: input.salt
            };
            let validate_collection_offer = self
                .validate_collection_offer(collection_offer.clone(), input.amount, input.signature);
            assert(validate_collection_offer, 'Invalid Authenticate!');
            let (protocol_fee, royalty_fee, seller_price) = self
                .computing_fee(collection_offer.price_per_item, 1, collection_offer.collection);

            //transer_nft
            let trader_addr = contract_address_try_from_felt252(collection_offer.trader).unwrap();
            self.transer_nft(collection_offer.collection, input.token_id, trader_addr, 2, caller);

            //transfer_erc20
            let fund_address = self.fund_address.read();
            let recipent_royalty = self
                .collection_royalties
                .read(collection_offer.collection)
                .recipent;
            let recipent_royalty_addr = contract_address_try_from_felt252(recipent_royalty)
                .unwrap();
            self
                .transfer_eth_starknet_from_pool(
                    trader_addr, fund_address, protocol_fee
                ); // trader is bidder
            if (royalty_fee != 0) {
                self
                    .transfer_eth_starknet_from_pool(
                        trader_addr, recipent_royalty_addr, royalty_fee
                    );
            }
            self.transfer_eth_starknet_from_pool(trader_addr, caller, seller_price);

            // update fullfil order
            let trader_nonce = self.nonces.read(trader_addr);
            let collection_offer_hash = collection_offer.clone().hash_struct(2, trader_nonce);
            let new_amount_taken = self.amount_taken.read((trader_addr, collection_offer_hash))
                + input.amount;

            self.amount_taken.write((trader_addr, collection_offer_hash), new_amount_taken);

            self
                .emit(
                    ExecutionCollectionOffer {
                        order_hash: collection_offer_hash,
                        collection: collection_offer.collection,
                        token_id: input.token_id,
                        amount: input.amount,
                        price: collection_offer.price_per_item,
                        order_type: 2,
                        remaining: (collection_offer.num_of_listing - input.amount),
                        sender: caller
                    }
                );
        }

        //______________________________________________//

        // view function
        fn get_protocol_fee(self: @ContractState) -> (ContractAddress, felt252) {
            (self.fund_address.read(), self.protocol_fee.read())
        }
        fn get_pool_address(self: @ContractState) -> ContractAddress {
            self._POOL.read()
        }
        fn get_user_nonce(self: @ContractState, user_address: ContractAddress) -> felt252 {
            self.nonces.read(user_address)
        }
        fn get_collection_royalty(self: @ContractState, collection: felt252) -> (felt252, felt252) {
            let royalty = self.collection_royalties.read(collection);
            (royalty.recipent, royalty.rate)
        }

        fn contract_version(self:@ContractState) -> u8 {
            1
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn computing_fee(
            self: @ContractState, price_item: felt252, amount: felt252, collection: felt252
        ) -> (u256, u256, u256) {
            let protocol_rate: u256 = self.protocol_fee.read().into();
            let royalty = self.collection_royalties.read(collection);
            let royalty_rate: u256 = royalty.rate.into();
            let must_pay: u256 = price_item.into() * amount.into();
            let protocol_fee = (must_pay * protocol_rate) / _BASIS_POINTS.into();
            let royalty_fee = (must_pay * royalty_rate) / _BASIS_POINTS.into();
            let seller_price = must_pay - protocol_fee - royalty_fee;
            (protocol_fee, royalty_fee, seller_price)
        }

        fn transer_nft(
            self: @ContractState,
            _collection: felt252,
            _token_id: felt252,
            _from: ContractAddress,
            order_type: felt252,
            _caller: ContractAddress
        ) {
            let collection = contract_address_try_from_felt252(_collection).unwrap();
            let token_id: u256 = _token_id.into();
            // let from = contract_address_try_from_felt252(_from).unwrap();
            // let caller = contract_address_try_from_felt252(_caller).unwrap();
            if (order_type == 0) {
                IERC721Dispatcher { contract_address: collection }
                    .transfer_from(_from, _caller, token_id);
            } else {
                IERC721Dispatcher { contract_address: collection }
                    .transfer_from(_caller, _from, token_id);
            }
        }

        fn transer_erc20(
            self: @ContractState,
            token_address: ContractAddress,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let eth_contract: ContractAddress = contract_address_try_from_felt252(
                0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
            )
                .unwrap();
            IERC20Dispatcher { contract_address: token_address }
                .transfer_from(sender, recipient, amount);
        }

        fn transer_eth_starknet(
            self: @ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) {
            let eth_contract: ContractAddress = contract_address_try_from_felt252(
                0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
            )
                .unwrap();
            IERC20Dispatcher { contract_address: eth_contract }
                .transferFrom(sender, recipient, amount);
        }

        fn transfer_eth_starknet_from_pool(
            self: @ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            let pool_addr = self._POOL.read();
            IPoolDispatcher { contract_address: pool_addr }.transfer_from(sender, recipient, amount)
        }

        fn assert_balance_allowance(
            self: @ContractState,
            price_item: felt252,
            amount: felt252,
            owner: ContractAddress,
            spender: ContractAddress
        ) {
            let eth_contract: ContractAddress = contract_address_try_from_felt252(
                0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
            )
                .unwrap();
            // let owner_address = contract_address_try_from_felt252(owner).unwrap();
            // let spender_address = contract_address_try_from_felt252(spender).unwrap();
            let allowance = IERC20Dispatcher { contract_address: eth_contract }
                .allowance(owner, spender);
            let must_pay: u256 = price_item.into() * amount.into();
            assert(allowance >= must_pay, 'Invalid Approve');
        }

        fn validate_oder(
            self: @ContractState, order: Order, order_type: felt252, signature: Array<felt252>
        ) {
            let trader_addr = contract_address_try_from_felt252(order.trader).unwrap();
            let user_nonce = self.nonces.read(trader_addr);
            let mut validate = true;
            let hash_to_sign: felt252 = order.get_message_hash(order_type, user_nonce);

            let _validate = IAccountInterfaceDispatcher { contract_address: trader_addr }
                .isValidSignature(hash_to_sign, signature);
            if (order.asset_type == 0) {
                validate = validate && order.amount == 1;
            }
            let order_hash = order.clone().hash_struct(order_type, user_nonce);
            let current_amount_taken: u256 = self
                .amount_taken
                .read((trader_addr, order_hash))
                .into();
            validate = _validate == 1
                && validate
                && ((current_amount_taken + order.amount.into()) <= order.num_of_listing.into());
            assert(validate, 'Invalid Authenticate');
        }

        fn validate_collection_offer(
            self: @ContractState,
            collection_offer: CollectionOffer,
            amount: felt252,
            signature: Array<felt252>
        ) -> bool {
            let trader_addr = contract_address_try_from_felt252(collection_offer.trader).unwrap();
            let user_nonce = self.nonces.read(trader_addr);
            let mut validate = true;
            let hash_to_sign = collection_offer.get_message_hash(2, user_nonce);
            let _validate = IAccountInterfaceDispatcher { contract_address: trader_addr }
                .isValidSignature(hash_to_sign, signature);
            if (collection_offer.asset_type == 0) {
                validate = validate && amount == 1;
            }
            let collection_offer_hash = collection_offer.clone().hash_struct(2, user_nonce);
            let current_amount_taken: u256 = self
                .amount_taken
                .read((trader_addr, collection_offer_hash))
                .into();
            _validate == 1
                && validate
                && ((current_amount_taken + amount.into()) <= collection_offer
                    .num_of_listing
                    .into())
        }
    }
}
