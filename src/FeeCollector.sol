// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.11;

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/interfaces/IERC20.sol";
import "@vexchange-contracts/vexchange-v2-core/contracts/interfaces/IVexchangeV2Pair.sol";
import "@vexchange-contracts/vexchange-v2-core/contracts/interfaces/IVexchangeV2Factory.sol";

contract FeeCollector is Ownable
{
    IVexchangeV2Factory mVexchangeFactory;

    constructor(IVexchangeV2Factory aVexchangeFactory) public
    {
        mVexchangeFactory = aVexchangeFactory;
    }

    function SellHolding(address aToken) public
    {
        // 1. confirm token is not DESIRED
        // 2. load DESIRED token to sell to (either default or specific to this token)
        // 3. Load pair for desired route, determine max trade size by market impact
        // 4. Sell Min(available, max_impact)
    }

    function WithdrawLP(IVexchangeV2Pair aPair) public
    {
        // 1. transfer our holding to the pair (if non-zero)
        // 2. trigger burn (don't care about min received)
    }
}
