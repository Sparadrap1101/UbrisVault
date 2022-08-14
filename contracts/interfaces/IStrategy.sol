// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface IStrategy {
    function strategy() external; // Where the strategy structure is set.

    function enterStrategy(
        address tokenAddress,
        address userAddress,
        uint256 amount
    ) external payable; // Factory contract deposit user funds here.

    function exitStrategy() external; // Factory contract withdraw user funds here.

    function recolt() external; // Factory contract tell strategy to recolt yield here.

    function getTokenToDeposit() external view returns (address); // Return token address to deposit on strategy.
}
