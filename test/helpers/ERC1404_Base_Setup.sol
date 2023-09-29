// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/ERC1404TokenMinKYCv13.sol";

contract ERC1404_Base_Setup is Test {
    address addr1 = 0x1a8929fbE9abEc00CDfCda8907408848cBeb5300;
    address addr2 = 0xAD3DF0f1c421002B8Eff81288146AF9bC692d13d;
    address addr3 = 0x8192706d699390D668710BD247886e3016D4672E;
    address addr4 = 0x6a44140c28629b1E20114122fb53101dB6953efC;

    ERC1404TokenMinKYCv13 token;
    string name = "TestToken";
    string symbol = "TKN";
    uint initialSupply = 10000;
    uint64 EPOCHTimeInFuture = 33239925995;
    uint64 allowedInvestors = 0;
    uint8 decimalsPlaces = 18;
    string shareCertificate = "share certificate link";
    string companyHomepage = "company homepage link";
    string companyLegalDocs = "company legal docs link";
    address atomicSwapContractAddress =
        0xE3C20D3089a7eF284b8Ab04bBEA0aaB8d50805b9;
    uint64 tradingHoldingPeriod = 1;

    function setUp() public virtual {
        token = new ERC1404TokenMinKYCv13(
            initialSupply,
            name,
            symbol,
            allowedInvestors,
            decimalsPlaces,
            shareCertificate,
            companyHomepage,
            companyLegalDocs,
            atomicSwapContractAddress,
            tradingHoldingPeriod
        );
    }
}
