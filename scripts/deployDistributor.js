// ES5 style
const config = require("./deploymentConfig");
const thorify = require("thorify").thorify;
const Web3 = require("web3");
const DistributorContract = require(config.pathToDistributorJson);
const readlineSync = require("readline-sync");

let network = null;
if (process.argv.length < 3) {
  console.error(
    "Usage: node scripts/deployDistributor [mainnet|testnet]"
  );
  process.exit(1);
}

network = config.network[process.argv[2]];
if (network === undefined) {
  console.error("Invalid network specified");
  process.exit(1);
}

const web3 = thorify(new Web3(), network.rpcUrl);
web3.eth.accounts.wallet.add(config.privateKey);

deployDistributor = async () => {
  // This is the address associated with the private key
  const walletAddress = web3.eth.accounts.wallet[0].address;

  console.log("Using wallet address:", walletAddress);
  console.log("Using RPC:", web3.eth.currentProvider.RESTHost);

  try {
    let transactionReceipt = null;

    console.log(
      "Attempting to deploy contract:",
      config.pathToDistributorJson
    );

    if (network.name == "mainnet") {
      let input = readlineSync.question(
        "Confirm you want to deploy this on the MAINNET? (y/n) "
      );
      if (input != "y") process.exit(1);
    }

    const distributorContract = new web3.eth.Contract(DistributorContract.abi);

    await distributorContract
      .deploy({
        data: DistributorContract.bytecode.object,
        arguments: [config.addresses.wvetAddress],
      })
      .send({ from: walletAddress })
      .on("receipt", (receipt) => {
        transactionReceipt = receipt;
      });

    console.log({
      "Transaction Hash": transactionReceipt.transactionHash,
      "Contract Successfully deployed at address": transactionReceipt.contractAddress
    })

    // await renounceMastership(transactionReceipt.contractAddress);
  } catch (error) {
    console.log("Deployment failed with:", error.message);
  }
};

deployDistributor();
