import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-driver";
import { PRIVATE_KEY } from "./config.js";
import { abi } from "thor-devkit";
import config from "./deploymentConfig.js";
import readlineSync from "readline-sync";
import fs from "fs";
import path from "path";
const __dirname = path.resolve();

const FeeCollectorContract = JSON.parse(
  fs.readFileSync(path.join(__dirname, config.pathToFeeCollectorJson), "utf-8")
);

const FEECOLLECTOR_CONSTRUCTOR_ABI = {
  inputs: [
    {
      internalType: "contract IVexchangeV2Factory",
      name: "aVexchangeFactory",
      type: "address",
    },
    {
      internalType: "contract IERC20",
      name: "aDesiredToken",
      type: "address",
    },
    {
      internalType: "address",
      name: "aRecipient",
      type: "address",
    },
  ],
  stateMutability: "nonpayable",
  type: "constructor",
};

let network = null;
let desirableTokenAddress = null;
let recipientAddress = null;
if (process.argv.length < 5) {
  console.error(
    `
      Usage: node scripts/deployFeeCollector [mainnet|testnet] [desirable token name] [recipient name]
      Example: node scripts/deployFeeCollector testnet wvet timelock
    `
  );
  process.exit(1);
}

network = config.network[process.argv[2]];
desirableTokenAddress = config.addresses[`${process.argv[3]}Address`];
recipientAddress = config.addresses[`${process.argv[4]}Address`];

if (network === undefined) {
  console.error("Invalid network specified");
  process.exit(1);
}

if (!desirableTokenAddress) {
  console.error("Invalid desirable token name");
  process.exit(1);
}

if (!recipientAddress) {
  console.error("Invalid recipient address name");
  process.exit(1);
}

(async () => {
  try {
    if (network.name == "mainnet") {
      let input = readlineSync.question(
        "Confirm you want to deploy this on the MAINNET? (y/n) "
      );
      if (input != "y") process.exit(1);
    }

    const lWallet = new SimpleWallet();
    lWallet.import(PRIVATE_KEY);
    const lNet = new SimpleNet(network.rpcUrl);
    const lDriver = await Driver.connect(lNet, lWallet);
    const connex = new Framework(lDriver);

    console.log(
      `Deploying fee collector contract(${config.pathToFeeCollectorJson})...`
    );
    const coder = new abi.Function(FEECOLLECTOR_CONSTRUCTOR_ABI);
    const data =
      FeeCollectorContract.bytecode.object +
      coder
        .encode(
          config.addresses.V2Factory,
          desirableTokenAddress,
          recipientAddress
        )
        .slice(10 /* remove 0x prefix and 4bytes sig */);

    const resContractDeployment = await connex.vendor
      .sign("tx", [{ to: null, value: 0, data }])
      .request();

    const contractDeploymentTransaction = connex.thor.transaction(
      resContractDeployment.txid
    );

    let receipt = null;
    while (!receipt) {
      await connex.thor.ticker().next();
      receipt = await contractDeploymentTransaction.getReceipt();
    }

    if (receipt.reverted) {
      console.log("Failed to deploy distributor contract");
      process.exit(1);
    }

    console.log(receipt, {
      arguments: [
        config.addresses.V2Factory,
        desirableTokenAddress,
        recipientAddress,
      ],
    });
    // await renounceMastership(transactionReceipt.contractAddress);
  } catch (error) {
    console.log("Deployment failed with:", error.message);
  }

  process.exit(1);
})();
