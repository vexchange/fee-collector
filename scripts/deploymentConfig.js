require("dotenv").config();

module.exports = {
  privateKey: process.env.PRIVATE_KEY,
  network: {
    mainnet: {
      name: "mainnet",
      rpcUrl: "http://mainnet02.vechain.fi.blockorder.net",
    },
    testnet: {
      name: "testnet",
      rpcUrl: "http://testnet02.vechain.fi.blockorder.net",
    },
  },
  pathToDistributorJson: "../out/Distributor.sol/Distributor.json",
  pathToFeeCollectorJson: "../out/FeeCollector.sol/FeeCollector.json",
  pathToIERC20Json: "../out/IERC20.sol/IERC20.json",
  pathToVexchangeV2FactoryJson:
    "../out/IVexchangeV2Factory.sol/IVexchangeV2Factory.json",
  addresses: {
    vexAddress: "0x0BD802635eb9cEB3fCBe60470D2857B86841aab6",
    wovAddress: "0x170F4BA8e7ACF6510f55dB26047C83D13498AF8A",
    veusdAddress: "0x4E17357053dA4b473e2daa2c65C2c949545724b8",
    wvetAddress: "0xD8CCDD85abDbF68DFEc95f06c973e87B1b5A9997",
    timelockAddress: "0x41D293Ee2924FF67Bd934fC092Be408162448f86",
    governorAlphaAddress: "0xa0a636893Ed688076286174Bc23b34C31BED3089",
    feeCollectorAddress: "0x17D252083c79Db33866295078ED955B04e1C61c8",
    feeCollectorVexAddress:  "0x10445a86645838306194c07f81ebd00bb7b82598",
    feeCollectorWvetAddress:  "0xc2ccf0af1b34367b639d0fd7bb4335da12bcc798",
    distributorAddress: "0x72ee1c849b7353ad1452e56af136e4b0ff68a07e",
    V2Factory: "0xB312582C023Cc4938CF0faEA2fd609b46D7509A2",
    vexVetPair: "0x39cd888a1583498AD30E716625AE1a00ff51286D",
    wovVetPair: "0xD86bed355d9d6A4c951e96755Dd0c3cf004d6CD0",
    veusdVetPair: "0x25491130A43d43AB0951d66CdF7ddaC7B1dB681b",
    multirewardsForVexVet: "0x538f8890a383c44e59df4c7263d96ca8048da2c7",
    multirewardsForWovVet: "0xa8d1a1c88329320234581e203474fe19b99473d3",
    multirewardsForVeusdVet: "0xf1be58861b4bcacd6c7d026ba3de994361f5d3aa",
    network: "mainnet",
  },
};
