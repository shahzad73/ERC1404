// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// Test Suite 7   -   Check force transfer
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC1404TokenMinKYCv13.sol";
import "./helpers/ERC1404_Base_Setup.sol";

contract ERC1404_Check_Force_Transfer is ERC1404_Base_Setup {
    function setUp() public override {
        ERC1404_Base_Setup.setUp();
        token.modifyKYCData(addr1, 1, 1);
        token.modifyKYCData(addr3, EPOCHTimeInFuture, EPOCHTimeInFuture);
    }

    function test_Force_Transfer_Tokens_From_Investors(uint amount) public {
        amount = bound(amount, 1, initialSupply);
        address tokenOwner = token.owner();
        token.transfer(addr1, amount);
        token.forceTransferToken(addr1, amount);
        assertEq(token.balanceOf(tokenOwner), initialSupply);
        assertEq(token.balanceOf(addr1), 0);
    }

    function test_Force_Transfer_More_Than_Available_Tokens_From_Investor(uint amount) public {
        amount = bound(amount, 1, initialSupply);
        token.transfer(addr1, amount);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.forceTransferToken(addr1, amount + 1);
    }

     function test_Force_Transfer_More_Than_Available_Tokens_From_Investor_Zero_Balance(uint amount) public {
        amount = bound(amount, 1, initialSupply);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.forceTransferToken(addr1, amount);
    }

    function test_Force_Transfer_Tokens_From_Investor_Not_Whitelisted(uint amount) public {
        amount = bound(amount, 1, initialSupply);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.forceTransferToken(addr2, amount);
    }

    function test_Force_Transfer_Tokens_From_Investor_Restricted(uint amount) public {
        amount = bound(amount, 1, initialSupply);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.forceTransferToken(addr3, amount);
    }
}
