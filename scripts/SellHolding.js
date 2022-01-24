import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-driver";
import axios from "axios";
import { FEECOLLECTOR_ADDRESS, WVET_ADDRESS, privateKey } from "./config.js";

const SellHoldingABI = {
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

const SellHolding = async () =>
{
	const tokens = new Map(Object.entries((await axios.get("https://api.vexchange.io/v1/tokens")).data));

	const wallet = new SimpleWallet();
	wallet.import(privateKey);
	const net = new SimpleNet("https://mainnet-node.vexchange.io");
	const driver = await Driver.connect(net, wallet);
	const provider = new Framework(driver);

	const feeCollectorContract = provider.thor.account(FEECOLLECTOR_ADDRESS);
	const method = feeCollectorContract.method(SellHoldingABI);

	for (const token of tokens.keys())
	{
		if (token === WVET_ADDRESS) { continue; }
		try
		{
			console.log("Attempting SellHolding for", token);
			const clause = method.asClause(token);
			const res = await provider.vendor
							.sign("tx", [clause])
							.request()
			console.log(res);
			console.log("Selling", token, "was succcessful");
		}
		catch(e)
		{
			console.error("Error", e);
		}
	}
}

SellHolding();
