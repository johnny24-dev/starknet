import { BigNumberish } from "starknet";

export interface Order {
    trader: BigNumberish,
    collection: BigNumberish,
    num_of_listing:number,
    token_id: number,
    amount: number,
    price: BigNumberish,
    asset_type: number, // 0 is erc721, 1 is erc1155
    salt: BigNumberish
}

export interface TakeOrderInput extends Order {
    order_type: number, // 0 is ask, 1 is bid
    signature: string[]
}

export interface CollectionOffer {
    trader: BigNumberish,
    collection: BigNumberish,
    num_of_listing: number,
    price_per_item: BigNumberish,
    asset_type: number, // 0 is erc721, 1 is erc1155
    salt: BigNumberish
}

export interface TakeCollectionOffer extends CollectionOffer{
    token_id: number,
    amount: number,
    signature: string[]
}

export interface CreateOrderInput {
    trader?: BigNumberish,
    collection: BigNumberish,
    token_id: number,
    amount: number,
    price: BigNumberish,
    asset_type: number, // 0 is erc721, 1 is erc1155
    salt?: BigNumberish,
    order_type:number
}

export interface CreateCollectionOfferInput {
    trader: BigNumberish,
    collection: BigNumberish,
    num_of_listing: number,
    price_per_item: BigNumberish,
    asset_type: number, // 0 is erc721, 1 is erc1155
    salt?: BigNumberish
}

export interface CreateCollectionOfferInputResponse extends CreateCollectionOfferInput{
    collection_offer_hash:string,
    signature:string[]
}

export interface CreateOrderInputResponse extends CreateOrderInput{
    num_of_listing:number,
    order_hash:string,
    signature:string[]
}

export enum AssetType{
    ERC721 = 0,
    ERC1155 = 1
}

export enum OrderType{
    ASK = 0,
    BID = 1,
    COLLECTION_OFFER = 2
}