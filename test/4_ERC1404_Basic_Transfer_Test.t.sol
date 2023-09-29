// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// Test Suite 4  -   Test ERC20 related functonalities including address
// whitelistings
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC1404TokenMinKYCv13.sol";
import "./helpers/ERC1404_Base_Setup.sol";

contract ERC1404_Basic_Transfer_Test is ERC1404_Base_Setup {
    uint transferAmount = 100;
    int transferNegativeAmount = -1;
    uint transferAmountZero = 0;
    uint transferMoreThanAvailable = initialSupply + 1;

    function setUp() public override {
        ERC1404_Base_Setup.setUp();
        token.modifyKYCData(addr1, 1, 1);
        token.modifyKYCData(addr2, 1, 1);
    }

    function test_Transfer_Amount() public {
        token.transfer(addr1, transferAmount);
        assertEq(token.balanceOf(addr1), transferAmount);
        assertEq(
            token.balanceOf(token.owner()),
            initialSupply - transferAmount
        );
    }

    function test_Issuer_Transfer_More_Than_Available_Amount() public {
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.transfer(addr1, transferMoreThanAvailable);
    }

    function test_Investor_Transfer_More_Than_Available_Amount() public {
        token.transfer(addr1, transferAmount);

        vm.prank(addr1);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.transfer(addr2, transferAmount + 1);
    }

    function test_Transfer_Zero_Amount() public {
        vm.expectRevert("Zero transfer amount not allowed");
        token.transfer(addr1, transferAmountZero);
    }

    function test_Transfer_Negative_Amount() public {
        // Since the int type is not compatible with the uint type you cannot even try to test with negative values
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.transfer(addr1, uint(transferNegativeAmount));
    }

    function testFail_Transfer_Overflow_Amount() public {
        token.transfer(addr1, uint(transferNegativeAmount) + 1);
    }

    function test_Transfer_From_Investor_To_Investor() public {
        token.transfer(addr1, transferAmount);

        vm.prank(addr1);
        token.transfer(addr2, transferAmount);
        assertEq(token.balanceOf(addr2), transferAmount);
        assertEq(token.balanceOf(addr1), 0);
    }
}
