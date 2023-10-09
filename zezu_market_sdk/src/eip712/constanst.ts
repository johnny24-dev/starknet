
import { Provider, constants, shortString } from "starknet";

export const CONTRACT_NAME = "ZEZU_EXCHANGE";
export const CONTRACT_VERSION = "1.0";
export const CONTRACT_ADDR = "0x0639bac6fe443cb2181e640e7e8bdea25d9bbef082b1ab9052c2f3300352dada";

export const provider = new Provider({ sequencer: { network: constants.NetworkName.SN_GOERLI, baseUrl: constants.BaseUrl.SN_GOERLI } });

export const DOMAIN = {
    name: CONTRACT_NAME,
    version: CONTRACT_VERSION,
    chainId: shortString.encodeShortString(constants.NetworkName.SN_GOERLI), // for testnet
}

export const EIP_712_ORDER_TYPES = {
    StarkNetDomain: [
        { name: "name", type: "felt" },
        { name: "version", type: "felt" },
        { name: "chainId", type: "felt" },
    ],
    //Order(trader:felt,collection:felt,num_of_listing:felt,token_id:felt,amount:felt,price:felt,asset_type:felt,salt:felt,order_type:felt,nonce:felt)
    Order: [
        { name: "trader", type: "felt" },
        { name: "collection", type: "felt" },
        { name: "num_of_listing", type: "felt" },
        { name: "token_id", type: "felt" },
        { name: "amount", type: "felt" },
        { name: "price", type: "felt" },
        { name: "asset_type", type: "felt" },
        { name: "salt", type: "felt" },
        { name: "order_type", type: "felt" },
        { name: "nonce", type: "felt" }
    ]
}

export const EIP_712_COLLECTION_OFFER_TYPES = {
    StarkNetDomain: [
        { name: "name", type: "felt" },
        { name: "version", type: "felt" },
        { name: "chainId", type: "felt" },
    ],
    //CollectionOffer(trader:felt,collection:felt,num_of_listing:felt,price_per_item:felt,asset_type:felt,salt:felt,order_type:felt,nonce:felt)
    CollectionOffer: [
        { name: "trader", type: "felt" },
        { name: "collection", type: "felt" },
        { name: "num_of_listing", type: "felt" },
        { name: "price_per_item", type: "felt" },
        { name: "asset_type", type: "felt" },
        { name: "salt", type: "felt" },
        { name: "order_type", type: "felt" },
        { name: "nonce", type: "felt" }
    ]
}

export enum PRIMARY_TYPES {
    Order = "Order",
    CollectionOffer = "CollectionOffer"
}

