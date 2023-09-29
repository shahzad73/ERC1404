// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// Test Suite 8   -   Test ERC1404 transfer restrictons for investor and check all
// messageForTransferRestriction being returned
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC1404TokenMinKYCv13.sol";
import "./helpers/ERC1404_Base_Setup.sol";

contract ERC1404_Check_Transfer_Restrictions_Tests is ERC1404_Base_Setup {
    enum RestrictionCodes {
        NoTransferRestriction,
        MaxAllowedAddressReached,
        AllTransfersDisabledHoldingPeriodInProgress,
        ZeroTransferAmount,
        SenderNotWhitelistedOrBlocked,
        ReceiverNotWhitelistedOrBlocked,
        SenderTransferDisabledHoldingPeriodKYC,
        ReceiverTransferDisabledHoldingPeriodKYC
    }

    function setUp() public override {
        ERC1404_Base_Setup.setUp();
        token.modifyKYCData(addr1, 1, 1);
        token.modifyKYCData(addr2, 1, 1);
        token.modifyKYCData(addr3, 1, 1);
    }

    function test_Test_All_Restriction_Codes() public {
        assertEq(
            token.messageForTransferRestriction(0),
            "No transfer restrictions found"
        );
        assertEq(
            token.messageForTransferRestriction(1),
            "Max allowed addresses with non-zero restriction is in place, this transfer will exceed this limitation"
        );
        assertEq(
            token.messageForTransferRestriction(2),
            "All transfers are disabled because Holding Period is not yet expired"
        );
        assertEq(
            token.messageForTransferRestriction(3),
            "Zero transfer amount not allowed"
        );
        assertEq(
            token.messageForTransferRestriction(4),
            "Sender is not whitelisted or blocked"
        );
        assertEq(
            token.messageForTransferRestriction(5),
            "Receiver is not whitelisted or blocked"
        );
        assertEq(
            token.messageForTransferRestriction(6),
            "Sender is whitelisted but is not eligible to send tokens and under holding period (KYC time restriction)"
        );
        assertEq(
            token.messageForTransferRestriction(7),
            "Receiver is whitelisted but is not yet eligible to receive tokens in his wallet (KYC time restriction)"
        );
    }

    function test_No_transfer_restrictions_found(uint amount) public {
        vm.assume(amount > 0);
        assertEq(
            token.detectTransferRestriction(addr1, addr2, amount),
            uint(RestrictionCodes.NoTransferRestriction)
        );
    }

    function test_Max_Non_Zero_Addresses_Restriction(uint amount) public {
        amount = bound(amount, 2, initialSupply);
        token.resetAllowedInvestors(1);
        token.transfer(addr1, amount);
        assertEq(
            token.detectTransferRestriction(addr1, addr2, amount / 2),
            uint(RestrictionCodes.MaxAllowedAddressReached)
        );
    }

    function test_Transfer_Holding_Period_Investor_To_Investor(
        uint amount
    ) public {
        amount = bound(amount, 1, initialSupply);
        // Following transfer is possible because holding period is not yet set
        token.transfer(addr1, amount);
        // set holding period in future
        token.setTradingHoldingPeriod(EPOCHTimeInFuture);
        // all transfers are not possible
        assertEq(
            token.detectTransferRestriction(addr1, addr2, amount),
            uint(RestrictionCodes.AllTransfersDisabledHoldingPeriodInProgress)
        );
    }

    function test_Transfer_Holding_Period_Investor_To_Issuer(
        uint amount
    ) public {
        amount = bound(amount, 1, initialSupply);
        // Following transfer is possible because holding period is not yet set
        token.transfer(addr1, amount);
        // set holding period in future
        token.setTradingHoldingPeriod(EPOCHTimeInFuture);
        // but not from address to owner.
        assertEq(
            token.detectTransferRestriction(addr1, token.owner(), amount),
            uint(RestrictionCodes.AllTransfersDisabledHoldingPeriodInProgress)
        );
    }

    function test_Transfer_Holding_Period_Issuer_To_Investor(
        uint amount
    ) public {
        amount = bound(amount, 1, initialSupply);
        // set holding period in future
        token.setTradingHoldingPeriod(EPOCHTimeInFuture);
        // but transfer from owner to address is possible even under holding period
        assertEq(
            token.detectTransferRestriction(token.owner(), addr1, amount),
            uint(RestrictionCodes.NoTransferRestriction)
        );
    }

    function test_Zero_Transfer_Is_Not_Allowed() public {
        // this transfer is not possible
        assertEq(
            token.detectTransferRestriction(token.owner(), addr1, 0),
            uint(RestrictionCodes.ZeroTransferAmount)
        );
    }

    function test_Sender_Is_Blocked_Or_Not_Whitelisted(uint amount) public {
        amount = bound(amount, 1, initialSupply);
        token.transfer(addr1, amount);
        token.modifyKYCData(addr1, 0, 0);
        // and this transfer is not possible because sender is under send holding period
        assertEq(
            token.detectTransferRestriction(addr1, token.owner(), amount),
            uint(RestrictionCodes.SenderNotWhitelistedOrBlocked)
        );
    }

    function test_Receiver_Is_Blocked_Or_Not_Whitelisted(uint amount) public {
        amount = bound(amount, 1, initialSupply);
        //this transfer is not possible
        assertEq(
            token.detectTransferRestriction(token.owner(), addr4, amount),
            uint(RestrictionCodes.ReceiverNotWhitelistedOrBlocked)
        );
    }

    function test_Sender_Is_Blocked_or_Under_Holding_Period(
        uint amount
    ) public {
        amount = bound(amount, 1, initialSupply);
        token.modifyKYCData(addr1, 1, EPOCHTimeInFuture);
        token.transfer(addr1, amount);

        // and this transfer is not possible because sender is under send holding period
        assertEq(
            token.detectTransferRestriction(addr1, token.owner(), amount),
            uint(RestrictionCodes.SenderTransferDisabledHoldingPeriodKYC)
        );
    }

    function test_Receiver_Is_Blocked_or_Under_Holding_Period(
        uint amount
    ) public {
        amount = bound(amount, 1, initialSupply);
        token.modifyKYCData(addr2, EPOCHTimeInFuture, 1);
        token.transfer(addr1, amount);

        // and this transfer is not possible because receiver is under send holding period
        assertEq(
            token.detectTransferRestriction(addr1, addr2, amount),
            uint(RestrictionCodes.ReceiverTransferDisabledHoldingPeriodKYC)
        );
    }
}
