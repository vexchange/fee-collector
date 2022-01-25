import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-driver";
import axios from "axios";
import { FEECOLLECTOR_ADDRESS, WVET_ADDRESS, PRIVATE_KEY, MAINNET_NODE_URL } from "./config.js";

const SELL_HOLDING_ABI =
{
    "inputs": [
        {
            "internalType": "contract IERC20",
            "name": "aToken",
            "type": "address"
        }
    ],
    "name": "SellHolding",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
};

async function SellHolding()
{
    const lTokens = new Map(Object.entries((await axios.get("https://api.vexchange.io/v1/tokens")).data));

    const lWallet = new SimpleWallet();
    lWallet.import(PRIVATE_KEY);
    const lNet = new SimpleNet(MAINNET_NODE_URL);
    const lDriver = await Driver.connect(lNet, lWallet);
    const lProvider = new Framework(lDriver);

    const lFeeCollectorContract = lProvider.thor.account(FEECOLLECTOR_ADDRESS);
    const lMethod = lFeeCollectorContract.method(SELL_HOLDING_ABI);

    for (const lToken of lTokens.keys())
    {
        if (lToken === WVET_ADDRESS) { continue; }
        try
        {
            console.log("Attempting SellHolding for", lToken);
            const lClause = lMethod.asClause(lToken);
            const lRes = await lProvider.vendor
                .sign("tx", [lClause])
                .request()
            console.log(lRes);
            console.log("Selling", lToken, "was succcessful");
        }
        catch(e)
        {
            console.error("Error", e);
        }
    }
}

SellHolding();
