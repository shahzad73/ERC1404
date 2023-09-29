// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC1404TokenMinKYCv13.sol";
import "./helpers/ERC1404_Base_Setup.sol";

// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// Test Suite 1   -  Test Default Values set while setting up security token
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

contract ERC1404_Default_Values is ERC1404_Base_Setup {
    function setUp() public override {
        ERC1404_Base_Setup.setUp();
    }

    // Check default decimal places which must be 18
    function test_Check_Decimals() public {
        assertEq(token.decimals(), decimalsPlaces);
    }

    // Check default total supply of tokens
    function test_Check_Total_Supply() public {
        assertEq(token.totalSupply(), initialSupply);
    }

    // Check owner contains the total balance minted
    function test_Check_BalanceOf_Issuer() public {
        assertEq(token.balanceOf(token.owner()), initialSupply);
    }

    // Check any other address that must not contain any tokens
    function test_Check_Default_BalanceOf_Account(
        address randomAddress
    ) public {
        vm.assume(randomAddress != address(this) && randomAddress != token.owner());
        assertEq(token.balanceOf(randomAddress), 0);
    }

    // Check swap contract address is whitelisted
    function test_Check_Account_Is_Whitelisted() public {
        (uint receiveRestriction, uint sendRestriction) = token.getKYCData(atomicSwapContractAddress);
        assertEq(receiveRestriction, 1);
        assertEq(sendRestriction, 1);
    }

    // Check any random address is not whitelisted
    function test_Check_Account_Is_Not_Whitelisted(
        address randomAddress
    ) public {
        vm.assume(randomAddress != address(this) && randomAddress != token.owner());
        (uint receiveRestriction, uint sendRestriction) = token.getKYCData(randomAddress);
        assertEq(receiveRestriction, 0);
        assertEq(sendRestriction, 0);
    }

    // Test tradingHoldingPeriod is set to it's default value 1
    function test_Trading_Holding_Period_Has_Default_Value() public {
        assertEq(token.tradingHoldingPeriod(), tradingHoldingPeriod);
    }

    // Test allowedInvestors is set to it's default value 0
    function test_Allowed_Investors_Set_To_Default_Value() public {
        assertEq(token.allowedInvestors(), allowedInvestors);
    }

    function test_Check_Default_Name_And_Symbol_Values() public {
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.IssuancePlatform(), "DigiShares");
        assertEq(token.issuanceProtocol(), "ERC-1404");
        assertEq(token.allowedInvestors(), allowedInvestors);
        assertEq(token.currentTotalInvestors(), 0);
    }
}
