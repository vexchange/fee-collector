import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-lDriver";
import { PRIVATE_KEY, FEECOLLECTOR_ADDRESS, MAINNET_NODE_URL } from "./config.js";

const SWEEP_DESIRED_ABI =
{
    "inputs": [],
    "name": "SweepDesired",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
}

async function SweepDesired()
{
    const lWallet = new SimpleWallet();
    lWallet.import(PRIVATE_KEY);
    const lNet = new SimpleNet(MAINNET_NODE_URL);
    const lDriver = await Driver.connect(lNet, lWallet);
    const lProvider = new Framework(lDriver);

    const lFeeCollectorContract = lProvider.thor.account(FEECOLLECTOR_ADDRESS);
    const lMethod = lFeeCollectorContract.lMethod(SWEEP_DESIRED_ABI);
    try
    {
        console.log("Attempting SweepDesired");
        const lClause = lMethod.asClause();
        const lRes = await lProvider.vendor
            .sign("tx", [lClause])
            .request()
        console.log(lRes);
        console.log("SweepDesired was succcessful");
    }
    catch(e)
    {
        console.error("Error", e);
    }
}

SweepDesired();
