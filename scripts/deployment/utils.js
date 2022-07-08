import {
  DISTRIBUTOR_JSON_PATH,
  FEE_COLLECTOR_JSON_PATH,
  V2FACTORY_ADDRESS,
} from "../config.js";
import { abi } from "thor-devkit";
import fs from "fs";
import path from "path";
const __dirname = path.resolve();

const DistributorContract = JSON.parse(
  fs.readFileSync(path.join(__dirname, DISTRIBUTOR_JSON_PATH), "utf-8")
);

const FeeCollectorContract = JSON.parse(
  fs.readFileSync(path.join(__dirname, FEE_COLLECTOR_JSON_PATH), "utf-8")
);

const FEE_COLLECTOR_CONSTRUCTOR_ABI = {
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

export const deployDistributorContract = async (connex, contructorArgs) => {
  return new Promise(async (resolve, reject) => {
    console.log(`Deploying distributor contract(${DISTRIBUTOR_JSON_PATH})...`);
    const coder = new abi.Function(DISTRIBUTOR_CONSTRUCTOR_ABI);
    const data =
      DistributorContract.bytecode.object +
      coder
        .encode(contructorArgs.incomingToken)
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
      return reject("Failed to deploy distributor contract");
    }

    console.log(receipt);
    return resolve(receipt.outputs[0].contractAddress);
  });
};

export const configureDistributorAllocations = async (connex, obj) => {
  return new Promise(async (resolve, reject) => {
    console.log(`Configuring distributor allocations...`);
    const distributorContract = connex.thor.account(
      obj.distributorContractAddress
    );
    const method = distributorContract.method(DISTRIBUTOR_SETALLOCATIONS_ABI);
    const resSetAllocations = await connex.vendor
      .sign("tx", [method.asClause(obj.allocations)])
      .request();
    const setAllocationsTransaction = connex.thor.transaction(
      resSetAllocations.txid
    );

    let receipt = null;
    while (!receipt) {
      await connex.thor.ticker().next();
      receipt = await setAllocationsTransaction.getReceipt();
    }

    if (receipt.reverted) {
      return reject("Failed to call setAllocations method");
    }

    console.log(receipt);
    return resolve(receipt);
  });
};

export const deployFeeCollectorContract = async (connex, contructorArgs) => {
  return new Promise(async (resolve, reject) => {
    console.log(
      `Deploying fee collector contract(${FEE_COLLECTOR_JSON_PATH})...`
    );
    const coder = new abi.Function(FEE_COLLECTOR_CONSTRUCTOR_ABI);
    const data =
      FeeCollectorContract.bytecode.object +
      coder
        .encode(
          V2FACTORY_ADDRESS,
          contructorArgs.desirableTokenAddress,
          contructorArgs.recipientAddress
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
      return reject("Failed to deploy distributor contract");
    }

    const contractAddress = receipt.outputs[0].contractAddress;
    console.log(receipt, {
      ...contructorArgs,
      contractAddress,
    });

    return resolve(contractAddress);
  });
};
