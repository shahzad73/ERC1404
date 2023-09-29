// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// Test Suite 11   -    Test setTradingHoldingPeriod and check trading with and without
// this restriction
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC1404TokenMinKYCv13.sol";
import "./helpers/ERC1404_Base_Setup.sol";

contract ERC1404_Trading_Holding_Period is ERC1404_Base_Setup {
    function setUp() public override {
        ERC1404_Base_Setup.setUp();
        token.modifyKYCData(addr1, 1, 1);
        token.modifyKYCData(addr2, 1, 1);
    }

    function test_Trading_Holding_Period_Issuer_Can_Transfer(
        uint amount
    ) public {
        amount = bound(amount, 1, initialSupply);
        token.setTradingHoldingPeriod(EPOCHTimeInFuture);
        // this transfer is possible as issuer is sending tokens to investors
        token.transfer(addr1, amount);
    }

    function test_Trading_Holding_Period_Investor_Cannot_Transfer(
        uint amount
    ) public {
        amount = bound(amount, 1, initialSupply);
        token.transfer(addr1, amount);
        token.setTradingHoldingPeriod(EPOCHTimeInFuture);
        // this transfer is possible as issuer is sending tokens to investors
        vm.prank(addr1);
        vm.expectRevert(
            "All transfers are disabled because Holding Period is not yet expired"
        );
        token.transfer(addr2, amount);
    }

    function test_Trading_Holding_Period_investors_Can_Transfer_To_Each_other(
        uint amount
    ) public {
        amount = bound(amount, 1, initialSupply);
        // Add balance to investor
        token.setTradingHoldingPeriod(EPOCHTimeInFuture);
        token.transfer(addr1, amount);
        // remove holding period restriction
        token.setTradingHoldingPeriod(1);
        //and now investors can transfer shares to each other
        vm.prank(addr1);
        token.transfer(addr2, amount);
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(addr1), 0);
        assertEq(token.balanceOf(addr2), amount);
        assertEq(token.balanceOf(token.owner()), initialSupply - amount);
    }

    function test_Trading_Holding_Period_To_Zero_investors_Can_Transfer_To_Each_other(
        uint amount
    ) public {
        amount = bound(amount, 1, initialSupply);
        // Add balance to investor
        token.setTradingHoldingPeriod(EPOCHTimeInFuture);
        token.transfer(addr1, amount);
        // remove holding period restriction
        token.setTradingHoldingPeriod(0);
        //and now investors can transfer shares to each other
        vm.prank(addr1);
        token.transfer(addr2, amount);
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(addr1), 0);
        assertEq(token.balanceOf(addr2), amount);
        assertEq(token.balanceOf(token.owner()), initialSupply - amount);
    }
}
