// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "../src/DividendClaim.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "murky/Merkle.sol";
import {Global_Helpers} from "./helpers/Global_Helpers.sol";

contract DividendClaimTest is Test {
    DividendClaim public dividendClaim;
    Global_Helpers public helpers;
    Merkle merkleTree;
    ERC20 public token;
    bytes32[] data;
    bytes32 merkleRoot;

    uint[] amounts;
    address[] addresses;
    uint totalAmount;

    address alice = address(0x1);
    address bob = address(0x2);
    uint etherBalance = 1 ether;
    uint numberOfRecipients = 200;

    function setUp() public {
        token = new ERC20("USDCoin", "USDC");
        helpers = new Global_Helpers();
        merkleTree = new Merkle();

        // Creates users, amounts and total amount
        addresses = helpers.createUsers(numberOfRecipients);
        (amounts, totalAmount) = helpers.createAmounts(numberOfRecipients);

        // Generates merkle tree and creates merkle root
        data = new bytes32[](numberOfRecipients);
        for (uint i; i < numberOfRecipients; i++) {
            data[i] = keccak256(bytes.concat(keccak256(abi.encode(addresses[i], amounts[i]))));
        }
        merkleRoot = merkleTree.getRoot(data);

        // Adds Ether to balance
        deal(alice, etherBalance);
        deal(bob, etherBalance);

        // Adds USDC balance
        deal(address(token), alice, 1 ether);
        deal(address(token), address(this), 1 ether);

        // console.log("Alice:", ERC20(token).balanceOf(alice));
        // console.log("This contract:", ERC20(token).balanceOf(address(this)));
        // console.log("The totalAmount:", totalAmount);

        // Deploys Dividends contract as alice
        vm.prank(alice);
        dividendClaim = new DividendClaim(address(token), merkleRoot, totalAmount);

        // Adds USDC balance to Dividends contract for distribution
        deal(address(token), address(dividendClaim), totalAmount);
    }

    function test_totalAmount() public {
        assertEq(ERC20(token).balanceOf(address(dividendClaim)), totalAmount);
    }

    function test_ClaimDividends_Success_Scenario() public {
        vm.startPrank(addresses[0]);
        bytes32[] memory proof = merkleTree.getProof(data, 0);
        dividendClaim.claimDividend(proof, amounts[0]);
        assertEq(IERC20(token).balanceOf(addresses[0]), amounts[0]);
        vm.stopPrank();
    }

    function testFail_RepeatClaimDividends() public {
        vm.startPrank(addresses[0]);
        bytes32[] memory proof = merkleTree.getProof(data, 0);
        dividendClaim.claimDividend(proof, amounts[0]);
        dividendClaim.claimDividend(proof, amounts[0]);
        vm.stopPrank();
    }

    function test_ExpectRevert_RepeatClaimDividends() public {
        vm.startPrank(addresses[0]);
        bytes32[] memory proof = merkleTree.getProof(data, 0);
        dividendClaim.claimDividend(proof, amounts[0]);
        vm.expectRevert(DividendClaim.AlreadyClaimed.selector);
        dividendClaim.claimDividend(proof, amounts[0]);
        vm.stopPrank();
    }

    function testFail_ClaimDividends_withInvalidProof() public {
        vm.startPrank(addresses[1]);
        bytes32[] memory proof = merkleTree.getProof(data, 0);
        dividendClaim.claimDividend(proof, amounts[0]);
        vm.stopPrank();
    }

    function test_ExpectRevert_ClaimDividends_withInvalidProof() public {
        vm.startPrank(addresses[1]);
        bytes32[] memory proof = merkleTree.getProof(data, 0);
        vm.expectRevert(DividendClaim.InvalidProof.selector);
        dividendClaim.claimDividend(proof, amounts[0]);
        vm.stopPrank();
    }

    function test_ClaimDividends_isNotClaimed() public {
        assertEq(dividendClaim.isClaimed(addresses[0]), false);
    }

    function test_MurkyMerkleProof() public {
        bytes32[] memory proof = merkleTree.getProof(data, 0);
        bool verified = merkleTree.verifyProof(merkleRoot, proof, data[0]);
        assertTrue(verified);
    }

    function test_OpenZeppelinMerkleProof() public {
        bytes32[] memory proof = merkleTree.getProof(data, 0);

        bool ozVerified = MerkleProof.verify(proof, merkleRoot, data[0]);
        assertTrue(ozVerified);
    }

    function test_OpenZeppelinDeconstructedMerkleProof() public {
        bytes32[] memory proof = merkleTree.getProof(data, 0);
        bytes32 testData = keccak256(bytes.concat(keccak256(abi.encode(addresses[0], amounts[0]))));
        bool ozVerified = MerkleProof.verify(proof, merkleRoot, testData);
        assertTrue(ozVerified);
    }

    function test_Withdraw_Owner() public {
        vm.prank(alice);
        dividendClaim.withdraw();
    }

    function testFail_Withdraw_NotOwner() public {
        vm.prank(bob);
        dividendClaim.withdraw();
    }
}
