// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.11;

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/interfaces/IERC20.sol";

/// @param recipient The address to receive the share of incomingToken
/// @param weight The share of incoming tokens in basis points
/// @dev The sum of all weights should be BASIS_POINTS_MAX
struct Allocation
{
    address recipient;
    uint16 weight;
}

contract Distributor is Ownable
{
    uint16 public constant BASIS_POINTS_MAX = 10000;

    IERC20 public immutable incomingToken;
    Allocation[] public allocations;

    constructor(IERC20 aIncomingToken)
    {
        incomingToken = aIncomingToken;
    }

    function getAllocationsLength() external view returns (uint256)
    { 
        return allocations.length;
    }

    function getAllocation(uint256 aIndex) external view returns (Allocation memory)
    {
        return allocations[aIndex];
    }

    function sumWeights(Allocation[] memory aAllocations) internal pure returns (uint256 lSum)
    {
        lSum = 0;
        for(uint256 i = 0; i < aAllocations.length; ++i) {
            lSum += aAllocations[i].weight;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256)
    {
        return a < b ? a : b;
    }

    function setAllocations(Allocation[] calldata aAllocations) external onlyOwner 
    {
        require(sumWeights(aAllocations) == BASIS_POINTS_MAX, "allocations do not sum to 100");

        uint256 lMinArrayLength = min(allocations.length, aAllocations.length);

        // 1. overwrite existing entries
        for (uint256 i = 0; i < lMinArrayLength; ++i) {
            allocations[i] = aAllocations[i];
        }

        // 2. grow/shink array to accomodate remainder
        if (aAllocations.length > allocations.length) {
            for (uint256 i = allocations.length; i < aAllocations.length; ++i) {
                allocations.push(aAllocations[i]);
            }
        }
        else {
            uint256 lEntriesToPop = allocations.length - aAllocations.length;
            for (uint256 i = 0; i < lEntriesToPop; ++i) {
                allocations.pop();
            }
        }
    }

    function recoverToken(IERC20 aToken, address aRecipient) external onlyOwner 
    {
        require(aRecipient != address(0), "recover zero address");
        require(aToken != incomingToken, "cannnot recover incoming token");

        aToken.transfer(aRecipient, aToken.balanceOf(address(this)));
    }

    function distribute() external
    {
        uint256 lTokenBalance = incomingToken.balanceOf(address(this));

        for (uint256 i = 0; i < allocations.length; ++i) {
            uint256 lAmountToTransfer = lTokenBalance * allocations[i].weight / BASIS_POINTS_MAX;

            incomingToken.transfer(allocations[i].recipient, lAmountToTransfer);
        }
    }
}
