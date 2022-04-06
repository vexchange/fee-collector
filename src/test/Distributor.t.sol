pragma solidity =0.8.11;

import "ds-test/test.sol";
import "src/Distributor.sol";
import "src/test/__fixtures/MintableERC20.sol";

contract DistributorTest is DSTest
{
	Distributor distributor; 
	MintableERC20 tokenReceiving = new MintableERC20("Wrapped Vechain", "WVET");	

	function setUp() public
	{
		distributor = new Distributor(tokenReceiving);
	}

	function test_correct_token() public
	{
		assertEq(address(distributor.tokenReceiving()), address(tokenReceiving));
	}
}
