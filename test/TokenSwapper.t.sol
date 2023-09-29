// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.14;

import "ds-test/test.sol";
import { TokenSwapper } from "../src/ERC20_swapper_V4.sol";
import { ERC1404TokenMinKYCv13 } from "../src/ERC1404TokenMinKYCv13.sol";
import "forge-std/console.sol";

// This is an example of how to write tests for solidity
// Pay attention to the file name (.t.sol is used in order to recognize which files are meant for tests)

interface Vm {
    // you can use this to test fail cases from require or revert reasons
    function expectRevert(bytes calldata) external;
    // use this to call contracts from different addresses for the next 1 call
    function prank(address) external;

    // use this to call contracts from a different address until the stopPrank function is called
    function startPrank(address) external;
    // use this to stop the chain of pranks
    function stopPrank() external;

    function warp(uint256) external;    
}

interface CheatCodes {
    // Gets address for a given private key, (privateKey) => (address)
    function addr(uint256) external returns (address);
}

// if you need to use structs, you can import them through inheritance (in this case TokenSwapper's Swap struct)
contract TokenSwapperTest is DSTest, TokenSwapper {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    address public addr1;
    address public addr2;


    TokenSwapper swapper;
    ERC1404TokenMinKYCv13 token1;
    ERC1404TokenMinKYCv13 token2;
    uint amount1 = 100;
    uint amount2 = 200;

    // setUp will be run before any tests
    function setUp() public {
        addr1 = cheats.addr(1);
        addr2 = cheats.addr(2);
        uint64 limitInvestors = 0;
        swapper = new TokenSwapper();
        token1 = new ERC1404TokenMinKYCv13(1000, 'Token1', 'TKN1', limitInvestors, 0, 'share certificate', 'company homepage', 'company legal docs', address(swapper), 1);
        token2 = new ERC1404TokenMinKYCv13(1000, 'Token2', 'TKN2', limitInvestors, 0, 'share certificate', 'company homepage', 'company legal docs', address(swapper), 1);

        token1.modifyKYCData(address(swapper), 1, 1);
        token1.modifyKYCData(addr1, 1, 1);
        token1.modifyKYCData(addr2, 1, 1);
        token1.mint(addr1, amount1);

        token2.modifyKYCData(address(swapper), 1, 1);
        token2.modifyKYCData(addr1, 1, 1);
        token2.modifyKYCData(addr2, 1, 1);
        token2.mint(addr2, amount2);
    }

    function test_swap_tokeen_total_supply () public {
        // check total supply and balance of test accounts 

        assertEq( token1.totalSupply(), 1100);
        assertEq( token2.totalSupply(), 1200 );

        assertEq( token1.balanceOf(addr1), 100 );
        assertEq( token1.balanceOf(addr2), 0 );
        assertEq( token1.balanceOf(address(swapper)), 0 );        

        assertEq( token2.balanceOf(addr1), 0 );
        assertEq( token2.balanceOf(addr2), 200 );        
        assertEq( token2.balanceOf(address(swapper)), 0 );        

    }

    function test_swap_is_open_and_valid_after_opening() public {
        // addr1 opens the swap with 10 tokens offer against 100 tokens         
        vm.startPrank(addr1);
        token1.approve(address(swapper), 10);
        assertEq( token1.allowance(addr1, address(swapper)), 10 );
        swapper.open(2, addr2, address(token1), 10, address(token2), 100, 100);
        vm.stopPrank();  

        (Swap memory result, uint status) = swapper.getSwapData(addr1, 2);
        assertEq( status, 1 );
    }

    function test_swap_between_token1_token2() public {
        // addr1 will give 50 token 1     from    100 addr2 

        uint swapNumber = 3;
        uint expiry = 100;

        // addr1 opens the swap with 10 tokens offer against 100 tokens         
        vm.startPrank(addr1);
        token1.approve(address(swapper), 10);
        assertEq( token1.allowance(addr1, address(swapper)), 10 );
        swapper.open(swapNumber, addr2, address(token1), 10, address(token2), 100, expiry);
        vm.stopPrank();        

        (Swap memory result2, uint status2) = swapper.getSwapData(addr1, swapNumber);
        assertEq( status2, 1 );

        // addr2 closes the deal giving 100 tokens and receiving 10 tokens
        vm.startPrank(addr2);
        token2.approve(address(swapper), 100);
        assertEq( token2.allowance(addr2, address(swapper)), 100 );
        swapper.close(addr1, swapNumber);
        vm.stopPrank();        

        assertEq( token1.balanceOf(addr1), 90 );  
        assertEq( token2.balanceOf(addr1), 100 );  

        assertEq( token1.balanceOf(addr2), 10 );  
        assertEq( token2.balanceOf(addr2), 100 );  

        (Swap memory result, uint status) = swapper.getSwapData(addr1, swapNumber);
        assertEq( status, 2 );
    }

    function test_swap_can_be_closed_multiple_times() public {

        uint swapNumber = 4;
        uint expiry = 100;

        // addr1 opens the swap with 10 tokens offer against 100 tokens         
        vm.startPrank(addr1);
        token1.approve(address(swapper), 10);
        assertEq( token1.allowance(addr1, address(swapper)), 10 );
        swapper.open(swapNumber, addr2, address(token1), 10, address(token2), 100, expiry);
        vm.stopPrank();        

        // addr2 closes the deal giving 100 tokens and receiving 10 tokens
        vm.startPrank(addr2);
        token2.approve(address(swapper), 100);
        assertEq( token2.allowance(addr2, address(swapper)), 100 );
        swapper.close(addr1, swapNumber);
        vm.stopPrank();        

        assertEq( token1.balanceOf(addr1), 90 );  
        assertEq( token2.balanceOf(addr1), 100 );  

        assertEq( token1.balanceOf(addr2), 10 );  
        assertEq( token2.balanceOf(addr2), 100 );  

        // try to close swap again and catch error
        vm.startPrank(addr2);
        vm.expectRevert ("TokenSwapper: swap not open");      
        swapper.close(addr1, swapNumber);
        vm.stopPrank(); 
    }

    function test_swap_number_already_taken() public {
        // addr1 opens the swap with 10 tokens offer against 100 tokens         
        vm.startPrank(addr1);
        token1.approve(address(swapper), 10);
        assertEq( token1.allowance(addr1, address(swapper)), 10 );
        swapper.open(5, addr2, address(token1), 10, address(token2), 100, 100);
        vm.stopPrank();  

        (Swap memory result, uint status) = swapper.getSwapData(addr1, 5);
        assertEq( status, 1 );


        vm.startPrank(addr1);
        token1.approve(address(swapper), 10);
        assertEq( token1.allowance(addr1, address(swapper)), 10 );
        vm.expectRevert ("TokenSwapper: swapNumber already used");      
        swapper.open(5, addr2, address(token1), 10, address(token2), 100, 100);
        vm.stopPrank();
    }

    function test_swap_expire_close_failure() public {

        uint swapNumber = 10;

        // addr1 opens the swap with 10 tokens offer against 100 tokens         
        vm.startPrank(addr1);
        token1.approve(address(swapper), 10);
        assertEq( token1.allowance(addr1, address(swapper)), 10 );
        swapper.open(swapNumber, addr2, address(token1), 10, address(token2), 100, 100);
        vm.stopPrank();  

        (Swap memory result, uint status) = swapper.getSwapData(addr1, swapNumber);
        assertEq( status, 1 );

        // print current timestamp
        // emit log_uint(block.timestamp); 
        vm.warp(1000);

        vm.startPrank(addr2);
        token2.approve(address(swapper), 100);
        assertEq( token2.allowance(addr2, address(swapper)), 100 );
        vm.expectRevert("TokenSwapper: swap expiration passed");
        swapper.close(addr1, swapNumber);
        vm.stopPrank();  

    }

    function test_expire_and_take_back_tokens() public {

        uint swapNumber = 11;

        // addr1 opens the swap with 10 tokens offer against 100 tokens         
        vm.startPrank(addr1);
        token1.approve(address(swapper), 10);
        assertEq( token1.allowance(addr1, address(swapper)), 10 );
        swapper.open(swapNumber, addr2, address(token1), 10, address(token2), 100, 100);
        vm.stopPrank();  

        (Swap memory result, uint status) = swapper.getSwapData(addr1, swapNumber);
        assertEq( status, 1 );

        // print current timestamp
        // emit log_uint(block.timestamp); 
        vm.warp(1000);

        assertEq( token1.balanceOf(addr1), 90 );
        assertEq( token1.balanceOf(address(swapper)), 10 );                

        vm.startPrank(addr1);
        swapper.expire(addr1, swapNumber);
        vm.stopPrank();  


        assertEq( token1.totalSupply(), 1100);
        assertEq( token2.totalSupply(), 1200 );

        assertEq( token1.balanceOf(addr1), 100 );
        assertEq( token1.balanceOf(addr2), 0 );
        assertEq( token1.balanceOf(address(swapper)), 0 );        

        assertEq( token2.balanceOf(addr1), 0 );
        assertEq( token2.balanceOf(addr2), 200 );        
        assertEq( token2.balanceOf(address(swapper)), 0 );   

    }    

}

