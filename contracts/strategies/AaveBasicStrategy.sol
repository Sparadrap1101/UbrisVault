// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPoolAave.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract AaveBasicStrategy is Ownable {
    address private tokenAddress;
    address private tokenToBorrow;
    address private aaveAddress;
    address private uniswapAddress;
    IPool aave;
    ISwapRouter uniswap;

    // Plus judicieux de mettre un % qu'un amount fixe pour la balance car elle sera amené à pas mal bouger
    // Peut être un ERC20 comme font Yearn etc avec les yToken (check comment ils font exactement).
    mapping(address => uint256) private s_userBalances;

    string public strategyTest = "Not called yet.";

    // Ajouter des events ?

    constructor(
        address _tokenAddress,
        address _tokenToBorrow,
        address _aaveAddress,
        address _uniswapAddress
    ) {
        tokenAddress = _tokenAddress;
        tokenToBorrow = _tokenToBorrow;
        aaveAddress = _aaveAddress;
        aave = IPool(_aaveAddress);
        uniswapAddress = _uniswapAddress;
        uniswap = ISwapRouter(_uniswapAddress);
        // Donner l'ownership au contrat factory et vérifier qu'il l'a bien avant d'add une stratégie ?
    }

    function test(uint256 amount) public {
        strategyTest = "1";
        ERC20 token = ERC20(tokenAddress);
        strategyTest = "2";
        token.approve(uniswapAddress, amount);
        strategyTest = "3";

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenAddress,
            tokenOut: tokenToBorrow,
            fee: 3000,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        strategyTest = "4";

        uniswap.exactInputSingle(params);
        strategyTest = "5";
    }

    function supplyOnAavePool(uint256 amount) internal {
        ERC20 token = ERC20(tokenAddress);
        token.approve(aaveAddress, amount);

        aave.supply(tokenAddress, amount, address(this), 0);
    }

    function withdrawFromAavePool(uint256 amount) internal {
        aave.withdraw(tokenAddress, amount, address(this));
    }

    function borrowOnAave(uint256 amountToBorrow, uint256 interestRateMode) internal {
        aave.borrow(tokenToBorrow, amountToBorrow, interestRateMode, 0, address(this));
    }

    function strategy(uint256 amount) internal {
        supplyOnAavePool(amount);

        uint256 amountToBorrow = (amount * 3) / 4;
        borrowOnAave(amountToBorrow, 2); // InterestRateMode = 2 -> Variable (1 -> Stable)
    } // Where the strategy structure is set.

    function enterStrategy(
        address _tokenAddress,
        address userAddress,
        uint256 amount
    ) public payable {
        require(_tokenAddress == tokenAddress, "This token is not available in this strategy.");
        require(tokenAddress != address(0), "This address is not valid for ERC20 token.");
        ERC20 Erc20Token = ERC20(tokenAddress);
        Erc20Token.transferFrom(msg.sender, address(this), amount);
        s_userBalances[userAddress] += amount;

        // strategy(amount);
    } // Factory contract deposit user funds here.

    function exitStrategy(address userAddress, uint256 amount) public {
        require(s_userBalances[userAddress] >= amount, "You can't withdraw more than your wallet funds.");
        require(tokenAddress != address(0), "This address is not valid for ERC20 token.");
        ERC20 Erc20Token = ERC20(tokenAddress);
        Erc20Token.transfer(msg.sender, amount);
        s_userBalances[userAddress] -= amount;
    } // Factory contract withdraw user funds here.

    function recolt() public {
        strategyTest = "Recolted.";
    } // Factory contract tell strategy to recolt yield here.

    function setAaveAddress(address _aaveAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(_aaveAddress != address(0), "This address is not available");
        aaveAddress = _aaveAddress;
        aave = IPool(_aaveAddress);
    }

    function getAaveAddress() public view returns (address) {
        return aaveAddress;
    }

    function setUniswapAddress(address _uniswapAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(_uniswapAddress != address(0), "This address is not available");
        uniswapAddress = _uniswapAddress;
        uniswap = ISwapRouter(_uniswapAddress);
    }

    function getUniswapAddress() public view returns (address) {
        return uniswapAddress;
    }

    function setTokenToDeposit(address newTokenAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(newTokenAddress != address(0), "This address is not available");
        tokenAddress = newTokenAddress;
    }

    function getTokenToDeposit() public view returns (address) {
        return tokenAddress;
    } // Return token address to deposit on strategy.

    function setTokenToBorrow(address newTokenAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(newTokenAddress != address(0), "This address is not available");
        tokenToBorrow = newTokenAddress;
    }

    function getTokenToBorrow() public view returns (address) {
        return tokenToBorrow;
    } // Return token address to deposit on strategy.

    function getUserBalance(address userAddress) public view returns (uint256) {
        return s_userBalances[userAddress];
    } // Return user balance in the strategy.
}
