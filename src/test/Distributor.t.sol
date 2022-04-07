pragma solidity =0.8.11;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "src/Distributor.sol";
import "src/test/__fixtures/MintableERC20.sol";

contract DistributorTest is DSTest
{
    Vm private vm = Vm(HEVM_ADDRESS);

    Distributor private mDistributor; 
    MintableERC20 private mIncomingToken = new MintableERC20("Wrapped Vechain", "WVET");
    MintableERC20 private mTokenToRecover = new MintableERC20("Recover Me", "RME");
    address private mRecipient1 = address(1);
    address private mRecipient2 = address(2);

    function setUp() public
    {
        mDistributor = new Distributor(mIncomingToken);
    }

    function testIncomingToken() public
    {
        // assert
        assertEq(address(mDistributor.incomingToken()), address(mIncomingToken));
    }

    function testSingleCorrectAllocaation() public
    {
        // arrange
        Allocation[] memory daArray = new Allocation[](1);
        Allocation memory da = Allocation(mRecipient1, mDistributor.BASIS_POINTS_MAX());

        daArray[0] = da;

        // act
        mDistributor.setAllocations(daArray);

        // assert
        assertEq(mDistributor.getAllocationsLength(), 1);
        assertEq(mDistributor.getAllocation(0).weight, mDistributor.BASIS_POINTS_MAX());
    }   

    function testTwoCorrectAllocation() public
    {
        // arrange 
        Allocation[] memory daArray = new Allocation[](2);
        Allocation memory da1 = Allocation(mRecipient1, 8000);
        Allocation memory da2 = Allocation(mRecipient2, 2000);

        daArray[0] = da1;
        daArray[1] = da2;

        // act
        mDistributor.setAllocations(daArray);

        // assert
        assertEq(mDistributor.getAllocation(0).weight, 8000);
        assertEq(mDistributor.getAllocation(1).weight, 2000);
    }

    function testExpandAllocation() public 
    {
        // arrange 
        Allocation[] memory lAllocations1 = new Allocation[](2);
        lAllocations1[0] = Allocation(mRecipient1, 6000);
        lAllocations1[1] = Allocation(mRecipient2, 4000);
        mDistributor.setAllocations(lAllocations1);

        Allocation[] memory lAllocations2 = new Allocation[](5);
        for (uint256 i = 0; i < 5; ++i)
        {
            lAllocations2[i] = Allocation(mRecipient1, mDistributor.BASIS_POINTS_MAX() / 5);
        }

        // act
        mDistributor.setAllocations(lAllocations2);

        // assert
        assertEq(mDistributor.getAllocationsLength(), 5);
    }

    function testShrinkAllocation() public
    {
        // arrange
        Allocation[] memory daArray = new Allocation[](10);
        for (uint256 i = 0; i < 10; ++i)
        {
            daArray[i] = Allocation(mRecipient1, mDistributor.BASIS_POINTS_MAX() / 10);
        }
        mDistributor.setAllocations(daArray);
        
        Allocation[] memory newDaArray = new Allocation[](1);
        newDaArray[0] = Allocation(mRecipient2, mDistributor.BASIS_POINTS_MAX());
        
        // act
        mDistributor.setAllocations(newDaArray);

        // assert
        assertEq(mDistributor.getAllocationsLength(), 1);
    }

    function testShrinkAllocationToZero() public
    {
        // arrange
        Allocation[] memory daArray = new Allocation[](10);
        for (uint256 i = 0; i < 10; ++i)
        {
            daArray[i] = Allocation(mRecipient1, mDistributor.BASIS_POINTS_MAX() / 10);
        }
        mDistributor.setAllocations(daArray);
        
        Allocation[] memory newDaArray = new Allocation[](0);

        // act & assert
        vm.expectRevert("allocations do not sum to 10000");
        mDistributor.setAllocations(newDaArray);
    }


    function testAllocationsExceedMax() public
    {
        // arrange
        Allocation[] memory daArray = new Allocation[](2);

        Allocation memory da1 = Allocation(mRecipient1, 5000);
        Allocation memory da2 = Allocation(mRecipient2, 8000);

        daArray[0] = da1;
        daArray[1] = da2;

        // act & assert
        vm.expectRevert("allocations do not sum to 10000");
        mDistributor.setAllocations(daArray);
    }

    function testNotOwner() public
    {
        // arrange
        Allocation[] memory daArray = new Allocation[](1);
        Allocation memory da = Allocation(mRecipient1, mDistributor.BASIS_POINTS_MAX());

        daArray[0] = da;
        
        vm.prank(address(3));  

        // act & assert
        vm.expectRevert("Ownable: caller is not the owner");
        mDistributor.setAllocations(daArray);
    }

    function testDistributeBasic() public
    {
        // arrange
        Allocation[] memory daArray = new Allocation[](2);
        Allocation memory da1 = Allocation(mRecipient1, 8000);
        Allocation memory da2 = Allocation(mRecipient2, 2000);

        daArray[0] = da1;
        daArray[1] = da2;

        mDistributor.setAllocations(daArray);
        mIncomingToken.mint(address(mDistributor), 100e18);

        // act
        mDistributor.distribute();

        // assert
        assertEq(mIncomingToken.balanceOf(mRecipient1), 80e18);
        assertEq(mIncomingToken.balanceOf(mRecipient2), 20e18);
        assertEq(mIncomingToken.balanceOf(address(mDistributor)), 0);
    }

    function testDistributeBeforeAllocation() public
    {
        // arrange
        mIncomingToken.mint(address(mDistributor), 100e18);

        // act
        mDistributor.distribute();

        // assert
        assertEq(mIncomingToken.balanceOf(address(mDistributor)), 100e18);
    }

    function testRecoverBasic() public
    {
        // arrange
        mTokenToRecover.mint(address(mDistributor), 100e18);

        // act
        mDistributor.recoverToken(mTokenToRecover, mRecipient1);

        // assert
        assertEq(mTokenToRecover.balanceOf(mRecipient1), 100e18);
    }

    function testRecoverZeroRecoverer() public
    {
        // act & assert
        vm.expectRevert("recover zero address");
        mDistributor.recoverToken(mTokenToRecover, address(0));
    }

    function testRecoverReceivingToken() public
    {
        // act & assert
        vm.expectRevert("cannnot recover incoming token");
        mDistributor.recoverToken(mIncomingToken, mRecipient1);
    }
}
