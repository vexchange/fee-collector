// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.11;

import "ds-test/test.sol";
import "src/FeeCollector.sol";
import "src/test/__fixtures/MintableERC20.sol";
import "@vexchange-contracts/vexchange-v2-core/contracts/VexchangeV2Factory.sol";
import "@vexchange-contracts/vexchange-v2-core/contracts/interfaces/IVexchangeV2Pair.sol";

contract FeeCollectorTest is DSTest
{
    FeeCollector private fee_collector;

    function setUp() public
    {
        ERC20 mDesiredToken = new MintableERC20("Desired", "DES");
        ERC20 mExternalToken = new MintableERC20("External", "EXT");

        VexchangeV2Factory mVexFactory = new VexchangeV2Factory(
            100,
            25000,
            address(this),
            address(this)
        );
        IVexchangeV2Pair mTestPair = mVexFactory.createPair(mDesiredToken, mExternalToken);

        FeeCollector mFeeCollector = new FeeCollector(mVexFactory, mDesiredToken, address(0));
    }

    function test_withdraw_lp() public
    {

    }
}
