// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol";
//import "@aave/core-v3/contracts/protocol/tokenization/AToken.sol";
//import "@aave/core-v3/contracts/protocol/tokenization/VariableDebtToken.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

contract AaveBasicStrategy is Ownable {
    address private tokenAddress;
    address private tokenToBorrow;
    address private aTokenAddress;
    address private vTokenAddress;
    address private aaveAddress;
    address private aaveRewardsAddress;
    address private uniswapAddress;
    address private uniswapQuoterAddress;

    IPool aave;
    ISwapRouter uniswap;
    IQuoter uniswapQuoter;
    IRewardsController aaveRewards;

    uint256 private immutable initialTokenPrice;
    uint256 private totalBalance;
    mapping(address => uint256) private userBalances;

    // Ajouter des events ?

    constructor(
        address _tokenAddress,
        address _tokenToBorrow,
        address _aaveAddress,
        address _aaveRewardsAddress,
        address _uniswapAddress,
        address _uniswapQuoterAddress
    ) {
        tokenAddress = _tokenAddress;
        tokenToBorrow = _tokenToBorrow;
        aaveAddress = _aaveAddress;
        aave = IPool(_aaveAddress);
        aaveRewardsAddress = _aaveRewardsAddress;
        aaveRewards = IRewardsController(_aaveRewardsAddress);
        uniswapAddress = _uniswapAddress;
        uniswap = ISwapRouter(_uniswapAddress);
        uniswapQuoterAddress = _uniswapQuoterAddress;
        uniswapQuoter = IQuoter(_uniswapQuoterAddress);
        uint256 initialPrice;

        if (tokenAddress == tokenToBorrow) {
            DataTypes.ReserveData memory outputs = aave.getReserveData(tokenAddress);
            aTokenAddress = outputs.aTokenAddress;
            vTokenAddress = outputs.variableDebtTokenAddress;
            initialPrice = 1;
        } else {
            DataTypes.ReserveData memory outputs1 = aave.getReserveData(tokenAddress);
            aTokenAddress = outputs1.aTokenAddress;

            DataTypes.ReserveData memory outputs2 = aave.getReserveData(tokenToBorrow);
            vTokenAddress = outputs2.variableDebtTokenAddress;

            // P'tete pas mettre le 3000 de fees en dur mais soit le mettre dans le constructeur, soit voir si y'a pas une fonction Uniswap qui
            // permet de le connaitre a partir des deux tokens à swap.
            initialPrice = uniswapQuoter.quoteExactInputSingle(tokenAddress, tokenToBorrow, 3000, 1, 0);
        }

        initialTokenPrice = initialPrice;

        // Donner l'ownership au contrat factory et vérifier qu'il l'a bien avant d'add une stratégie ?
    }

    /// Internal functions ///

    function _supplyOnAavePool(address tokenSupply, uint256 amount) internal {
        ERC20 token = ERC20(tokenSupply);
        token.approve(aaveAddress, amount);

        aave.supply(tokenSupply, amount, address(this), 0);
    }

    function _withdrawFromAavePool(address tokenWithdraw, uint256 amount) internal {
        aave.withdraw(tokenWithdraw, amount, address(this));
    } // Vérifier qu'on passe pas le Health Factor sous 1 en faisant withdraw

    function _borrowOnAave(
        address tokenBorrow,
        uint256 amountToBorrow,
        uint256 interestRateMode
    ) internal {
        aave.borrow(tokenBorrow, amountToBorrow, interestRateMode, 0, address(this));
    }

    function _repayOnAave(
        address tokenRepay,
        uint256 amountToRepay,
        uint256 interestRateMode
    ) internal {
        ERC20 token = ERC20(tokenRepay);
        token.approve(aaveAddress, amountToRepay); // Plus tard p'tete approve à l'infini et check juste s'il reste de l'allowance.

        aave.repay(tokenRepay, amountToRepay, interestRateMode, address(this));
    }

    function _repayWithATokenOnAave(
        address tokenRepay,
        uint256 amountToRepay,
        uint256 interestRateMode
    ) internal {
        aave.repayWithATokens(tokenRepay, amountToRepay, interestRateMode);
    }

    function _swapOnUniswap(
        address tokenToSwap,
        address tokenToGet,
        uint256 amount,
        uint24 fees,
        bool isInput
    ) public returns (uint256) {
        uint256 amountOut;
        ERC20 token = ERC20(tokenToSwap);
        token.approve(uniswapAddress, amount);

        if (isInput) {
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

            amountOut = uniswap.exactInputSingle(params); // Swap with exact input and return output value
        } else {
            ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
                tokenIn: tokenToSwap,
                tokenOut: tokenToGet,
                fee: fees,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: amount,
                amountInMaximum: amount * 2, // P'tete mettre un uint(max) ou qqc comme ça si y'a gros gap entre les deux cours ?
                sqrtPriceLimitX96: 0
            });

            amountOut = uniswap.exactOutputSingle(params); // Swap with exact output and return input value
        }

        return amountOut;
    }

    // Non Gas efficient, should not be called on-chain
    // I use this for now but maybe use Chainlink in the future for price feed or something like that
    function _quoteWithUniswap(
        address tokenToSwap,
        address tokenToGet,
        uint256 amount,
        uint24 fees,
        bool isInput
    ) internal returns (uint256) {
        uint256 amountOutput;

        if (tokenAddress == tokenToBorrow) {
            amountOutput = 1;
        } else {
            if (isInput) {
                amountOutput = uniswapQuoter.quoteExactInputSingle(tokenToSwap, tokenToGet, fees, amount, 0);
            } else {
                amountOutput = uniswapQuoter.quoteExactOutputSingle(tokenToSwap, tokenToGet, fees, amount, 0);
            }
        }

        return amountOutput;
    }

    function withdraw(address _tokenAddress) public {
        ERC20 token = ERC20(_tokenAddress);

        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function _strategy(uint256 amount) internal {
        _supplyOnAavePool(tokenAddress, amount);

        uint256 amountToBorrow = (amount * 3) / 4; // C'est de la merde ça, faut voir le rapport entre les deux token avec QuoteUniswap ou Chainlink
        _borrowOnAave(tokenToBorrow, amountToBorrow, 2); // InterestRateMode : 2 -> Variable (1 -> Stable)

        // Pareil, peut être faire une variable fee globale à partir du constructeur ou uniswap.
        uint256 amountOut = _swapOnUniswap(tokenToBorrow, tokenAddress, amountToBorrow, 3000, true); // Fees : 3000 = 0.3%

        _supplyOnAavePool(tokenAddress, amountOut);
    } // Where the strategy structure is set. (Full path with some gas cost).

    function _strategyGasLess(uint256 amount) internal {
        _supplyOnAavePool(tokenAddress, amount);

        uint256 amountToBorrow = (amount * 3) / 4;
        _borrowOnAave(tokenAddress, amountToBorrow, 2); // InterestRateMode = 2 -> Variable (1 -> Stable)

        _supplyOnAavePool(tokenAddress, amountToBorrow);
    } // Strategy with same asset borrow as supplied (to avoid swaps, fees and use repayWithAToken())

    function _exitAave(uint256 amount) internal {
        // Vérifier les montant avec des require (si le mec peut, si ça nique pas le health factor etc)
        _withdrawFromAavePool(tokenAddress, amount);

        uint256 amountOut = _swapOnUniswap(tokenAddress, tokenToBorrow, amount, 3000, true); // Fees : 3000 = 0.3%

        _repayOnAave(tokenToBorrow, amountOut, 2);

        _withdrawFromAavePool(tokenAddress, amountOut);
    }

    function _exitAaveGasLess(uint256 amount) internal {
        _repayWithATokenOnAave(tokenAddress, amount, 2);

        _withdrawFromAavePool(tokenAddress, amount);
    }

    /// Public functions ///

    function enterStrategy(
        address _tokenAddress,
        address userAddress,
        uint256 amount
    ) public payable {
        require(_tokenAddress == tokenAddress, "This token is not available in this strategy.");
        require(tokenAddress != address(0), "This address is not valid for ERC20 token.");
        // Vérifier l'Allowance et si j'ai bien les thunes

        // Use Chainlink prices instead ?
        uint256 newTokenPrice = _quoteWithUniswap(tokenAddress, tokenToBorrow, 1, 3000, true);
        uint256 contractBalanceLogic = (initialTokenPrice * initialTokenPrice) / newTokenPrice;

        userBalances[userAddress] += contractBalanceLogic * amount;
        totalBalance += contractBalanceLogic * amount;

        ERC20 Erc20Token = ERC20(tokenAddress);
        Erc20Token.transferFrom(msg.sender, address(this), amount);

        if (tokenAddress == tokenToBorrow) {
            _strategyGasLess(amount);
        } else {
            _strategy(amount);
        }
    } // Factory contract deposit user funds here.

    function exitStrategy(address userAddress, uint256 amount) public {
        require(getUserBalance(userAddress) >= amount, "You can't withdraw more than your wallet funds.");

        uint256 newTokenPrice = _quoteWithUniswap(tokenAddress, tokenToBorrow, 1, 3000, true);
        uint256 contractBalanceLogic = (initialTokenPrice * initialTokenPrice) / newTokenPrice;

        userBalances[userAddress] -= contractBalanceLogic * amount;
        totalBalance -= contractBalanceLogic * amount;

        if (tokenAddress == tokenToBorrow) {
            _exitAaveGasLess(amount);
        } else {
            _exitAave(amount);
        }

        ERC20 Erc20Token = ERC20(tokenAddress);
        Erc20Token.transfer(msg.sender, amount);

        // Vérifier les balances blabla et transferer sur le compte du gars dans factory.
    } // Factory contract withdraw user funds here.

    function recolt() public {
        address[] memory tempArray = new address[](2);
        tempArray[0] = aTokenAddress;
        tempArray[1] = vTokenAddress;

        // (address[] memory rewardsList, uint256[] memory claimedAmounts) = aaveRewards.claimAllRewardsToSelf(tempArray);
        aaveRewards.claimAllRewardsToSelf(tempArray);
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

    function setAaveRewardsAddress(address _aaveRewardsAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(_aaveRewardsAddress != address(0), "This address is not available");
        aaveRewardsAddress = _aaveRewardsAddress;
        aaveRewards = IRewardsController(_aaveRewardsAddress);
    }

    function getAaveRewardsAddress() public view returns (address) {
        return aaveRewardsAddress;
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

    function setUniswapQuoterAddress(address _uniswapQuoterAddress) public onlyOwner {
        require(_uniswapQuoterAddress != address(0), "This address is not available");
        uniswapQuoterAddress = _uniswapQuoterAddress;
        uniswapQuoter = IQuoter(_uniswapQuoterAddress);
    }

    function getUniswapQuoterAddress() public view returns (address) {
        return uniswapQuoterAddress;
    }

    // Potentielles failles si on change les tokens alors qu'y'a déjà eu des supply/borrow ?
    function setTokenToDeposit(address newTokenAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(newTokenAddress != address(0), "This address is not available");
        tokenAddress = newTokenAddress;

        DataTypes.ReserveData memory outputs = aave.getReserveData(tokenAddress);
        aTokenAddress = outputs.aTokenAddress;
    }

    function getTokenToDeposit() public view returns (address) {
        return tokenAddress;
    } // Return token address to deposit on strategy.

    function setTokenToBorrow(address newTokenAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(newTokenAddress != address(0), "This address is not available");
        tokenToBorrow = newTokenAddress;

        DataTypes.ReserveData memory outputs = aave.getReserveData(tokenToBorrow);
        vTokenAddress = outputs.variableDebtTokenAddress;
    }

    function getTokenToBorrow() public view returns (address) {
        return tokenToBorrow;
    } // Return token address to deposit on strategy.

    function getAToken() public view returns (address) {
        return aTokenAddress;
    }

    function getDebtToken() public view returns (address) {
        return vTokenAddress;
    }

    function getUserBalance(address userAddress) public returns (uint256) {
        uint256 userCurrentBalance;

        if (userBalances[userAddress] == 0) {
            userCurrentBalance = 0;
        } else {
            uint256 userRatio = userBalances[userAddress] / totalBalance;
            uint256 totalBalanceStrategy = getTotalStrategyBalance();

            userCurrentBalance = totalBalanceStrategy * userRatio;
        }

        return userCurrentBalance;
    } // Return user total balance in this strategy.

    function getTotalStrategyBalance() public returns (uint256) {
        uint256 balance = getPureStrategyBalanceOnAave() + getStrategyBalanceOutOfAave();

        return balance;
    } // Total strategy balance of the main token

    function getStrategyBalanceOutOfAave() public view returns (uint256) {
        ERC20 token = ERC20(tokenAddress);

        return token.balanceOf(address(this));
    } // Strategy balance of a token out of Aave

    function getStrategyATokenBalance() public view returns (uint256) {
        ERC20 aToken = ERC20(aTokenAddress);

        return aToken.balanceOf(address(this));
    } // Strategy balance of all aTokens on Aave

    function getStrategyDebtTokenBalance() public view returns (uint256) {
        ERC20 vToken = ERC20(vTokenAddress);

        return vToken.balanceOf(address(this));
    } // Strategy balance of all vToken on Aave (Debt of the strategy)

    function getPureStrategyBalanceOnAave() public returns (uint256) {
        uint256 balance;
        uint256 aBalance;
        uint256 vBalance;
        // P'tete problème dans le calcul de la balance si certains tokens de dette sont gardé comme tels et pas re supply en aToken ?

        if (tokenAddress == tokenToBorrow) {
            // Again potentielle faille si on change les addresses après coup ?
            aBalance = getStrategyATokenBalance();
            vBalance = getStrategyDebtTokenBalance();

            balance = aBalance - vBalance;
        } else {
            aBalance = getStrategyATokenBalance();
            vBalance = getStrategyDebtTokenBalance();
            uint256 realVBalance;

            if (vBalance == 0) {
                realVBalance = 0;
            } else {
                realVBalance = _quoteWithUniswap(aTokenAddress, vTokenAddress, vBalance, 3000, false);
            }

            balance = aBalance - realVBalance;
        }

        return balance;
    } // Strategy pure balance on Aave (full aToken supply balance - vToken debt balance = real balance on Aave)

    uint256 public calculatedHealthFactor;
    uint256 public healthFactor;
    uint256 public _totalCollateralBase;
    uint256 public _totalDebtBase;
    uint256 public _availableBorrowsBase;
    uint256 public _currentLiquidationThreshold;
    uint256 public futureHealthFactor;

    function getHealthFactor(uint256 addToBorrow)
        public
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        // Mettre un require si rien n'est borrow ?
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            ,
            uint256 health_factor
        ) = aave.getUserAccountData(address(this));

        healthFactor = health_factor;
        calculatedHealthFactor = (totalCollateralBase * currentLiquidationThreshold) / totalDebtBase;
        futureHealthFactor = 0;
        _totalCollateralBase = totalCollateralBase;
        _totalDebtBase = totalDebtBase;
        _availableBorrowsBase = availableBorrowsBase;
        _currentLiquidationThreshold = currentLiquidationThreshold;

        if (calculatedHealthFactor == health_factor) {
            futureHealthFactor = (totalCollateralBase * currentLiquidationThreshold) / (totalDebtBase + addToBorrow);
        }

        return (health_factor, availableBorrowsBase, futureHealthFactor);
    } // Health Factor on Aave
}
