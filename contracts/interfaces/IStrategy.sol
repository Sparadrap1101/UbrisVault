// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IStrategy {
    function enterStrategy(
        address tokenAddress,
        address userAddress,
        uint256 amount
    ) external payable; // Factory contract deposit user funds here.

    function exitStrategy(address userAddress, uint256 amount) external; // Factory contract withdraw user funds here.

    function recolt() external; // Factory contract tell strategy to recolt yield here.

    function getTokenToDeposit() external view returns (address); // Return token address to deposit on strategy.

    function getUserBalance(address userAddress) external view returns (uint256); // Return user balance in the strategy.
}
