import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-driver";
import { PRIVATE_KEY, DISTRIBUTOR_ADDRESS } from "./config.js";
import { abi } from "thor-devkit";
import config from "./deploymentConfig.js";
import fs from "fs";
import path from "path";
const __dirname = path.resolve();

const DistributorContract = JSON.parse(
  fs.readFileSync(path.join(__dirname, config.pathToDistributorJson), "utf-8")
);

let network = null;
if (process.argv.l0ength < 3) {
  console.error("Usage: node scripts/deployDistributor [mainnet|testnet]");
  process.exit(1);
}

network = config.network[process.argv[2]];
if (network === undefined) {
  console.error("Invalid network specified");
  process.exit(1);
}

// const web3 = thorify(new Web3(), network.rpcUrl);
// web3.eth.accounts.wallet.add(config.privateKey);

const DISTRIBUTOR_CONSTRUCTOR = {
  inputs: [
    {
      internalType: "contract IERC20",
      name: "aIncomingToken",
      type: "address",
    },
  ],
  stateMutability: "nonpayable",
  type: "constructor",
};

(async () => {
  try {
    console.log("Attempting to deploy contract:", config.pathToDistributorJson);

    if (network.name == "mainnet") {
      let input = readlineSync.question(
        "Confirm you want to deploy this on the MAINNET? (y/n) "
      );
      if (input != "y") process.exit(1);
    }

    let receipt = null;
    const lWallet = new SimpleWallet();
    lWallet.import(PRIVATE_KEY);
    const lNet = new SimpleNet(network.rpcUrl);
    const lDriver = await Driver.connect(lNet, lWallet);
    const connex = new Framework(lDriver);
    const coder = new abi.Function(DISTRIBUTOR_CONSTRUCTOR);
    const data =
      DistributorContract.bytecode.object +
      coder
        .encode(config.addresses.wvetAddress)
        .slice(10 /* remove 0x prefix and 4bytes sig */);

    const { txid } = await connex.vendor
      .sign("tx", [{ to: null, value: 0, data }])
      .request();

    console.info(`Transaction: ${txid}`);

    const transaction = connex.thor.transaction(txid);

    while (!receipt) {
      await connex.thor.ticker().next();
      receipt = await transaction.getReceipt();
    }

    console.log(receipt);

    if (receipt.reverted) {
      console.log("Transaction was reverted");
    } else {
      console.log("Transaction was successful");
    }

    // await renounceMastership(transactionReceipt.contractAddress);
  } catch (error) {
    console.log("Deployment failed with:", error.message);
  }

  process.exit(1);
})();
