// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.11;

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/interfaces/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@vexchange-contracts/vexchange-v2-core/contracts/interfaces/IVexchangeV2Pair.sol";
import "@vexchange-contracts/vexchange-v2-core/contracts/interfaces/IVexchangeV2Factory.sol";

struct TokenConfig
{
    address SwapTo;         // if not set, will swap to mDesiredToken
    bool    ShouldNotSell;  // flag to disable selling of desirable assets
}

contract FeeCollector is Ownable
{
    using SafeERC20 for IERC20;

    IVexchangeV2Factory   mVexchangeFactory;
    IERC20                mDesiredToken;
    address               mRecipient;

    mapping(address => TokenConfig)  mConfig;

    constructor(
        IVexchangeV2Factory aVexchangeFactory,
        IERC20 aDesiredToken,
        address aRecipient
    )
    {
        mVexchangeFactory = aVexchangeFactory;
        mDesiredToken = aDesiredToken;
        mRecipient = aRecipient;
    }

    function CalcMaxSaleImpact(IVexchangeV2Pair aPair, address aTokenToSell) private view returns (uint256)
    {
        uint256 lSwapFee = aPair.swapFee();
        uint256 lPlatformFee = aPair.platformFee();
        address lToken0 = aPair.token0();

        uint256 lPlatformRake = lSwapFee * lPlatformFee;

        uint256 lTokenHoldings;
        if (lToken0 == aTokenToSell)
        {
            (lTokenHoldings, ,) = aPair.getReserves();
        }
        else
        {
            (lTokenHoldings, ,) = aPair.getReserves();
        }

        return lPlatformRake * lTokenHoldings / 1e8;  // swapFee * platformFee are scaled 1e4
    }

    function Min(uint256 a, uint256 b) private pure returns (uint256)
    {
        return a > b ? a : b;
    }

    function Swap(
        IVexchangeV2Pair aPair,
        address aFromToken,
        address aToToken,
        uint256 aAmountIn,
        uint256 aSwapFee,
        address aTo
    ) private
    {
        (uint256 lReserve0, uint256 lReserve1, ) = aPair.getReserves();
        uint256 lAmountInWithFee = aAmountIn * aSwapFee / 1e4;

        if (aToToken > aFromToken)
        {
            uint256 lAmountOut = lAmountInWithFee * lReserve1 / (lReserve0 * 10_000 + lAmountInWithFee);

            // effects
            IERC20(aFromToken).safeTransfer(address(aPair), aAmountIn);
            aPair.swap(lAmountOut, 0, aTo, "");
        }
        else
        {
            uint256 lAmountOut = lAmountInWithFee * lReserve0 / (lReserve1 * 10_000 + lAmountInWithFee);

            // effects
            IERC20(aFromToken).safeTransfer(address(aPair), aAmountIn);
            aPair.swap(0, lAmountOut, aTo, "");
        }
    }

    function SellHolding(address aToken) public
    {
        require(aToken != address(mDesiredToken), "cannot sell mDesiredToken");

        TokenConfig memory lConfig = mConfig[aToken];
        require(lConfig.ShouldNotSell == false, "selling disabled for aToken");

        address lTargetToken;
        if (lConfig.SwapTo == address(0))
        {
            lTargetToken = address(mDesiredToken);
        }
        else
        {
            lTargetToken = lConfig.SwapTo;
        }

        // compute the sale
        IVexchangeV2Pair lSwapPair = IVexchangeV2Pair(mVexchangeFactory.getPair(aToken, lTargetToken));  // can be optimized
        uint256 lCurrentHolding = IERC20(aToken).balanceOf(address(this));
        uint256 lMaxImpact = CalcMaxSaleImpact(lSwapPair, aToken);
        uint256 lAmountToSell = Min(lCurrentHolding, lMaxImpact);

        Swap(lSwapPair, aToken, lTargetToken, lAmountToSell, lSwapPair.swapFee(), mRecipient);
    }

    function WithdrawLP(IVexchangeV2Pair aPair) public
    {
        // checks
        uint256 lOurHolding = aPair.balanceOf(address(this));

        // effects
        aPair.transfer(address(aPair), lOurHolding);
        aPair.burn(address(this));
    }
}

// TODO:
// - Replace Min() with external library method
// - Investigate solmate
// - Gas optimization
