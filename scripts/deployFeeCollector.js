// ES5 style
const config = require("./deploymentConfig");
const thorify = require("thorify").thorify;
const Web3 = require("web3");
const FeeCollectorContract = require(config.pathToFeeCollectorJson);
const readlineSync = require("readline-sync");

let network = null;
let desirableTokenAddress = null
let recipientAddress = null
if (process.argv.length < 5) {
  console.error(
    `
      Usage: node scripts/deployFeeCollector [mainnet|testnet] [desirable token name] [recipient name]
      Example: node scripts/deployFeeCollector mainnet wvet timelock
    `
  );
  process.exit(1);
}

network = config.network[process.argv[2]];
desirableTokenAddress = config.addresses[`${process.argv[3]}Address`]
recipientAddress = config.addresses[`${process.argv[4]}Address`]

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

const web3 = thorify(new Web3(), network.rpcUrl);
web3.eth.accounts.wallet.add(config.privateKey);

deployFeeCollector = async () => {
  // This is the address associated with the private key
  const walletAddress = web3.eth.accounts.wallet[0].address;

  console.log("Using wallet address:", walletAddress);
  console.log("Using RPC:", web3.eth.currentProvider.RESTHost);

  try {
    let transactionReceipt = null;

    console.log(
      "Attempting to deploy contract:",
      config.pathToFeeCollectorJson
    );

    if (network.name == "mainnet") {
      let input = readlineSync.question(
        "Confirm you want to deploy this on the MAINNET? (y/n) "
      );
      if (input != "y") process.exit(1);
    }

    const feeCollectorContract = new web3.eth.Contract(FeeCollectorContract.abi);

    await feeCollectorContract
      .deploy({
        data: FeeCollectorContract.bytecode.object,
        arguments: [config.addresses.V2Factory, desirableTokenAddress, recipientAddress],
      })
      .send({ from: walletAddress })
      .on("receipt", (receipt) => {
        transactionReceipt = receipt;
      });

    console.log({
      "Transaction Hash": transactionReceipt.transactionHash,
      "Contract Successfully deployed at address": transactionReceipt.contractAddress,
      arguments: [config.addresses.V2Factory, desirableTokenAddress, recipientAddress]
    })

    // await renounceMastership(transactionReceipt.contractAddress);
  } catch (error) {
    console.log("Deployment failed with:", error.message);
  }
};

deployFeeCollector();
