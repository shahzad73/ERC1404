// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "../src/DividendPayout.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Global_Helpers} from "./helpers/Global_Helpers.sol";

contract DividendPayoutTest is Test {
    DividendPayout public dividendPayout;
    Global_Helpers public helpers;
    ERC20 public token;

    uint[] amounts;
    address[] addresses;
    uint totalAmount;

    address alice = address(0x1);
    uint totalAliceAmount = 1 ether;
    uint numberOfRecipients = 200;

    function setUp() public {
        dividendPayout = new DividendPayout();
        helpers = new Global_Helpers();
        token = new ERC20("USDCoin", "USDC");

        // Mocks users, amounts and totalAmount
        addresses = helpers.createUsers(numberOfRecipients);
        (amounts, totalAmount) = helpers.createAmounts(numberOfRecipients);

        // Adds ether and USDC balance to msg.sender
        deal(alice, totalAliceAmount);
        deal(address(token), alice, totalAliceAmount);
    }

    function test_BulkTransferDividends() public {
        vm.startPrank(alice);
        token.approve(address(dividendPayout), totalAmount);
        vm.expectEmit(true, true, true, false);
        dividendPayout.bulkTransferDividends(token, addresses, amounts, totalAmount);
        vm.stopPrank();
        for (uint i; i < addresses.length; i++) {
            assertEq(amounts[i], token.balanceOf(addresses[i]));
        }
    }

    function testFail_BulkTransferDividends_insufficientAllowance_1() public {
        console.log("allowance before ", token.allowance(alice, address(dividendPayout)));
        vm.startPrank(alice);
        token.approve(address(dividendPayout), totalAmount - 1);
        console.log("allowance after", token.allowance(alice, address(dividendPayout)));
        dividendPayout.bulkTransferDividends(token, addresses, amounts, totalAmount);
        vm.stopPrank();
    }

    function testFail_BulkTransferDividends_insufficientAllowance_2() public {
        console.log("allowance before ", token.allowance(alice, address(dividendPayout)));
        vm.startPrank(alice);
        console.log("allowance after", token.allowance(alice, address(dividendPayout)));
        dividendPayout.bulkTransferDividends(token, addresses, amounts, totalAmount);
        vm.stopPrank();
    }

    function test_ExpectRevert_BulkTransferDividends_arraysDifferentSize_1() public {
        addresses.push(address(0x6));

        vm.startPrank(alice);
        vm.expectRevert("Arrays must be of the same length");
        dividendPayout.bulkTransferDividends(token, addresses, amounts, totalAmount);
        vm.stopPrank();
    }

    function test_ExpectRevert_BulkTransferDividends_arraysDifferentSize_2() public {
        amounts.push(5);

        vm.startPrank(alice);
        vm.expectRevert("Arrays must be of the same length");
        dividendPayout.bulkTransferDividends(token, addresses, amounts, totalAmount);
        vm.stopPrank();
    }

    function test_ExpectRevert_BulkTransferDividends_insufficientBalance() public {
        totalAmount = totalAliceAmount + 1;
        vm.startPrank(alice);
        vm.expectRevert("The sender has insufficient balance");
        dividendPayout.bulkTransferDividends(token, addresses, amounts, totalAmount);
        vm.stopPrank();
    }

    function test_ExpectRevert_BulkTransferDividends_amountIsZero() public {
        amounts.pop();
        amounts.push(0);

        vm.startPrank(alice);
        token.approve(address(dividendPayout), totalAmount);
        vm.expectRevert(DividendPayout.ZeroAmount.selector);
        dividendPayout.bulkTransferDividends(token, addresses, amounts, totalAmount);
        vm.stopPrank();
    }

    function test_ExpectRevert_BulkTransferDividends_insufficientTotalAmount() public {
        totalAmount = 41;

        vm.startPrank(alice);
        token.approve(address(dividendPayout), totalAmount);
        vm.expectRevert(DividendPayout.InsufficientTotalAmount.selector);
        dividendPayout.bulkTransferDividends(token, addresses, amounts, totalAmount);
        vm.stopPrank();
    }

    function test_ExpectRevert_BulkTransferDividends_ExceededNumberOfRecipients() public {
        uint amount = numberOfRecipients - addresses.length;
        for (uint i; i < amount + 1; i++) {
            addresses.push(address(0x1));
            amounts.push(4);
        }

        vm.startPrank(alice);
        token.approve(address(dividendPayout), totalAmount);
        vm.expectRevert("Number of recipients must be under or equal to 200");
        dividendPayout.bulkTransferDividends(token, addresses, amounts, totalAmount);
        vm.stopPrank();
    }

    function test_ExpectRevert_BulkTransferDividends_BothEmptyArrays() public {
        address[] memory emptyAddresses;
        uint[] memory emptyAmounts;

        vm.startPrank(alice);
        token.approve(address(dividendPayout), totalAmount);
        vm.expectRevert("Length of arrays should be more than zero");
        dividendPayout.bulkTransferDividends(token, emptyAddresses, emptyAmounts, totalAmount);
        vm.stopPrank();
    }

    function test_ExpectRevert_BulkTransferDividends_EmptyAddressesArrays() public {
        address[] memory emptyAddresses;

        vm.startPrank(alice);
        token.approve(address(dividendPayout), totalAmount);
        vm.expectRevert("Length of arrays should be more than zero");
        dividendPayout.bulkTransferDividends(token, emptyAddresses, amounts, totalAmount);
        vm.stopPrank();
    }

    function test_ExpectRevert_BulkTransferDividends_EmptyAmountsArrays() public {
        uint[] memory emptyAmounts;

        vm.startPrank(alice);
        token.approve(address(dividendPayout), totalAmount);
        vm.expectRevert("Length of arrays should be more than zero");
        dividendPayout.bulkTransferDividends(token, addresses, emptyAmounts, totalAmount);
        vm.stopPrank();
    }
}
