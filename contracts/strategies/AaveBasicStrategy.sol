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

    uint256 public strategyTest = 0;

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

    /// Internal functions ///

    function supplyOnAavePool(address tokenSupply, uint256 amount) internal {
        ERC20 token = ERC20(tokenSupply);
        token.approve(aaveAddress, amount);

        aave.supply(tokenSupply, amount, address(this), 0);
    }

    function withdrawFromAavePool(address tokenWithdraw, uint256 amount) internal {
        aave.withdraw(tokenWithdraw, amount, address(this));
    } // Vérifier qu'on passe pas le Health Factor sous 1 en faisant withdraw

    function borrowOnAave(
        address tokenBorrow,
        uint256 amountToBorrow,
        uint256 interestRateMode
    ) internal {
        aave.borrow(tokenBorrow, amountToBorrow, interestRateMode, 0, address(this));
    }

    function repayOnAave(
        address tokenRepay,
        uint256 amountToRepay,
        uint256 interestRateMode
    ) internal {
        ERC20 token = ERC20(tokenRepay);
        token.approve(aaveAddress, amountToRepay); // Plus tard p'tete approve à l'infini et check juste s'il reste de l'allowance.

        aave.repay(tokenRepay, amountToRepay, interestRateMode, address(this));
    }

    function repayWithATokenOnAave(
        address tokenRepay,
        uint256 amountToRepay,
        uint256 interestRateMode
    ) internal {
        aave.repayWithATokens(tokenRepay, amountToRepay, interestRateMode);
    }

    function swapOnUniswap(
        address tokenToSwap,
        address tokenToGet,
        uint256 amount,
        uint24 fees
    ) public returns (uint256) {
        ERC20 token = ERC20(tokenToSwap);
        token.approve(uniswapAddress, amount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenToSwap,
            tokenOut: tokenToGet,
            fee: fees,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        strategyTest = (amount * 9) / 10;

        uint256 amountOut = uniswap.exactInputSingle(params);

        return amountOut;
    }

    function withdraw(address _tokenAddress) public {
        ERC20 token = ERC20(_tokenAddress);

        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function strategy(uint256 amount) internal {
        supplyOnAavePool(tokenAddress, amount);

        uint256 amountToBorrow = (amount * 3) / 4;
        borrowOnAave(tokenToBorrow, amountToBorrow, 2); // InterestRateMode = 2 -> Variable (1 -> Stable)

        // Vérifier pcq j'ai pas forcément besoin de swap au final, surtout pour des stablecoins. on peut laisser le choix à la limite
        uint256 amountToSwap = (amountToBorrow * 4) / 5;
        uint256 amountOut = swapOnUniswap(tokenToBorrow, tokenAddress, amountToSwap, 3000); // Fees : 3000 = 0.3%

        supplyOnAavePool(tokenAddress, amountOut);
    } // Where the strategy structure is set. (Full path with some gas cost).

    function strategyGasLess(uint256 amount) internal {
        supplyOnAavePool(tokenAddress, amount);

        uint256 amountToBorrow = (amount * 3) / 4;
        borrowOnAave(tokenAddress, amountToBorrow, 2); // InterestRateMode = 2 -> Variable (1 -> Stable)

        supplyOnAavePool(tokenAddress, amountToBorrow);
    } // Strategy with same asset borrow as supplied (to avoid swaps, fees and use repayWithAToken())

    function exitAave(uint256 amount) internal {
        // Vérifier les montant avec des require (si le mec peut, si ça nique pas le health factor etc)
        withdrawFromAavePool(tokenAddress, amount);

        uint256 amountOut = swapOnUniswap(tokenAddress, tokenToBorrow, amount, 3000); // Fees : 3000 = 0.3%

        repayOnAave(tokenToBorrow, amountOut, 2);

        withdrawFromAavePool(tokenAddress, amountOut);
    }

    function exitAaveGasLess(uint256 amount) internal {
        repayWithATokenOnAave(tokenAddress, amount, 2);

        withdrawFromAavePool(tokenAddress, amount);
    }

    /// Public functions ///

    function enterStrategy(
        address _tokenAddress,
        address userAddress,
        uint256 amount,
        bool gasLessStrategy
    ) public payable {
        require(_tokenAddress == tokenAddress, "This token is not available in this strategy.");
        require(tokenAddress != address(0), "This address is not valid for ERC20 token.");
        ERC20 Erc20Token = ERC20(tokenAddress);
        Erc20Token.transferFrom(msg.sender, address(this), amount);
        s_userBalances[userAddress] += amount;

        if (gasLessStrategy == true) {
            strategyGasLess(amount);
        } else {
            strategy(amount);
        }
    } // Factory contract deposit user funds here.

    function exitStrategy(
        address userAddress,
        uint256 amount,
        bool gasLessStrategy
    ) public {
        require(s_userBalances[userAddress] >= amount, "You can't withdraw more than your wallet funds.");
        require(tokenAddress != address(0), "This address is not valid for ERC20 token.");
        ERC20 Erc20Token = ERC20(tokenAddress);
        Erc20Token.transfer(msg.sender, amount);
        s_userBalances[userAddress] -= amount;

        if (gasLessStrategy == true) {
            exitAaveGasLess(amount);
        } else {
            exitAave(amount);
        }

        // Vérifier les balances blabla et transferer sur le compte du gars dans factory.
    } // Factory contract withdraw user funds here.

    function recolt() public {
        strategyTest = 1;
    } // Factory contract tell strategy to recolt yield here.

    /// Set & Get functions ///

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

    function getStrategyBalance() public view returns (uint256) {
        return 0;
    }

    function verifyHealthFactor() public view returns (uint256) {
        return 0;
    }
}
