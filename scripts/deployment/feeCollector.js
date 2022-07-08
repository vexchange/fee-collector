import { Framework } from "@vechain/connex-framework";
import { Driver, SimpleNet, SimpleWallet } from "@vechain/connex-driver";
import { MAINNET_NODE_URL, PRIVATE_KEY, TESTNET_NODE_URL } from "../config.js";
import { deployFeeCollectorContract } from "./utils.js";
import inquirer from "inquirer";

const deployFeeCollector = async () => {
  try {
    const answers = await inquirer.prompt([
      {
        type: "list",
        name: "network",
        default: 'testnet',
        choices: ['mainnet', 'testnet']
      },
      {
        type: "input",
        name: "recipientAddress",
        message: "Recipient address"
      },
      {
        type: "input",
        name: "desirableTokenAddress",
        message: "Desirable token address"
      }
    ]);

    if (answers.network === 'mainnet') {
      const confirm = await inquirer.prompt([
        {
          type: "confirm",
          name: "confirm",
          default: false,
          message: "Confirm you want to deploy this on the MAINNET?",
        },
      ]);

      if (!confirm.confirm) process.exit(1)
    }

    const network = answers.network === 'mainnet' ? MAINNET_NODE_URL : TESTNET_NODE_URL
    const lWallet = new SimpleWallet();
    lWallet.import(PRIVATE_KEY);
    const lNet = new SimpleNet(network);
    const lDriver = await Driver.connect(lNet, lWallet);
    const connex = new Framework(lDriver);

    await deployFeeCollectorContract(connex, answers);
    // await renounceMastership(transactionReceipt.contractAddress);
  } catch (error) {
    console.log(error);
  }

  process.exit(1);
};

deployFeeCollector();
