// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// Test Suite 2   -  Test Whitelist authorities and set reset thier status.
// Check addresses after setting whitelist status
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC1404TokenMinKYCv13.sol";
import "./helpers/ERC1404_Base_Setup.sol";

contract ERC1404_Whitelist_Authorities is ERC1404_Base_Setup {
    function setUp() public override {
        ERC1404_Base_Setup.setUp();
    }

    function test_CheckDefaultWhiteListAuthorityStatusForOwner() public {
        // Check that owner of the token address is  whitelisted by default
        (uint receiveRestriction, uint sendRestriction) = token.getKYCData(token.owner());
        assertEq(receiveRestriction, 1);
        assertEq(sendRestriction, 1);
    }

    function test_CheckDefaultWhiteListAuthorityStatusForSwapContract() public {
        // Check address set as Swap Token is also whitelisted
        (uint receiveRestriction, uint sendRestriction) = token.getKYCData(atomicSwapContractAddress);
        assertEq(receiveRestriction, 1);
        assertEq(sendRestriction, 1);
    }

    function test_getWhitelistAuthorityStatusNotWhitelisted() public {
        bool v1 = token.getWhitelistAuthorityStatus(addr1);
        assertEq(v1, false);
    }

    function test_SetWhitelistAuthorityStatus() public {
        token.setWhitelistAuthorityStatus(addr1);
        bool v1 = token.getWhitelistAuthorityStatus(addr1);
        assertEq(v1, true);
    }

    function test_removeWhitelistAuthorityStatusAsDeployer() public {
        token.setWhitelistAuthorityStatus(addr1);
        // remove whitelist authority status
        token.removeWhitelistAuthorityStatus(addr1);
        bool v2 = token.getWhitelistAuthorityStatus(addr1);
        assertEq(v2, false);
    }

    function test_removeWhitelistAuthorityStatusAsTokenOwner() public {
        vm.startPrank(token.owner());
        token.setWhitelistAuthorityStatus(addr1);
        // remove whitelist authority status
        token.removeWhitelistAuthorityStatus(addr1);
        bool v2 = token.getWhitelistAuthorityStatus(addr1);
        assertEq(v2, false);
        vm.stopPrank();
    }

    function test_notAuthorizedModifyKYCData() public {
        vm.prank(addr1);
        vm.expectRevert(
            "Only authorized addresses can control whitelisting of holder addresses"
        );
        token.modifyKYCData(addr2, 1, 1);
    }

    function test_authorizedModifyKYCData() public {
        // set whitelist authority
        token.setWhitelistAuthorityStatus(addr1);
        // now switch to whitelist authority and set another address whitelisted
        vm.prank(addr1);
        token.modifyKYCData(addr2, 1, 1);
        (uint receiveRestriction, uint sendRestriction) = token.getKYCData(addr2);
        assertEq(receiveRestriction, 1);
        assertEq(sendRestriction, 1);
    }
}
