import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-driver";
import axios from "axios";
import { FEECOLLECTOR_ADDRESS, PRIVATE_KEY, MAINNET_NODE_URL } from "./config.js";
import * as readlineSync from "readline-sync";

const WITHDRAW_TOKENS_ABI = 
{
    "inputs": [
      {
        "internalType": "contract IERC20",
        "name": "aToken",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "aRecipient",
        "type": "address"
      }
    ],
    "name": "WithdrawToken",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
}

async function WithdrawTokens()
{
    const lTokens = new Map(Object.entries((await axios.get("https://api.vexchange.io/v1/tokens")).data));

    const lWallet = new SimpleWallet();
    lWallet.import(PRIVATE_KEY);
    const lNet = new SimpleNet(MAINNET_NODE_URL);
    const lDriver = await Driver.connect(lNet, lWallet);
    const lProvider = new Framework(lDriver);

    const lFeeCollectorContract = lProvider.thor.account(FEECOLLECTOR_ADDRESS);
    const lMethod = lFeeCollectorContract.method(WITHDRAW_TOKENS_ABI);

    for (const lToken of lTokens.keys())
    {
        console.log("Attempting WithdrawTokens for", lToken);
        
        let input = readlineSync.question("Confirm you want to continue (y/n) ");
        if (input != 'y') { continue; }
        
        try
        {
            const lClause = lMethod.asClause(lToken, "0x133720c677ac960Fd6692457233D2CeEA3754529");
            const lRes = await lProvider.vendor
                        .sign("tx", [lClause])
                        .request();

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
                console.log("Transfer", lToken, "was succcessful");    
            }
        }
        catch(e)
        {
            console.error("Error", e);
        }
    }

    console.log("Loop Finished");
}

WithdrawTokens();
