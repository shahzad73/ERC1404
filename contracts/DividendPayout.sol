//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract DividendPayout {
    using SafeERC20 for IERC20;

    error InsufficientTotalAmount();
    error ZeroAmount();

    event Payout(address indexed sender, address indexed recipient, uint indexed amount);

    function bulkTransferDividends(
        IERC20 token,
        address[] memory recipients,
        uint[] memory amounts,
        uint totalAmount
    ) external {
        require(recipients.length > 0 && amounts.length > 0, "Length of arrays should be more than zero");
        require(recipients.length == amounts.length, "Arrays must be of the same length");
        require(recipients.length < 201, "Number of recipients must be under or equal to 200");
        require(token.balanceOf(msg.sender) >= totalAmount, "The sender has insufficient balance");
        require(totalAmount > 0, "Total amount should be more than 0");

        uint prevAmount;
        for (uint i; i < recipients.length; i++) {
            if (prevAmount + amounts[i] > totalAmount) {
                revert InsufficientTotalAmount();
            }
            if (amounts[i] < 1) {
                revert ZeroAmount();
            }

            prevAmount += amounts[i];
            token.safeTransferFrom(msg.sender, recipients[i], amounts[i]);
            emit Payout(msg.sender, recipients[i], amounts[i]);
        }
    }
}
