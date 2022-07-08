import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-driver";
import {
  FEE_COLLECTOR_VEX_ADDRESS,
  MAINNET_NODE_URL,
  PRIVATE_KEY,
  TESTNET_NODE_URL,
  TIMELOCK_ADDRESS,
  WVET_ADDRESS,
} from "../config.js";
import inquirer from "inquirer";
import {
  configureDistributorAllocations,
  deployDistributorContract,
} from "./utils.js";

/* ALLOCATIONS */
const allocations = [
  {
    recipient: FEE_COLLECTOR_VEX_ADDRESS,
    weight: 5000,
  },
  {
    recipient: TIMELOCK_ADDRESS,
    weight: 5000,
  },
];

const deployDistributor = async () => {
  try {
    const answers = await inquirer.prompt([
      {
        type: "list",
        name: "network",
        default: "testnet",
        choices: ["mainnet", "testnet"],
      },
      {
        type: "input",
        name: "incomingToken",
        default: WVET_ADDRESS
      },
    ]);

    if (answers.network === "mainnet") {
      const confirm = await inquirer.prompt([
        {
          type: "confirm",
          name: "confirm",
          default: false,
          message: "Confirm you want to deploy this on the MAINNET?",
        },
      ]);

      if (!confirm.confirm) process.exit(1);
    }

    const network =
      answers.network === "mainnet" ? MAINNET_NODE_URL : TESTNET_NODE_URL;

    const lWallet = new SimpleWallet();
    lWallet.import(PRIVATE_KEY);
    const lNet = new SimpleNet(network);
    const lDriver = await Driver.connect(lNet, lWallet);
    const connex = new Framework(lDriver);

    const distributorContractAddress = await deployDistributorContract(connex, {
      incomingToken: answers.incomingToken,
    });
    await configureDistributorAllocations(connex, {
      distributorContractAddress,
      allocations,
    });
    // await renounceMastership(transactionReceipt.contractAddress);
  } catch (error) {
    console.log("Deployment failed with:", error);
  }

  process.exit(1);
};
deployDistributor();
