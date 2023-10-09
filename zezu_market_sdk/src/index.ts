import { Account, Contract, Provider, Signer, TypedData, WeierstrassSignatureType, constants, shortString, typedData } from "starknet";
import { generateRandomSalt } from "./utils";
import { ethers, toUtf8Bytes } from "ethers";




const typedDataValidate: TypedData = {
    types: {
        StarkNetDomain: [
            { name: "name", type: "felt" },
            { name: "version", type: "felt" },
            { name: "chainId", type: "felt" },
        ],
        Order: [
            { name: "trader", type: "felt" },
            { name: "collection", type: "felt" },
            { name: "token_id", type: "felt" },
            { name: "amount", type: "felt" },
            { name: "price", type: "felt" },
            { name: "asset_type", type: "felt" },
            { name: "salt", type: "felt" },
            { name: "order_type", type: "felt" },
            { name: "nonce", type: "felt" },
        ]
    },
    primaryType: "Order",
    domain: {
        name: "dappName", // put the name of your dapp to ensure that the signatures will not be used by other DAPP
        version: "1",
        chainId: shortString.encodeShortString("SN_GOERLI"), // shortString of 'SN_GOERLI' (or 'SN_MAIN' or 'SN_GOERLI2'), to be sure that signature can't be used by other network.
    },
    message: {
        trader: "0x01EB945a1b881A2D8f8D8EA5eaDa7Ec42C999ab5e5ED225af7b62F00865BAfBd",
        collection: "0x0187623be1669117F3bd4DE38E86B01E2493a28ccBa1f669Ff0D7a9d9D6Ca571",
        token_id: 1,
        amount: 1,
        price: '1000000000000000',
        asset_type: 0, // 0 is erc721, 1 is erc1155
        salt: '3980537072612236587',
        order_type: 0, // 0 is ask, 1 is bid
        nonce: 0 //user nonce
    },
};


const run = async () => {

    const privateKey = "0x056ed11a8c2a00c612c6e1ded9ac334e23dccf8b40cbc853ffc2e64fa9a4aec6";
    const accountAddress = "0x01EB945a1b881A2D8f8D8EA5eaDa7Ec42C999ab5e5ED225af7b62F00865BAfBd";

    const contract_address = "0x039cb8e00bf0a7744a1b13d27749143aa1b35e0d79e42dffb32bdcd955aaa943";

    const provider = new Provider({ sequencer: { network: constants.NetworkName.SN_GOERLI, baseUrl: constants.BaseUrl.SN_GOERLI } });

    const account = new Account(
        provider,
        accountAddress,
        privateKey,
        '1'
    )

    // const classHash = "0x057759ba312093a795c4ae8231afe0819b24390abb77b559bd4ac467a57d1365";

    // const deployResponse = await account.deployContract({ classHash: classHash });
    // await provider.waitForTransaction(deployResponse.transaction_hash);


    // console.log('contract_address', deployResponse.contract_address)

    console.log("🚀 ~ file: index.ts:66 ~ run ~ typedDataValidate:", typedDataValidate)

    const message_hash = typedData.getMessageHash(typedDataValidate,accountAddress);
    console.log("🚀 ~ file: index.ts:72 ~ run ~ message_hash:", message_hash)

    const _order_hash = typedData.getStructHash(typedDataValidate.types,typedDataValidate.primaryType,typedDataValidate.message)
    console.log("🚀 ~ file: index.ts:77 ~ run ~ _order_hash:", _order_hash)

    const _doamain_hash = typedData.getStructHash(typedDataValidate.types,'StarkNetDomain',typedDataValidate.domain)
    console.log("🚀 ~ file: index.ts:80 ~ run ~ _doamain_hash:", _doamain_hash)

    const signature2 = await account.signMessage(typedDataValidate) as WeierstrassSignatureType;

    // const s_r = toUtf8Bytes(signature2.r.toString())
    // const s_s = toUtf8Bytes(signature2.s.toString())

    console.log("🚀 ~ file: index.ts:75 ~ run ~ signature2:", signature2.r.toString(), signature2.s.toString())


    // const msgHash5 = typedData.getMessageHash(typedDataValidate, accountAddress);
    // // The call of isValidSignature will generate an error if not valid
    // let result5: boolean;
    // try {
    //     await contractAccount.isValidSignature(msgHash5, [signature2.r, signature2.s]);
    //     result5 = true;
    // } catch {
    //     result5 = false;
    // }
    // console.log("Result5 (boolean) =", result5);

}

run()