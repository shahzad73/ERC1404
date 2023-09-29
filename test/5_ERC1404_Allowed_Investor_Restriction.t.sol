// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// Test Suite 5   -   Test Allowed Investors restriction sceanrios
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC1404TokenMinKYCv13.sol";
import "./helpers/ERC1404_Base_Setup.sol";

contract ERC1404_Allowed_Investor_Restriction is ERC1404_Base_Setup {
    function setUp() public override {
        ERC1404_Base_Setup.setUp();
        token.modifyKYCData(addr1, 1, 1);
        token.modifyKYCData(addr2, 1, 1);
        token.modifyKYCData(addr3, 1, 1);
        token.modifyKYCData(addr4, 1, 1);
    }

    function test_Change_Allowed_Investors_Amount(uint64 amount) public {
        token.resetAllowedInvestors(amount);
        assertEq(token.allowedInvestors(), amount);
    }

    function test_Allowed_Investors_Amount_Transfer(
        uint transferAmount
    ) public {
        transferAmount = bound(transferAmount, 1, initialSupply / 2);
        token.resetAllowedInvestors(2);
        token.transfer(addr1, transferAmount);
        token.transfer(addr2, transferAmount);
        assertEq(token.currentTotalInvestors(), 2);
        assertEq(token.allowedInvestors(), 2);
    }

    function test_Allowed_Investors_Amount_Transfer_After_Change(
        uint transferAmount
    ) public {
        transferAmount = bound(transferAmount, 1, initialSupply / 3);
        token.resetAllowedInvestors(2);
        token.transfer(addr1, transferAmount);
        token.transfer(addr2, transferAmount);
        token.resetAllowedInvestors(3);
        token.transfer(addr3, transferAmount);
        assertEq(token.currentTotalInvestors(), 3);
        assertEq(token.allowedInvestors(), 3);
    }

    function test_Allowed_Investors_Amount_Mint(uint8 mintAmount) public {
        vm.assume(mintAmount > 0);
        token.resetAllowedInvestors(2);
        token.mint(addr1, mintAmount);
        token.mint(addr2, mintAmount);
        assertEq(token.currentTotalInvestors(), 2);
        assertEq(token.allowedInvestors(), 2);
    }

    function test_Allowed_Investors_Amount_Mint_After_Change(
        uint8 mintAmount
    ) public {
        vm.assume(mintAmount > 0);
        token.resetAllowedInvestors(2);
        token.mint(addr1, mintAmount);
        token.mint(addr2, mintAmount);
        token.resetAllowedInvestors(3);
        token.mint(addr3, mintAmount);
        assertEq(token.currentTotalInvestors(), 3);
        assertEq(token.allowedInvestors(), 3);
    }

    function test_Change_Allowed_Investors_Amount_After_currentTotalInvestors_Above_Zero_Change(
        uint8 amount
    ) public {
        vm.assume(amount > 0);
        token.resetAllowedInvestors(2);
        token.mint(addr1, amount);
        token.transfer(addr2, amount);
        vm.expectRevert(
            "Allowed Token holders cannot be less than current token holders with non-zero balance"
        );
        token.resetAllowedInvestors(1);
    }

    function test_Change_Allowed_Investors_Amount_After_currentTotalInvestors_Above_Zero_Default(
        uint8 amount
    ) public {
        vm.assume(amount > 0);
        token.mint(addr1, amount);
        token.mint(addr2, amount);
        vm.expectRevert(
            "Allowed Token holders cannot be less than current token holders with non-zero balance"
        );
        token.resetAllowedInvestors(1);
    }

    function test_Change_Allowed_Investors_Amount_To_Zero_After_currentTotalInvestors_Above_Zero_Change(
        uint8 amount
    ) public {
        vm.assume(amount > 0);
        token.resetAllowedInvestors(2);
        token.mint(addr1, amount);
        token.mint(addr2, amount);
        token.resetAllowedInvestors(0);
        assertEq(token.currentTotalInvestors(), 2);
        assertEq(token.allowedInvestors(), 0);
    }

    // This flow is a quite weird edge case
    function test_Transfer_Between_Investors_When_Only_One_Investor_Allowed(
        uint amount
    ) public {
        amount = bound(amount, 1, initialSupply);
        token.resetAllowedInvestors(1);
        token.transfer(addr1, amount);

        vm.prank(addr1);
        token.transfer(addr2, amount);
        assertEq(token.currentTotalInvestors(), 1);
        assertEq(token.allowedInvestors(), 1);
    }

    function test_Setup_Allowed_Investors_And_Try_To_Transfer_More_Than_That(
        uint amount
    ) public {
        amount = bound(amount, 1, initialSupply / 3);
        token.resetAllowedInvestors(2);
        token.transfer(addr1, amount);
        token.transfer(addr2, amount);
        vm.expectRevert(
            "Max allowed addresses with non-zero restriction is in place, this transfer will exceed this limitation"
        );
        token.transfer(addr3, amount);
    }

    function test_Setup_Allowed_Investors_And_Try_To_Mint_More_Than_That(
        uint8 amount
    ) public {
        vm.assume(amount > 0);
        token.resetAllowedInvestors(2);
        token.mint(addr1, amount);
        token.mint(addr2, amount);
        vm.expectRevert(
            "Minting not allowed to this address as allowed token holder restriction is in place and minting will increase the allowed limit"
        );
        token.mint(addr3, amount);
    }

    
}
