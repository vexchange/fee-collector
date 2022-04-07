pragma solidity =0.8.11;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "src/Distributor.sol";
import "src/test/__fixtures/MintableERC20.sol";

contract DistributorTest is DSTest
{
    Vm private vm = Vm(HEVM_ADDRESS);

    Distributor private distributor; 
    MintableERC20 private incomingToken = new MintableERC20("Wrapped Vechain", "WVET");
    MintableERC20 private tokenToRecover = new MintableERC20("Recover Me", "RME");
    address private recipient1 = address(1);
    address private recipient2 = address(2);

    function setUp() public
    {
        distributor = new Distributor(incomingToken);
    }

    function testIncomingToken() public
    {
        // assert
        assertEq(address(distributor.incomingToken()), address(incomingToken));
    }

    function testSingleCorrectAllocaation() public
    {
        // arrange
        Allocation[] memory daArray = new Allocation[](1);
        Allocation memory da = Allocation(recipient1, distributor.BASIS_POINTS_MAX());

        daArray[0] = da;

        // act
        distributor.setAllocations(daArray);

        // assert
        assertEq(distributor.getAllocationsLength(), 1);
        assertEq(distributor.getAllocation(0).weight, distributor.BASIS_POINTS_MAX());
    }   

    function testTwoCorrectAllocation() public
    {
        // arrange 
        Allocation[] memory daArray = new Allocation[](2);
        Allocation memory da1 = Allocation(recipient1, 8000);
        Allocation memory da2 = Allocation(recipient2, 2000);

        daArray[0] = da1;
        daArray[1] = da2;

        // act
        distributor.setAllocations(daArray);

        // assert
        assertEq(distributor.getAllocation(0).weight, 8000);
        assertEq(distributor.getAllocation(1).weight, 2000);
    }

    // todo: add tests that have varying before and after lengths of arrays
    // to test the correct expansion and shrinkage of arrays


    function testTotalMoreThan10000BasisPoints() public
    {
        // arrange
        Allocation[] memory daArray = new Allocation[](2);

        Allocation memory da1 = Allocation(recipient1, 5000);
        Allocation memory da2 = Allocation(recipient2, 8000);

        daArray[0] = da1;
        daArray[1] = da2;

        // act & assert
        vm.expectRevert("allocations do not sum to 10000");
        distributor.setAllocations(daArray);
    }

    function testNotOwner() public
    {
        // arrange
        Allocation[] memory daArray = new Allocation[](1);
        Allocation memory da = Allocation(recipient1, distributor.BASIS_POINTS_MAX());

        daArray[0] = da;
        
        vm.prank(address(3));  

        // act & assert
        vm.expectRevert("Ownable: caller is not the owner");
        distributor.setAllocations(daArray);
    }

    function testDistributeBasic() public
    {
        // arrange
        Allocation[] memory daArray = new Allocation[](2);
        Allocation memory da1 = Allocation(recipient1, 8000);
        Allocation memory da2 = Allocation(recipient2, 2000);

        daArray[0] = da1;
        daArray[1] = da2;

        distributor.setAllocations(daArray);

        // act
        incomingToken.mint(address(distributor), 100e18);
        distributor.distribute();

        // assert
        assertEq(incomingToken.balanceOf(recipient1), 80e18);
        assertEq(incomingToken.balanceOf(recipient2), 20e18);
        assertEq(incomingToken.balanceOf(address(distributor)), 0);
    }

    function testRecoverBasic() public
    {
        // arrange
        tokenToRecover.mint(address(distributor), 100e18);

        // act
        distributor.recoverToken(tokenToRecover, recipient1);

        // assert
        assertEq(tokenToRecover.balanceOf(recipient1), 100e18);
    }

    function testRecoverZeroRecoverer() public
    {
        // act & assert
        vm.expectRevert("recover zero address");
        distributor.recoverToken(tokenToRecover, address(0));
    }

    function testRecoverReceivingToken() public
    {
        // act & assert
        vm.expectRevert("cannnot recover incoming token");
        distributor.recoverToken(incomingToken, recipient1);
    }
}
