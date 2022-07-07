import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-driver";
import { DISTRIBUTOR_ADDRESS, PRIVATE_KEY } from "./config.js";
import { abi } from "thor-devkit";
import config from "./deploymentConfig.js";
import readlineSync from "readline-sync";
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

/* ALLOCATIONS */
const allocations = [
  {
    recipient: config.addresses.feeCollectorVexAddress,
    weight: 5000,
  },
  {
    recipient: config.addresses.timelockAddress,
    weight: 5000,
  },
];
/* */

const DISTRIBUTOR_CONSTRUCTOR_ABI = {
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

const DISTRIBUTOR_SETALLOCATIONS_ABI = {
  inputs: [
    {
      components: [
        {
          internalType: "address",
          name: "recipient",
          type: "address",
        },
        {
          internalType: "uint16",
          name: "weight",
          type: "uint16",
        },
      ],
      internalType: "struct Allocation[]",
      name: "aAllocations",
      type: "tuple[]",
    },
  ],
  name: "setAllocations",
  outputs: [],
  stateMutability: "nonpayable",
  type: "function",
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
    const coder = new abi.Function(DISTRIBUTOR_CONSTRUCTOR_ABI);
    const data =
      DistributorContract.bytecode.object +
      coder
        .encode(config.addresses.wvetAddress)
        .slice(10 /* remove 0x prefix and 4bytes sig */);

    const resContractDeployment = await connex.vendor
      .sign("tx", [{ to: null, value: 0, data }])
      .request();

    const contractDeploymentTransaction = connex.thor.transaction(
      resContractDeployment.txid
    );

    while (!receipt) {
      await connex.thor.ticker().next();
      receipt = await contractDeploymentTransaction.getReceipt();
    }

    console.log(receipt);

    if (receipt.reverted) {
      console.log("Failed to deploy contract");
      process.exit(1);
    }

    const lFeeCollectorContract = connex.thor.account(
      receipt.outputs[0].contractAddress
    );
    const lMethod = lFeeCollectorContract.method(
      DISTRIBUTOR_SETALLOCATIONS_ABI
    );
    const lClause = lMethod.asClause(allocations);
    console.log(lClause);
    const resSetAllocations = await connex.vendor
      .sign("tx", [lClause])
      .request();

    const setAllocationsTransaction = connex.thor.transaction(
      resSetAllocations.txid
    );

    receipt = null;
    while (!receipt) {
      await connex.thor.ticker().next();
      receipt = await setAllocationsTransaction.getReceipt();
    }

    if (receipt.reverted) {
      console.log("Failed to call setAllocations method");
      process.exit(1);
    }

    console.log(receipt);
    // await renounceMastership(transactionReceipt.contractAddress);
  } catch (error) {
    console.log("Deployment failed with:", error.message);
  }

  process.exit(1);
})();
