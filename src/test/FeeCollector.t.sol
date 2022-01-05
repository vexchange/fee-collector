// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.11;

import "ds-test/test.sol";
import "src/FeeCollector.sol";
import "src/test/__fixtures/MintableERC20.sol";
import "@vexchange-contracts/vexchange-v2-core/contracts/interfaces/IVexchangeV2Pair.sol";
import "@vexchange-contracts/vexchange-v2-core/contracts/interfaces/IVexchangeV2Factory.sol";

interface HEVM {
    function ffi(string[] calldata) external returns (bytes memory);
}

contract FeeCollectorTest is DSTest
{
    HEVM hevm = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    ERC20 mExternalToken = new MintableERC20("External", "EXT");
    ERC20 mDesiredToken = new MintableERC20("Desired", "DES");

    IVexchangeV2Factory mVexFactory;

    FeeCollector fee_collector;

    // ***** Helpers *****
    function deployContract(bytes memory code) internal returns (address addr)
    {
        assembly
        {
            addr := create(0, add(code, 0x20), mload(code))
            if iszero(addr)
            {
                revert (0, 0)
            }
        }
    }

    function getVexchangeBytecode() internal returns (bytes memory)
    {
        string[] memory cmds = new string[](2);
        cmds[0] = "node";
        cmds[1] = "scripts/getBytecode.js";

        return hevm.ffi(cmds);
    }

    // ***** Start Tests *****
    function setUp() public
    {
        bytes memory lBytecodeWithArgs = abi.encodePacked(
            getVexchangeBytecode(),
            abi.encode(100),            // swapFee
            abi.encode(2_500),          // platformFee
            abi.encode(address(this)),  // platformFeeTo
            abi.encode(address(this))   // defaultRecoverer
        );

        mVexFactory = IVexchangeV2Factory(deployContract(lBytecodeWithArgs));
        // IVexchangeV2Pair mTestPair = IVexchangeV2Pair(
        //     mVexFactory.createPair(address(mDesiredToken), address(mExternalToken))
        // );

        // FeeCollector mFeeCollector = new FeeCollector(mVexFactory, mDesiredToken, address(0));
    }

    function test_withdraw_lp() public
    {
        assertEq(uint256(1337), uint256(1337));
    }
}
