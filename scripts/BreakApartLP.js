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
    const lPairs = new Map(Object.entries((await axios.get("https://api.vexchange.io/v1/pairs")).data));

    const lWallet = new SimpleWallet();
    lWallet.import(PRIVATE_KEY);
    const lNet = new SimpleNet(MAINNET_NODE_URL);
    const lDriver = await Driver.connect(lNet, lWallet);
    const lProvider = new Framework(lDriver);

    const lFeeCollectorContract = lProvider.thor.account(FEECOLLECTOR_ADDRESS);
    const lMethod = lFeeCollectorContract.method(BREAK_APART_LP_ABI);

    for (const lPair of lPairs.keys())
    {
        try
        {
            console.log("Attempting BreakApart for", lPair);
            const lClause = lMethod.asClause(lPair);
            
            const lRes = await lProvider.vendor
                .sign("tx", [lClause])
                .request()
            console.log(lRes);
            console.log("BreakApart for", lPair, "was succcessful");
        }
        catch(e)
        {
            console.error("Error", e);
        }
    }
}

BreakApartLP();
