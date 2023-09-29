// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// Test Suite 3   -   Test EPOCH times in whitelisting.  Test both buy and sell restrictions
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC1404TokenMinKYCv13.sol";
import "./helpers/ERC1404_Base_Setup.sol";

contract ERC1404_Test_Whitelisting_Buy_Sell is ERC1404_Base_Setup {
    uint transferAmount = 100;

    function setUp() public override {
        ERC1404_Base_Setup.setUp();
        token.modifyKYCData(addr1, 1, 1);
    }

    function test_Set_Whitelist_KYC_Information() public {
        token.modifyKYCData(addr2, 500, 500);
        (uint receiveRestriction, uint sendRestriction) = token.getKYCData(
            addr2
        );
        assertEq(receiveRestriction, 500);
        assertEq(sendRestriction, 500);
    }

    function test_Tokens_Cannot_Be_Transferred_To_NonWhitelisted_Address()
        public
    {
        // is not whitelisted and this call will fail
        vm.expectRevert("Receiver is not whitelisted or blocked");
        token.transfer(addr2, transferAmount);
    }

    function test_Tokens_Cannot_Be_Minted_To_NonWhitelisted_Address() public {
        // is not whitelisted and this call will fail
        vm.expectRevert("Address is not yet whitelisted by issuer");
        token.mint(addr2, transferAmount);
    }

    function test_Tokens_Cannot_Be_Transferred_From_NonWhitelisted_Address()
        public
    {
        // is not whitelisted and this call will fail
        vm.prank(addr2);
        vm.expectRevert("Sender is not whitelisted or blocked");
        token.transfer(addr3, transferAmount);
    }

    function test_Tokens_Send_Restriction() public {
        token.modifyKYCData(addr2, 1, EPOCHTimeInFuture);
        vm.prank(addr2);
        vm.expectRevert(
            "Sender is whitelisted but is not eligible to send tokens and under holding period (KYC time restriction)"
        );
        token.transfer(addr1, transferAmount);
    }

    function test_Tokens_Receive_Restriction_Transfer() public {
        token.modifyKYCData(addr2, EPOCHTimeInFuture, EPOCHTimeInFuture);
        vm.expectRevert(
            "Receiver is whitelisted but is not yet eligible to receive tokens in his wallet (KYC time restriction)"
        );
        token.transfer(addr2, transferAmount);
    }

    // This should most likely revert but does not
    function test_Tokens_Receive_Restriction_Mint_Receive_Restricted() public {
        token.modifyKYCData(addr2, EPOCHTimeInFuture, EPOCHTimeInFuture);
        token.mint(addr2, transferAmount);
    }

    function test_Tokens_Receive_Restriction_Mint_Not_Whitelisted() public {
        vm.expectRevert("Address is not yet whitelisted by issuer");
        token.mint(addr2, transferAmount);
    }

    function test_Current_Total_Investors_Increase_Transfer() public {
        token.transfer(addr1, transferAmount);
        assertEq(token.currentTotalInvestors(), 1);
    }

    function test_Current_Total_Investors_Increase_Mint() public {
        token.mint(addr1, transferAmount);
        assertEq(token.currentTotalInvestors(), 1);
    }

    function test_Current_Total_Investors_Decrease() public {
        token.transfer(addr1, transferAmount);
        address owner = token.owner();
        vm.prank(addr1);
        token.transfer(owner, transferAmount);
        assertEq(token.currentTotalInvestors(), 0);
    }

    function test_Burn_To_Decrease_Total_Investors(uint8 amount) public {
        vm.assume(amount > 0);
        token.mint(addr1, amount);
        token.burn(addr1, amount);
        assertEq(token.currentTotalInvestors(), 0);
    }
}
