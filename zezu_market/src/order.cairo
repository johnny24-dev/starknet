use box::BoxTrait;
use starknet::{
    contract_address_try_from_felt252, get_tx_info, get_caller_address, testing::set_caller_address
};
use pedersen::PedersenTrait;
use hash::{HashStateTrait, HashStateExTrait};
use array::{Array};

const STARKNET_DOMAIN_TYPE_HASH: felt252 =
    selector!("StarkNetDomain(name:felt,version:felt,chainId:felt)");

const ORDER_TYPE_HASH: felt252 =
    selector!(
        "Order(trader:felt,collection:felt,num_of_listing:felt,token_id:felt,amount:felt,price:felt,asset_type:felt,salt:felt,order_type:felt,nonce:felt)"
    );

#[derive(Drop, Copy, Hash, Serde)]
struct Order {
    trader: felt252,
    collection: felt252,
    num_of_listing:felt252,
    token_id: felt252,
    amount: felt252,
    price: felt252,
    asset_type: felt252, // 0 is erc721, 1 is erc1155
    salt: felt252
// order_type:felt252, // 0 is ask, 1 is bid
// nonce:felt252 //user nonce
}

#[derive(Drop, Serde)]
struct TakeOrderInput {
    trader: felt252,
    collection: felt252,
    num_of_listing:felt252,
    token_id: felt252,
    amount: felt252,
    price: felt252,
    asset_type: felt252, // 0 is erc721, 1 is erc1155
    salt: felt252,
    order_type: felt252, // 0 is ask, 1 is bid
    signature: Array<felt252>
}

#[derive(Drop, Serde)]
struct CancelOrder {
    order_hash: felt252,
    amount: felt252
}

#[derive(Drop, Copy, Hash)]
struct StarknetDomain {
    name: felt252,
    version: felt252,
    chain_id: felt252,
}

trait IStructHashOrder<T> {
    fn hash_struct(self: @T, order_type: felt252, nonce: felt252) -> felt252;
}

trait IStructHash<T> {
    fn hash_struct(self: @T) -> felt252;
}

trait IOffchainMessageHash<T> {
    fn get_message_hash(self: @T, order_type: felt252, nonce: felt252) -> felt252;
}

impl OffchainMessageHashOrderStruct of IOffchainMessageHash<Order> {
    fn get_message_hash(self: @Order, order_type: felt252, nonce: felt252) -> felt252 {
        let domain = StarknetDomain {
            name: 'ZEZU_EXCHANGE', version: '1.0', chain_id: get_tx_info().unbox().chain_id
        };
        let mut state = PedersenTrait::new(0);
        state = state.update_with('StarkNet Message');
        state = state.update_with(domain.hash_struct());

        let trader_addr = contract_address_try_from_felt252(*self.trader).unwrap();
        state = state.update_with(trader_addr);
        state = state.update_with(self.hash_struct(order_type, nonce));
        // Hashing with the amount of elements being hashed 
        state = state.update_with(4);
        state.finalize()
    }
}

impl StructHashStarknetDomain of IStructHash<StarknetDomain> {
    fn hash_struct(self: @StarknetDomain) -> felt252 {
        let mut state = PedersenTrait::new(0);
        state = state.update_with(STARKNET_DOMAIN_TYPE_HASH);
        state = state.update_with(*self);
        state = state.update_with(4);
        state.finalize()
    }
}

impl StructHashOrderStruct of IStructHashOrder<Order> {
    fn hash_struct(self: @Order, order_type: felt252, nonce: felt252) -> felt252 {
        let mut state = PedersenTrait::new(0);
        state = state.update_with(ORDER_TYPE_HASH);
        state = state.update_with(*self);
        state = state.update_with(order_type);
        state = state.update_with(nonce);
        state = state.update_with(11);
        state.finalize()
    }
}

