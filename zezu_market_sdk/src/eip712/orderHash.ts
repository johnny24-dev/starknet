import { Account, BigNumberish, CallData, WeierstrassSignatureType, cairo, typedData } from "starknet";
import { CollectionOffer, CreateCollectionOfferInput, CreateCollectionOfferInputResponse, CreateOrderInput, CreateOrderInputResponse, Order, OrderType } from "./types";
import { CONTRACT_ADDR, DOMAIN, EIP_712_COLLECTION_OFFER_TYPES, EIP_712_ORDER_TYPES, PRIMARY_TYPES, provider } from "./constanst";
import { generateRandomSalt } from "../utils";

export const getOrderHash = (order: Order, order_type: number, user_nonce: number) => {
    const data = {
        ...order,
        order_type,
        nonce: user_nonce
    }
    const order_hash = typedData.getStructHash(EIP_712_ORDER_TYPES, PRIMARY_TYPES.Order, data)
    return order_hash
}

export const getCollectionOfferHash = (collectionOffer: CollectionOffer, user_nonce: number) => {

    const data = {
        ...collectionOffer,
        order_type: 2,
        nonce: user_nonce
    }
    const collection_offer_hash = typedData.getStructHash(EIP_712_COLLECTION_OFFER_TYPES, PRIMARY_TYPES.CollectionOffer, data)
    return collection_offer_hash
}

export const getOrderMessageHash = (order: Order, order_type: number, user_nonce: number, user_address: BigNumberish) => {
    const data = {
        ...order,
        order_type,
        nonce: user_nonce
    }
    const message_hash = typedData.getMessageHash({ types: EIP_712_ORDER_TYPES, primaryType: PRIMARY_TYPES.Order, domain: DOMAIN, message: data }, user_address)
    return message_hash
}

export const getCollectionOfferMessageHash = (collectionOffer: CollectionOffer, user_nonce: number, user_address: BigNumberish) => {
    const data = {
        ...collectionOffer,
        order_type: 2,
        nonce: user_nonce
    }

    const message_hash = typedData.getMessageHash({ types: EIP_712_COLLECTION_OFFER_TYPES, primaryType: PRIMARY_TYPES.CollectionOffer, domain: DOMAIN, message: data }, user_address)
    return message_hash
}

export const createOrderAndSignMessage = async (account: Account, inputs: CreateOrderInput[]): Promise<CreateOrderInputResponse[]> => {

    let res: CreateOrderInputResponse[] = [];

    const res_user_nonce = await provider.callContract({
        contractAddress:CONTRACT_ADDR,
        entrypoint:'get_user_nonce',
        calldata: CallData.compile({
            user_address:cairo.felt(account.address)
        })
    }) // check approve token
    console.log("🚀 ~ file: index.ts:246 ~ consttest_call_data= ~ res:", res_user_nonce.result)

    const user_nonce = +BigInt(res_user_nonce.result[0]).toString()

    for (let i = 0; i < inputs.length; i++) {
        const input = inputs[i];
        const order: Order = {
            trader: input.trader ?? account.address,
            collection: input.collection,
            num_of_listing: 1,
            token_id: input.token_id,
            amount: input.amount,
            price: input.price,
            asset_type: input.asset_type,
            salt: input.salt ?? BigInt(generateRandomSalt()).toString()
        }
        const order_hash = getOrderHash(order, input.order_type, user_nonce);
        const data = {
            ...order,
            order_type:input.order_type,
            nonce: user_nonce
        }
        const signature = await account.signMessage({ types: EIP_712_ORDER_TYPES, primaryType: PRIMARY_TYPES.Order, domain: DOMAIN, message: data }) as WeierstrassSignatureType;

        const order_response: CreateOrderInputResponse = {
            ...order,
            order_type:input.order_type,
            order_hash,
            signature: [signature.r.toString(), signature.s.toString()]
        }

        res.push(order_response)
        console.log('<<res.length', res.length)
    }

    return res
}

export const createCollectionOfferAndSignMessage = async (account:Account, input:CreateCollectionOfferInput):Promise<CreateCollectionOfferInputResponse> => {

    const res_user_nonce = await provider.callContract({
        contractAddress:CONTRACT_ADDR,
        entrypoint:'get_user_nonce',
        calldata: CallData.compile({
            user_address:cairo.felt(account.address)
        })
    }) // check approve token
    console.log("🚀 ~ file: index.ts:246 ~ consttest_call_data= ~ res:", res_user_nonce.result)

    const user_nonce = +BigInt(res_user_nonce.result[0]).toString()

    const collection_offer:CollectionOffer = {
        trader: input.trader ?? account.address,
        collection: input.collection,
        num_of_listing: input.num_of_listing,
        price_per_item: input.price_per_item,
        asset_type: input.asset_type,
        salt: input.salt ?? BigInt(generateRandomSalt()).toString()
    }
    const collection_offer_hash = getCollectionOfferHash(collection_offer,user_nonce);
    const data = {
        ...collection_offer,
        order_type:2,
        nonce:user_nonce
    }

    const signature = await account.signMessage({ types: EIP_712_COLLECTION_OFFER_TYPES, primaryType: PRIMARY_TYPES.CollectionOffer, domain: DOMAIN, message: data }) as WeierstrassSignatureType;

    const collectionOfferResponse:CreateCollectionOfferInputResponse = {
        collection_offer_hash: collection_offer_hash,
        signature: [signature.r.toString(), signature.s.toString()],
        trader: collection_offer.trader,
        collection: collection_offer.collection,
        num_of_listing: collection_offer.num_of_listing,
        price_per_item: collection_offer.price_per_item,
        asset_type: collection_offer.asset_type,
        salt: collection_offer.salt
    }

    return collectionOfferResponse

}
