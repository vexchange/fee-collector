pragma solidity =0.8.11;

import "ds-test/test.sol";
import "src/Distributor.sol";
import "src/test/__fixtures/MintableERC20.sol";

contract DistributorTest is DSTest
{
	Distributor distributor; 
	MintableERC20 tokenReceiving = new MintableERC20("Wrapped Vechain", "WVET");
	MintableERC20 tokenToRecover = new MintableERC20("Recover Me", "RME");
	address recipient1 = address(0xdD31a4a99748605ed2d574702b975EC320f4A561);
	address recipient2 = address(0x1FEAeC7adEaC20b6f0178D03796293235774AEC6);

	function setUp() public
	{
		distributor = new Distributor(tokenReceiving);
	}

	function test_correct_token() public
	{
		assertEq(address(distributor.tokenReceiving()), address(tokenReceiving));
	}

	function test_single_correct_allocaation() public
	{
		DistributionAllocation[] memory daArray = new DistributionAllocation[](1);
		DistributionAllocation memory da = DistributionAllocation(recipient1, distributor.BASIS_POINTS_MAX());

		daArray[0] = da;

		distributor.setAllocation(daArray);

		assertEq(distributor.getAllocationsLength(), 1);
		assertEq(distributor.getAllocation(0).weightInBasisPoints, distributor.BASIS_POINTS_MAX());
	}	

	function test_two_correct_allocation() public
	{
		DistributionAllocation[] memory daArray = new DistributionAllocation[](2);
		DistributionAllocation memory da1 = DistributionAllocation(recipient1, 8000);
		DistributionAllocation memory da2 = DistributionAllocation(recipient1, 2000);

		daArray[0] = da1;
		daArray[1] = da2;

		distributor.setAllocation(daArray);

		assertEq(distributor.getAllocation(0).weightInBasisPoints, 8000);
		assertEq(distributor.getAllocation(1).weightInBasisPoints, 2000);
	}

	function testFail_more_than_10000_basis_points() public
	{
		DistributionAllocation[] memory daArray = new DistributionAllocation[](2);

		DistributionAllocation memory da1 = DistributionAllocation(recipient1, 5000);
		DistributionAllocation memory da2 = DistributionAllocation(recipient1, 8000);

		daArray[0] = da1;
		daArray[1] = da2;

		distributor.setAllocation(daArray);
	}

	function test_distribute_basic() public
	{
		// set allocation
		DistributionAllocation[] memory daArray = new DistributionAllocation[](2);
		DistributionAllocation memory da1 = DistributionAllocation(recipient1, 8000);
		DistributionAllocation memory da2 = DistributionAllocation(recipient2, 2000);

		daArray[0] = da1;
		daArray[1] = da2;

		distributor.setAllocation(daArray);

		// transfer tokens to distributor
		tokenReceiving.Mint(address(distributor), 100e18);
		distributor.distribute();

		// check that the recipients have got the tokens
		assertEq(tokenReceiving.balanceOf(recipient1), 80e18);
		assertEq(tokenReceiving.balanceOf(recipient2), 20e18);
	}

	function test_recover_basic() public
	{
		tokenToRecover.Mint(address(distributor), 100e18);
		distributor.recoverERC20(tokenToRecover, recipient1);

		assertEq(tokenToRecover.balanceOf(recipient1), 100e18);
	}

	function testFail_recover_zero_recoverer() public
	{
		distributor.recoverERC20(tokenToRecover, address(0));
	}

	function testFail_recover_receiving_token() public
	{
		distributor.recoverERC20(tokenReceiving, recipient1);
	}
}
