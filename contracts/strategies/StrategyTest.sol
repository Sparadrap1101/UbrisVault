// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StrategyTest {
    address private token;

    mapping(address => uint256) private s_userBalances;

    string public strategyTest = "Not called yet.";

    function strategy() internal {
        strategyTest = "Success";
    } // Where the strategy structure is set.

    function enterStrategy(
        address tokenAddress,
        address userAddress,
        uint256 amount
    ) public payable {
        require(tokenAddress == token, "This token is not available in this strategy.");
        require(token != address(0), "This address is not valid for ERC20 token.");
        ERC20 Erc20Token = ERC20(token);
        Erc20Token.transferFrom(msg.sender, address(this), amount);
        s_userBalances[userAddress] += amount;

        strategy();
    } // Factory contract deposit user funds here.

    function exitStrategy(address userAddress, uint256 amount) public {
        require(s_userBalances[userAddress] >= amount, "You can't withdraw more than your wallet funds.");
        require(token != address(0), "This address is not valid for ERC20 token.");
        ERC20 Erc20Token = ERC20(token);
        Erc20Token.transfer(msg.sender, amount);
        s_userBalances[userAddress] -= amount;
    } // Factory contract withdraw user funds here.

    function recolt() public {
        strategyTest = "Recolted.";
    } // Factory contract tell strategy to recolt yield here.

    function setTokenToDeposit(address newTokenAddress) public {
        // OnlyOwner()
        require(newTokenAddress != address(0), "This address is not available");
        token = newTokenAddress;
    }

    function getTokenToDeposit() public view returns (address) {
        return token;
    } // Return token address to deposit on strategy.

    function getUserBalance(address userAddress) public view returns (uint256) {
        return s_userBalances[userAddress];
    } // Return user balance in the strategy.
}
