import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-driver";
import { PRIVATE_KEY, FEE_COLLECTOR_ADDRESS, MAINNET_NODE_URL } from "./config.js";
import { isAddress } from "ethers/lib/utils.js";

const SWEEP_DESIRED_ABI =
{
    "inputs": [],
    "name": "SweepDesired",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
}

const SWEEP_DESIRED_MANUAL_ABI =
{
    "inputs": [
        {
            "internalType": "address",
            "name": "aToken",
            "type": "address"
        }
    ],
    "name": "SweepDesired",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
}

async function SweepDesired(aTokenAddress=undefined)
{
    const lWallet = new SimpleWallet();
    lWallet.import(PRIVATE_KEY);
    const lNet = new SimpleNet(MAINNET_NODE_URL);
    const lDriver = await Driver.connect(lNet, lWallet);
    const lProvider = new Framework(lDriver);

    const lFeeCollectorContract = lProvider.thor.account(FEE_COLLECTOR_ADDRESS);

    const lMethod = aTokenAddress ? lFeeCollectorContract.method(SWEEP_DESIRED_MANUAL_ABI)
                                 : lFeeCollectorContract.method(SWEEP_DESIRED_ABI);

    try
    {
        console.log("Attempting SweepDesired");
        const lClause = aTokenAddress ? lMethod.asClause(aTokenAddress)
                                     : lMethod.asClause();

        const lRes = await lProvider.vendor
            .sign("tx", [lClause])
            .request()

        let lTxReceipt;
        const lTxVisitor = lProvider.thor.transaction(lRes.txid);
        const lTicker = lProvider.thor.ticker();

        while(!lTxReceipt) {
            await lTicker.next();
            lTxReceipt = await lTxVisitor.getReceipt();
        }

        if (lTxReceipt.reverted)
        {
            console.log("tx was unsuccessful");
        }
        else
        {
            console.log("SweepDesired was succcessful");
        }
    }
    catch(e)
    {
        console.error("Error", e);
    }
}

const TOKEN_ADDRESS = process.argv[2];
if (TOKEN_ADDRESS && !isAddress(TOKEN_ADDRESS))
{
    throw Error("Invalid Token Address Provided");
}

SweepDesired(TOKEN_ADDRESS);
