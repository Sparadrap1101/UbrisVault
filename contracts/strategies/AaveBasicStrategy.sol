// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPoolAave.sol";

contract AaveBasicStrategy is Ownable {
    address private token;
    address private aaveAddress;
    IPool aave;

    // Plus judicieux de mettre un % qu'un amount fixe pour la balance car elle sera amené à pas mal bouger
    // Peut être un ERC20 comme font Yearn etc avec les yToken (check comment ils font exactement).
    mapping(address => uint256) private s_userBalances;

    string public strategyTest = "Not called yet.";

    // Ajouter des events ?

    constructor(address _token, address _aaveAddress) {
        token = _token;
        aaveAddress = _aaveAddress;
        aave = IPool(_aaveAddress);
        // Donner l'ownership au contrat factory et vérifier qu'il l'a bien avant d'add une stratégie ?
    }

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

    function setAaveAddress(address _aaveAddress) public onlyOwner {
        require(_aaveAddress != address(0), "This address is not available");
        aaveAddress = _aaveAddress;
        aave = IPool(_aaveAddress);
    }

    function getAaveAddress() public view returns (address) {
        return aaveAddress;
    }

    function setTokenToDeposit(address newTokenAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
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
