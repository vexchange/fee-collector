import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-driver";
import { privateKey, FEECOLLECTOR_ADDRESS } from "./config.js";

const SweepDesiredABI =
{
    "inputs": [],
    "name": "SweepDesired",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
}

const SweepDesired = async () =>
{
    const wallet = new SimpleWallet();
    wallet.import(privateKey);
    const net = new SimpleNet("https://mainnet-node.vexchange.io");
    const driver = await Driver.connect(net, wallet);
    const provider = new Framework(driver);

    const feeCollectorContract = provider.thor.account(FEECOLLECTOR_ADDRESS);
    const method = feeCollectorContract.method(SweepDesiredABI);
    try
    {
        console.log("Attempting SweepDesired");
        const clause = method.asClause();
        const res = await provider.vendor
            .sign("tx", [clause])
            .request()
        console.log(res);
        console.log("SweepDesired was succcessful");
    }
    catch(e)
    {
        console.error("Error", e);
    }
}

SweepDesired();
