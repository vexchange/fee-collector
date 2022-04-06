pragma solidity =0.8.13;

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

	constructor(IERC20 _tokenReceiving,
				DistributionAllocation[] memory _allocations)
	{
		require(sumPercentage(_allocations) == BASIS_POINTS_MAX, "Provided allocations do not sum to 100");
		tokenReceiving = _tokenReceiving;
		allocations = _allocations;
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

	function changeAllocation(DistributionAllocation[] calldata newAllocation) onlyOwner external
	{ 
		require(sumPercentage(newAllocation) == BASIS_POINTS_MAX, "Provided allocations do not sum to 100");

		// DistributionAllocation[] storage newArray = [];

		for (uint i = 0; i < newAllocation.length; ++i)
		{
			address recipient = newAllocation[i].recipient;
			allocations[i].recipient = recipient;
			// allocations[i].weightInBasisPoints = newAllocation[i].weightInBasisPoints;
		}

		// allocations = newArray;
		
		emit AllocationsChanged();
	}

	function recoverERC20(IERC20 tokenToRecover, address recipient) onlyOwner external
	{
        require(recipient != address(0), "RECOVERER_ZERO_ADDRESS");
		tokenToRecover.transfer(recipient, tokenToRecover.balanceOf(address(this)));
	}
}
