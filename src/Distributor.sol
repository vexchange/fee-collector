// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.11;

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/interfaces/IERC20.sol";

struct DistributionAllocation
{
	address recipient;
	// 0 - 10000
	uint weightInBasisPoints;
}

interface DistributorInterface
{
	function distribute() external;
}

contract Distributor is Ownable, DistributorInterface
{
	IERC20 public immutable tokenReceiving;
	DistributionAllocation[] public allocations;
	uint public constant BASIS_POINTS_MAX = 10000;

	event AllocationsChanged();

	constructor(IERC20 _tokenReceiving)
	{
		tokenReceiving = _tokenReceiving;
	}

	function distribute() external
	{
		uint tokenBalance = tokenReceiving.balanceOf(address(this));
		for (uint i = 0; i < allocations.length; ++i)
		{
			uint amountToTransfer = tokenBalance * allocations[i].weightInBasisPoints / BASIS_POINTS_MAX;
			tokenReceiving.transfer(allocations[i].recipient, amountToTransfer);
		}
	}

	function sumPercentage(DistributionAllocation[] memory allocationsToCalculate) internal pure returns (uint sum)
	{
		sum = 0;
		for(uint i = 0; i < allocationsToCalculate.length; ++i)
		{
			sum += allocationsToCalculate[i].weightInBasisPoints;
		}
	}

	function min(uint256 a, uint256 b) internal pure returns (uint256)
	{
		return a > b ? a : b;
	}

	function changeAllocation(DistributionAllocation[] calldata newAllocation) onlyOwner external
	{
		require(sumPercentage(newAllocation) == BASIS_POINTS_MAX, "Provided allocations do not sum to 100");

		// DistributionAllocation[] storage newArray = [];

		uint256 lMinArrayLength = min(allocations.length, newAllocation.length);

		// 1. overwrite existing entries
		for (uint256 i = 0; i < lMinArrayLength; ++i)
		{
			allocations[i] = newAllocation[i];
		}

		// 2. grow array by new entries
		if (newAllocation.length > allocations.length) {
			for (uint256 i = allocations.length; i < newAllocation.length; ++i)
			{
				allocations.push(newAllocation[i]);
			}
		} else {
			uint256 lEntriesToPop = allocations.length - newAllocation.length;
			for (uint256 i = 0; i < lEntriesToPop; ++i) {
				allocations.pop();
			}
		}

		emit AllocationsChanged();
	}

	function recoverERC20(IERC20 tokenToRecover, address recipient) onlyOwner external
	{
        require(recipient != address(0), "RECOVERER_ZERO_ADDRESS");
		tokenToRecover.transfer(recipient, tokenToRecover.balanceOf(address(this)));
	}
}
