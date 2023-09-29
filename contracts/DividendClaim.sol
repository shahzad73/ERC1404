//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

contract DividendClaim is Ownable {
    using SafeERC20 for IERC20;

    address public immutable token;
    bytes32 public immutable merkleRoot;
    uint public totalAmount;
    mapping(address => bool) public isClaimed;

    error InvalidProof();
    error AlreadyClaimed();

    event DividendClaimed(
        address indexed dividendAddress,
        address indexed investor,
        uint indexed amount
    );

    constructor(address _token, bytes32 _merkleRoot, uint _totalAmount) {
        token = _token;
        merkleRoot = _merkleRoot;
        totalAmount = _totalAmount;
    }

    function claimDividend(
        bytes32[] calldata merkleProof,
        uint amount
    ) external {
        if (isClaimed[msg.sender]) {
            revert AlreadyClaimed();
        }
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(msg.sender, amount)))
        );
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert InvalidProof();
        }

        isClaimed[msg.sender] = true;
        IERC20(token).safeTransfer(msg.sender, amount);

        emit DividendClaimed(address(this), msg.sender, amount);
    }

    function withdraw() external onlyOwner {
        IERC20(token).safeTransfer(
            owner(),
            IERC20(token).balanceOf(address(this))
        );
    }
}

// Markle Trees background
// https://soliditydeveloper.com/merkle-tree