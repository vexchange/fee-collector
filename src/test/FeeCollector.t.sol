// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.11;

import "ds-test/test.sol";
import "src/FeeCollector.sol";
import "src/test/__fixtures/MintableERC20.sol";
import "@vexchange-contracts/vexchange-v2-core/contracts/interfaces/IVexchangeV2Pair.sol";
import "@vexchange-contracts/vexchange-v2-core/contracts/interfaces/IVexchangeV2Factory.sol";

interface HEVM {
    function ffi(string[] calldata) external returns (bytes memory);
    function warp(uint256 timestamp) external;
}

contract FeeCollectorTest is DSTest
{
    // ***** Test State *****
    // this is the cheat code address. HEVM exposes certain cheat codes to test contracts. one of these is the ffi
    // cheat code that lets you execute arbitrary shell commands (in this case loading the bytecode of Vexchange V2)
    HEVM private hevm = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    MintableERC20 private mExternalToken = new MintableERC20("External", "EXT");
    MintableERC20 private mDesiredToken = new MintableERC20("Desired", "DES");

    IVexchangeV2Factory private mVexFactory;
    IVexchangeV2Pair private mTestPair;

    FeeCollector private mFeeCollector;

    // ***** Helpers *****
    function deployContract(bytes memory code) private returns (address addr)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly
        {
            addr := create(0, add(code, 0x20), mload(code))
            if iszero(addr)
            {
                revert (0, 0)
            }
        }
    }

    function getVexchangeBytecode() private returns (bytes memory)
    {
        string[] memory cmds = new string[](2);
        cmds[0] = "node";
        cmds[1] = "scripts/getBytecode.js";

        return hevm.ffi(cmds);
    }

    function calculateMaxSale(IVexchangeV2Pair aPair, IERC20 aToken) private view returns (uint256 rMaxInput)
    {
        // pair state
        uint256 lSwapFee = aPair.swapFee();
        uint256 lPlatformFee = aPair.platformFee();
        if (lPlatformFee == 0)
        {
            lPlatformFee = 10_000;
        }

        uint256 lPlatformRake = lSwapFee * lPlatformFee;  // has been scaled by 1e8

        // balances
        uint256 lCollectorBal = aToken.balanceOf(address(mFeeCollector));
        uint256 lPairLiqProxy = aToken.balanceOf(address(aPair));

        uint256 lMaxImpact = lPairLiqProxy * lPlatformRake / 1e8;

        return lMaxImpact < lCollectorBal
            ? lMaxImpact
            : lCollectorBal;
    }

    // ***** Setup *****
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
        mTestPair = IVexchangeV2Pair(mVexFactory.createPair(
            address(mDesiredToken),
            address(mExternalToken)
        ));

        mFeeCollector = new FeeCollector(mVexFactory, mDesiredToken, address(this));

        // set timezone to 24 hours in the future to get passed 8 hour sale rate limit
        hevm.warp(24 hours);
    }

    // ***** Tests *****
    function test_withdraw() public
    {
        // sanity
        mExternalToken.Mint(address(mFeeCollector), 10e18);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 10e18);

        // act
        mFeeCollector.WithdrawToken(mExternalToken, address(this));

        // assert
        assertEq(mExternalToken.balanceOf(address(this)), 10e18);
    }

    function testFail_disable_sales() public
    {
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(1));

        // sanity
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(mFeeCollector));
        mFeeCollector.BreakApartLP(mTestPair);
        assertEq(mTestPair.balanceOf(address(mFeeCollector)),      0);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 100e18);
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)),  50e18);
        assertEq(mDesiredToken.balanceOf(address(this)),           0);

        // act
        mFeeCollector.UpdateConfig(
            mExternalToken,
            TokenConfig({ DisableSales: true, SwapTo: IERC20(address(0)), LastSaleTime: 0 })
        );
        mFeeCollector.SellHolding(mExternalToken);
    }

    function testFail_disable_pair() public
    {
        // arrange
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(mFeeCollector));

        // act
        mFeeCollector.SetPairStatus(mTestPair, true);
        mFeeCollector.BreakApartLP(mTestPair);
    }

    function test_withdraw_lp() public
    {
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);

        // sanity
        uint256 lLiquidityMinted = mTestPair.mint(address(mFeeCollector));
        assertEq(mTestPair.balanceOf(address(mFeeCollector)), lLiquidityMinted);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 0);
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)),  0);

        // act
        mFeeCollector.BreakApartLP(mTestPair);

        // assert
        assertEq(mTestPair.balanceOf(address(mFeeCollector)),      0);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 99999999999999998585);
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)),  49999999999999999292);
    }

    function test_sell_holding() public
    {
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(1));

        // sanity
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(mFeeCollector));
        mFeeCollector.BreakApartLP(mTestPair);
        assertEq(mTestPair.balanceOf(address(mFeeCollector)),      0);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 100e18);
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)),  50e18);
        assertEq(mDesiredToken.balanceOf(address(this)),           0);

        // act
        uint256 lMaxSale = calculateMaxSale(mTestPair, mExternalToken);
        mFeeCollector.SellHolding(mExternalToken);

        // assert
        uint256 lOurBal = mDesiredToken.balanceOf(address(this));
        uint256 lCollectorBal = mDesiredToken.balanceOf(address(mFeeCollector));
        uint256 lTestPairBal = mDesiredToken.balanceOf(address(mTestPair));

        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 100e18 - lMaxSale);  // we sold lMaxSale
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)), 50e18);  // mFeeCollector received nothing
        assertEq(lOurBal, 100e18 - lCollectorBal - lTestPairBal);  // we received the result of the swap
    }

    function testFail_sell_holding() public
    {
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(1));

        // sanity
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(mFeeCollector));
        mFeeCollector.BreakApartLP(mTestPair);

        // act
        mFeeCollector.SellHolding(mDesiredToken);
    }

    function test_sweep_holding() public
    {
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);

        // sanity
        mTestPair.mint(address(mFeeCollector));
        mFeeCollector.BreakApartLP(mTestPair);
        assertEq(mTestPair.balanceOf(address(mFeeCollector)),      0);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 99999999999999998585);
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)),  49999999999999999292);

        // act
        mFeeCollector.SweepDesired();

        // assert
        uint256 lOurBal = mDesiredToken.balanceOf(address(this));
        uint256 lCollectorBal = mDesiredToken.balanceOf(address(mFeeCollector));
        uint256 lTestPairBal = mDesiredToken.balanceOf(address(mTestPair));

        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 99999999999999998585);
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)),  0);
        assertEq(lOurBal + lCollectorBal + lTestPairBal, 50e18);
    }

    function test_sell_and_sweep_holding() public
    {
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(1));

        // sanity
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(mFeeCollector));
        mFeeCollector.BreakApartLP(mTestPair);
        assertEq(mTestPair.balanceOf(address(mFeeCollector)),      0);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 100e18);
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)),  50e18);

        // act
        uint256 lMaxSale = calculateMaxSale(mTestPair, mExternalToken);
        mFeeCollector.SellHolding(mExternalToken);
        mFeeCollector.SweepDesired();

        // assert
        uint256 lOurBal = mDesiredToken.balanceOf(address(this));
        uint256 lTestPairBal = mDesiredToken.balanceOf(address(mTestPair));

        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 100e18 - lMaxSale);
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)),  0);
        assertEq(lOurBal, 100e18 - lTestPairBal);  // we have all desired outside of test pair
    }

    function test_swap_to_other() public
    {
        // arrange
        MintableERC20 lOtherToken = new MintableERC20("Other Token", "OTHER");
        IVexchangeV2Pair lOtherPair = IVexchangeV2Pair(mVexFactory.createPair(
            address(mExternalToken),
            address(lOtherToken)
        ));

        lOtherToken.Mint(address(lOtherPair), 2e18);  // this is a more expensive token
        mExternalToken.Mint(address(lOtherPair), 50e18);
        lOtherPair.mint(address(1));

        // sanity
        lOtherToken.Mint(address(lOtherPair), 2e18);
        mExternalToken.Mint(address(lOtherPair), 50e18);
        lOtherPair.mint(address(mFeeCollector));
        mFeeCollector.BreakApartLP(lOtherPair);
        assertEq(lOtherPair.balanceOf(address(mFeeCollector)),     0);
        assertEq(lOtherToken.balanceOf(address(mFeeCollector)),    2e18);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 50e18);

        // act
        uint256 lMaxSale = calculateMaxSale(lOtherPair, lOtherToken);
        mFeeCollector.UpdateConfig(
            lOtherToken,
            TokenConfig({ DisableSales: false, SwapTo: mExternalToken, LastSaleTime: 0 })
        );
        mFeeCollector.SellHolding(lOtherToken);
        mFeeCollector.SweepDesired();

        // assert
        uint256 lOtherPairBal = mExternalToken.balanceOf(address(lOtherPair));
        uint256 lCollectorBal = mExternalToken.balanceOf(address(mFeeCollector));

        assertEq(lOtherToken.balanceOf(address(mFeeCollector)), 2e18 - lMaxSale);  // we sold as much as we could
        assertEq(lCollectorBal, 100e18 - lOtherPairBal);  // we have all external outside of other pair
    }

    function testFail_swap_too_quickly() public
    {
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(1));

        // sanity
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(mFeeCollector));
        mFeeCollector.BreakApartLP(mTestPair);
        assertEq(mTestPair.balanceOf(address(mFeeCollector)),      0);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 100e18);
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)),  50e18);
        assertEq(mDesiredToken.balanceOf(address(this)),           0);

        // act
        mFeeCollector.SellHolding(mExternalToken);
        mFeeCollector.SellHolding(mExternalToken);
    }

    function test_sell_two_different() public
    {
        MintableERC20 lOtherToken = new MintableERC20("Other Token", "OTHER");
        IVexchangeV2Pair lOtherPair = IVexchangeV2Pair(mVexFactory.createPair(
            address(mExternalToken),
            address(lOtherToken)
        ));

        lOtherToken.Mint(address(lOtherPair), 2e18);  // this is a more expensive token
        mExternalToken.Mint(address(lOtherPair), 50e18);
        lOtherPair.mint(address(1));
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(1));

        // sanity
        lOtherToken.Mint(address(lOtherPair), 2e18);
        mExternalToken.Mint(address(lOtherPair), 50e18);
        lOtherPair.mint(address(mFeeCollector));
        mFeeCollector.BreakApartLP(lOtherPair);
        assertEq(lOtherPair.balanceOf(address(mFeeCollector)),     0);
        assertEq(lOtherToken.balanceOf(address(mFeeCollector)),    2e18);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 50e18);
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(mFeeCollector));
        mFeeCollector.BreakApartLP(mTestPair);
        assertEq(mTestPair.balanceOf(address(mFeeCollector)),      0);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 150e18);
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)),  50e18);
        assertEq(mDesiredToken.balanceOf(address(this)),           0);

        // act
        mFeeCollector.UpdateConfig(
            lOtherToken,
            TokenConfig({ DisableSales: false, SwapTo: mExternalToken, LastSaleTime: 0 })
        );
        uint256 lMaxSaleExternal = calculateMaxSale(mTestPair, mExternalToken);
        uint256 lMaxSaleOther = calculateMaxSale(lOtherPair, lOtherToken);
        mFeeCollector.SellHolding(mExternalToken);
        mFeeCollector.SellHolding(lOtherToken);

        // assert
        uint256 lOurBal = mDesiredToken.balanceOf(address(this));
        uint256 lTestPairBalDesired = mDesiredToken.balanceOf(address(mTestPair));
        uint256 lCollectorBalDesired = mDesiredToken.balanceOf(address(mFeeCollector));

        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 150e18 - lMaxSaleExternal);  // we sold lMaxSale
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)), 50e18);  // mFeeCollector received nothing
        assertEq(lOurBal, 100e18 - lCollectorBalDesired - lTestPairBalDesired);  // we received the result of the swap
        assertEq(lOtherToken.balanceOf(address(mFeeCollector)), 2e18 - lMaxSaleOther);  // we sold as much as we could
    }

    function test_sell_holding_no_platform_fee() public
    {
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(1));

        // sanity
        mExternalToken.Mint(address(mTestPair), 100e18);
        mDesiredToken.Mint(address(mTestPair), 50e18);
        mTestPair.mint(address(mFeeCollector));
        mFeeCollector.BreakApartLP(mTestPair);
        assertEq(mTestPair.balanceOf(address(mFeeCollector)),      0);
        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 100e18);
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)),  50e18);
        assertEq(mDesiredToken.balanceOf(address(this)),           0);

        // act
        mVexFactory.setPlatformFeeForPair(address(mTestPair), 0);

        uint256 lMaxSale = calculateMaxSale(mTestPair, mExternalToken);
        mFeeCollector.SellHolding(mExternalToken);

        // assert
        uint256 lOurBal = mDesiredToken.balanceOf(address(this));
        uint256 lCollectorBal = mDesiredToken.balanceOf(address(mFeeCollector));
        uint256 lTestPairBal = mDesiredToken.balanceOf(address(mTestPair));

        assertEq(mExternalToken.balanceOf(address(mFeeCollector)), 100e18 - lMaxSale);  // we sold lMaxSale
        assertEq(mDesiredToken.balanceOf(address(mFeeCollector)), 50e18);  // mFeeCollector received nothing
        assertEq(lOurBal, 100e18 - lCollectorBal - lTestPairBal);  // we received the result of the swap
    }
}
