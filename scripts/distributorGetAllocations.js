// ES5 style
const config = require("./deploymentConfig");
const thorify = require("thorify").thorify;
const Web3 = require("web3");
const Distributor = require(config.pathToDistributorJson);
const readlineSync = require('readline-sync');

let network = null;
if (process.argv.length < 2)
{
    console.error("Usage: node scripts/distributorSetAllocation [mainnet|testnet]");
    process.exit(1);
}

network = config.network[process.argv[2]];
if (network === undefined) {
    console.error("Invalid network specified");
    process.exit(1);
}

const web3 = thorify(new Web3(), network.rpcUrl);
web3.eth.accounts.wallet.add(config.privateKey);

setAllocations = async() =>
{
    // This is the address associated with the private key
    const walletAddress = web3.eth.accounts.wallet[0].address;

    console.log("Using wallet address:", walletAddress);
    console.log("Using RPC:", web3.eth.currentProvider.RESTHost);

    try
    {
        let transactionReceipt = null;
        const distributorContract = new web3.eth.Contract(Distributor.abi, config.addresses.distributorAddress);

        if (network.name == "mainnet")
        {
            let input = readlineSync.question("Confirm you want to execute this on the MAINNET? (y/n) ");
            if (input != 'y') process.exit(1);
        }

        const numberOfAllocations = await distributorContract.methods.getAllocationsLength().call()
        for (let i = 0; i < numberOfAllocations; i++) {
            await distributorContract.methods.getAllocation(i).call(console.log)
        }

        // .then(console.log);

        // await distributorContract
        //         .methods
        //         .setAllocations(allocations)
        //         .send({ from: walletAddress })
        //         .on("receipt", (receipt) => {
        //             transactionReceipt = receipt;
        //         });

        // console.log("Transaction Hash:", transactionReceipt.transactionHash);
    }
    catch(error)
    {
        console.log("Execution failed with:", error)
    }
}

setAllocations();
