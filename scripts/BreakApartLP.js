import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-driver";
import axios from "axios";
import { PRIVATE_KEY, FEECOLLECTOR_ADDRESS, MAINNET_NODE_URL } from "./config.js";

const BREAK_APART_LP_ABI =
{
    "inputs": [
        {
            "internalType": "contract IVexchangeV2Pair",
            "name": "aPair",
            "type": "address"
        }
    ],
    "name": "BreakApartLP",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
};

async function BreakApartLP()
{
    const pairs = new Map(Object.entries((await axios.get("https://api.vexchange.io/v1/pairs")).data));

    const wallet = new SimpleWallet();
    wallet.import(PRIVATE_KEY);
    const net = new SimpleNet(MAINNET_NODE_URL);
    const driver = await Driver.connect(net, wallet);
    const provider = new Framework(driver);

    const feeCollectorContract = provider.thor.account(FEECOLLECTOR_ADDRESS);
    const method = feeCollectorContract.method(BREAK_APART_LP_ABI);

    for (const pair of pairs.keys())
    {
        try
        {
            console.log("Attempting BreakApart for", pair);
            const clause = method.asClause(pair);
            const res = await provider.vendor
                .sign("tx", [clause])
                .request()
            console.log(res);
            console.log("BreakApart for", pair, "was succcessful");
        }
        catch(e)
        {
            console.error("Error", e);
        }
    }
}

BreakApartLP();
