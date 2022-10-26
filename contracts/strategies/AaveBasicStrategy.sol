// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPool, DataTypes} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IRewardsController} from "@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract AaveBasicStrategy is Ownable {
    address private immutable tokenAddress;
    address private immutable tokenToBorrow;
    bool private isSameToken;
    address private aTokenAddress;
    address private vTokenAddress;
    uint24 private uniswapFees;
    //bool private isChainlinkWorking;

    IPool private immutable aave;
    IRewardsController private immutable aaveRewards;
    ISwapRouter private immutable uniswap;
    //IQuoter private immutable uniswapQuoter;
    AggregatorV3Interface private immutable chainlinkTokenA;
    AggregatorV3Interface private immutable chainlinkTokenB;

    uint256 private immutable initialTokenPrice;
    uint256 private totalBalance;
    mapping(address => uint256) private userBalances;

    // Ajouter des events ?

    error WrongTokenStrategy();
    error InsufficientBalance();

    constructor(
        address _tokenAddress,
        address _tokenToBorrow,
        address _aaveAddress,
        address _aaveRewardsAddress,
        address _uniswapAddress,
        //address _uniswapQuoterAddress,
        uint24 _uniswapFees,
        address _chainlinkAddressTokenA,
        address _chainlinkAddressTokenB
    ) {
        tokenAddress = _tokenAddress;
        tokenToBorrow = _tokenToBorrow;

        if (tokenAddress == tokenToBorrow) {
            isSameToken = true;
        } else {
            isSameToken = false;
        }

        aave = IPool(_aaveAddress);
        aaveRewards = IRewardsController(_aaveRewardsAddress);
        uniswap = ISwapRouter(_uniswapAddress);
        //uniswapQuoter = IQuoter(_uniswapQuoterAddress);
        // Vérifier si je peux pas choper les fees de la pool direct avec un call sur uniswap.
        uniswapFees = _uniswapFees;
        chainlinkTokenA = AggregatorV3Interface(_chainlinkAddressTokenA);
        chainlinkTokenB = AggregatorV3Interface(_chainlinkAddressTokenB);
        /*
        try chainlinkTokenA.latestRoundData() {
            try chainlinkTokenB.latestRoundData() {
                isChainlinkWorking = true;
            } catch {
                isChainlinkWorking = false;
            }
        } catch {
            isChainlinkWorking = false;
        }*/

        uint256 initialPrice;

        if (isSameToken) {
            DataTypes.ReserveData memory outputs = aave.getReserveData(tokenAddress);
            aTokenAddress = outputs.aTokenAddress;
            vTokenAddress = outputs.variableDebtTokenAddress;

            initialPrice = 1;
        } else {
            DataTypes.ReserveData memory outputs1 = aave.getReserveData(tokenAddress);
            aTokenAddress = outputs1.aTokenAddress;

            DataTypes.ReserveData memory outputs2 = aave.getReserveData(tokenToBorrow);
            vTokenAddress = outputs2.variableDebtTokenAddress;

            //if (isChainlinkWorking) {
            initialPrice = _chainlinkPriceFeed(true); /*
            } else {
                initialPrice = _quoteWithUniswap(tokenAddress, tokenToBorrow, 1, true);
            }*/
        }

        initialTokenPrice = initialPrice;

        // Donner l'ownership au contrat factory et vérifier qu'il l'a bien avant d'add une stratégie ?
    }

    /// Internal functions ///

    function _supplyOnAavePool(address tokenSupply, uint256 amount) internal {
        ERC20 token = ERC20(tokenSupply);
        token.approve(address(aave), amount);

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
        token.approve(address(aave), amountToRepay); // Plus tard p'tete approve à l'infini et check juste s'il reste de l'allowance.

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
        bool isInput
    ) public returns (uint256) {
        uint256 amountOut;
        ERC20 token = ERC20(tokenToSwap);
        token.approve(address(uniswap), amount);

        if (isInput) {
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenToSwap,
                tokenOut: tokenToGet,
                fee: uniswapFees,
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
                fee: uniswapFees,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: amount,
                amountInMaximum: type(uint256).max,
                sqrtPriceLimitX96: 0
            });

            amountOut = uniswap.exactOutputSingle(params); // Swap with exact output and return input value
        }

        return amountOut;
    }

    // Non Gas efficient, should not be called on-chain
    /*function _quoteWithUniswap(
        address tokenToSwap,
        address tokenToGet,
        uint256 amount,
        bool isInput
    ) internal returns (uint256) {
        uint256 amountOutput;

        if (isInput) {
            amountOutput = uniswapQuoter.quoteExactInputSingle(tokenToSwap, tokenToGet, uniswapFees, amount, 0);
        } else {
            amountOutput = uniswapQuoter.quoteExactOutputSingle(tokenToSwap, tokenToGet, uniswapFees, amount, 0);
        }

        return amountOutput;
    }*/

    function _chainlinkPriceFeed(bool isFromAtoB) internal view returns (uint256) {
        uint256 priceToken;

        (, int256 tokenA, , , ) = chainlinkTokenA.latestRoundData();
        (, int256 tokenB, , , ) = chainlinkTokenB.latestRoundData();

        if (isFromAtoB) {
            priceToken = uint256(tokenA) / uint256(tokenB);
        } else {
            priceToken = uint256(tokenB) / uint256(tokenA);
        }

        return priceToken;
    }

    function withdraw(address _tokenAddress) public {
        // A supprimer à terme (sert pour les tests si jamais)
        ERC20 token = ERC20(_tokenAddress);

        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function _strategy(uint256 amount) internal {
        _supplyOnAavePool(tokenAddress, amount);

        // vérifier par rapport au Health Factor et tout si je peux bien borrow autant, vérifier d'autres require si besoin jsp
        uint256 amountToBorrow = (amount * 3) / 4;

        //if (isChainlinkWorking) {
        amountToBorrow = amountToBorrow * _chainlinkPriceFeed(true); /*
        } else {
            amountToBorrow = _quoteWithUniswap(tokenAddress, tokenToBorrow, amountToBorrow, true);
        }*/

        _borrowOnAave(tokenToBorrow, amountToBorrow, 2); // InterestRateMode : 2 -> Variable (1 -> Stable)

        uint256 amountOut = _swapOnUniswap(tokenToBorrow, tokenAddress, amountToBorrow, true);

        _supplyOnAavePool(tokenAddress, amountOut);
    } // Where the strategy structure is set. (Full path with some gas cost).

    function _strategyGasLess(uint256 amount) internal {
        _supplyOnAavePool(tokenAddress, amount);

        // vérifier par rapport au Health Factor et tout si je peux bien borrow autant, vérifier d'autres require si besoin jsp
        uint256 amountToBorrow = (amount * 3) / 4;

        //if (isChainlinkWorking) {
        amountToBorrow = amountToBorrow * _chainlinkPriceFeed(true); /*
        } else {
            amountToBorrow = _quoteWithUniswap(tokenAddress, tokenToBorrow, amountToBorrow, true);
        }*/

        _borrowOnAave(tokenAddress, amountToBorrow, 2); // InterestRateMode = 2 -> Variable (1 -> Stable)

        _supplyOnAavePool(tokenAddress, amountToBorrow);
    } // Strategy with same asset borrow as supplied (to avoid swaps, fees and use repayWithAToken())

    function _exitAave(uint256 amount) internal {
        // Vérifier les montant avec des require (si le mec peut, si ça nique pas le health factor etc)
        _withdrawFromAavePool(tokenAddress, amount);

        uint256 amountOut = _swapOnUniswap(tokenAddress, tokenToBorrow, amount, true);

        _repayOnAave(tokenToBorrow, amountOut, 2);

        _withdrawFromAavePool(tokenAddress, amountOut);
    }

    function _exitAaveGasLess(uint256 amount) internal {
        // Vérifier les montant avec des require (si le mec peut, si ça nique pas le health factor etc)
        _repayWithATokenOnAave(tokenToBorrow, amount, 2);

        _withdrawFromAavePool(tokenAddress, amount);
    }

    /// Public functions ///

    function enterStrategy(
        address _tokenAddress,
        address userAddress,
        uint256 amount
    ) public payable {
        if (_tokenAddress != tokenAddress) {
            revert WrongTokenStrategy();
        }
        // Vérifier l'Allowance et si j'ai bien les thunes

        uint256 newTokenPrice;

        if (isSameToken) {
            newTokenPrice = 1;
        } else {
            //if (isChainlinkWorking) {
            newTokenPrice = _chainlinkPriceFeed(true); /*
            } else {
                newTokenPrice = _quoteWithUniswap(tokenAddress, tokenToBorrow, 1, true);
            }*/
        }

        uint256 contractBalanceLogic = (initialTokenPrice * initialTokenPrice) / newTokenPrice;

        // Voir si y'a pas d'autres endroits importants pour mettre à jour la userBalance, genre par rapport à la récolte ou jsp quoi (pas sur)
        userBalances[userAddress] += contractBalanceLogic * amount;
        totalBalance += contractBalanceLogic * amount;

        ERC20 Erc20Token = ERC20(tokenAddress);
        Erc20Token.transferFrom(msg.sender, address(this), amount);

        if (isSameToken) {
            _strategyGasLess(amount);
        } else {
            _strategy(amount);
        }
    } // Factory contract deposit user funds here.

    function exitStrategy(address userAddress, uint256 amount) public {
        if (getUserBalance(userAddress) < amount) {
            revert InsufficientBalance();
        }

        uint256 newTokenPrice;

        if (isSameToken) {
            newTokenPrice = 1;
        } else {
            //if (isChainlinkWorking) {
            newTokenPrice = _chainlinkPriceFeed(true); /*
            } else {
                newTokenPrice = _quoteWithUniswap(tokenAddress, tokenToBorrow, 1, true);
            }*/
        }

        uint256 contractBalanceLogic = (initialTokenPrice * initialTokenPrice) / newTokenPrice;

        userBalances[userAddress] -= contractBalanceLogic * amount;
        totalBalance -= contractBalanceLogic * amount;

        if (isSameToken) {
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
    /*
    function swapChainlinkWorkingBool() public onlyOwner {
        isChainlinkWorking = !isChainlinkWorking;
    }

    function getChainlinkWorkingBool() public view returns (bool) {
        return isChainlinkWorking;
    }*/

    /*
    function setAaveAddress(address _aaveAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(_aaveAddress != address(0), "This address is not available");
        aave = IPool(_aaveAddress);
    }*/

    function getAaveAddress() public view returns (address) {
        return address(aave);
    }

    /*
    function setAaveRewardsAddress(address _aaveRewardsAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(_aaveRewardsAddress != address(0), "This address is not available");
        aaveRewards = IRewardsController(_aaveRewardsAddress);
    }*/

    function getAaveRewardsAddress() public view returns (address) {
        return address(aaveRewards);
    }

    /*
    function setUniswapAddress(address _uniswapAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(_uniswapAddress != address(0), "This address is not available");
        uniswap = ISwapRouter(_uniswapAddress);
    }*/

    function getUniswapAddress() public view returns (address) {
        return address(uniswap);
    }

    /*
    function setUniswapQuoterAddress(address _uniswapQuoterAddress) public onlyOwner {
        require(_uniswapQuoterAddress != address(0), "This address is not available");
        uniswapQuoter = IQuoter(_uniswapQuoterAddress);
    }

    function getUniswapQuoterAddress() public view returns (address) {
        return address(uniswapQuoter);
    }*/

    function setUniswapFees(uint24 _uniswapFees) public onlyOwner {
        uniswapFees = _uniswapFees;
    }

    function getUniswapFees() public view returns (uint24) {
        return uniswapFees;
    }

    /*
    function setChainlinkAddressTokenA(address _chainlinkAddressTokenA) public onlyOwner {
        require(_chainlinkAddressTokenA != address(0), "This address is not available");

        chainlinkTokenA = AggregatorV3Interface(_chainlinkAddressTokenA);

        try chainlinkTokenA.latestRoundData() {
            try chainlinkTokenB.latestRoundData() {
                isChainlinkWorking = true;
            } catch {
                isChainlinkWorking = false;
            }
        } catch {
            isChainlinkWorking = false;
        }
    }*/

    function getChainlinkAddressTokenA() public view returns (address) {
        return address(chainlinkTokenA);
    }

    /*
    function setChainlinkAddressTokenB(address _chainlinkAddressTokenB) public onlyOwner {
        require(_chainlinkAddressTokenB != address(0), "This address is not available");

        chainlinkTokenB = AggregatorV3Interface(_chainlinkAddressTokenB);

        try chainlinkTokenB.latestRoundData() {
            try chainlinkTokenA.latestRoundData() {
                isChainlinkWorking = true;
            } catch {
                isChainlinkWorking = false;
            }
        } catch {
            isChainlinkWorking = false;
        }
    }*/

    function getChainlinkAddressTokenB() public view returns (address) {
        return address(chainlinkTokenB);
    }

    /*
    // Potentielles failles si on change les tokens alors qu'y'a déjà eu des supply/borrow ?
    function setTokenToDeposit(address newTokenAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(newTokenAddress != address(0), "This address is not available");
        tokenAddress = newTokenAddress;

        DataTypes.ReserveData memory outputs = aave.getReserveData(tokenAddress);
        aTokenAddress = outputs.aTokenAddress;

        // Changer de token en cours de route ça peut amener pas mal de merde, déjà faudra changer le uniswapFees ou des trucs comme ça,
        // les balances vont être fucked up pcq ça suit le ratio des deux token initiaux, Chainlink faudra changer les adresses du proxy
        // etc... Un peu la merde, p'tete plus simple de pas les changer et juste les mettre les adresses des token au début et basta.
    }*/

    function getTokenToDeposit() public view returns (address) {
        return tokenAddress;
    } // Return token address to deposit on strategy.

    /*
    function setTokenToBorrow(address newTokenAddress) public onlyOwner {
        // Si l'owner est la factory, faire une fonction dedans qui permet de modifier les adresses
        // des tokens dans les stratégies si nécessaire.
        require(newTokenAddress != address(0), "This address is not available");
        tokenToBorrow = newTokenAddress;

        DataTypes.ReserveData memory outputs = aave.getReserveData(tokenToBorrow);
        vTokenAddress = outputs.variableDebtTokenAddress;

        // Idem qu'au dessus pour le fait de changer les tokens.
    }*/

    function getTokenToBorrow() public view returns (address) {
        return tokenToBorrow;
    } // Return token address to deposit on strategy.

    function getAToken() public view returns (address) {
        return aTokenAddress;
    }

    function getDebtToken() public view returns (address) {
        return vTokenAddress;
    }

    function getUserBalance(address userAddress) public view returns (uint256) {
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

    function getTotalStrategyBalance() public view returns (uint256) {
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

    function getPureStrategyBalanceOnAave() public view returns (uint256) {
        uint256 balance;
        uint256 aBalance;
        uint256 vBalance;
        // P'tete problème dans le calcul de la balance si certains tokens de dette sont gardé comme tels et pas re supply en aToken ?

        if (isSameToken) {
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
                //if (isChainlinkWorking) {
                realVBalance = vBalance / _chainlinkPriceFeed(false); /*
                } else {
                    realVBalance = _quoteWithUniswap(aTokenAddress, vTokenAddress, vBalance, false); // Why aTokenAddress là ? Pas sur qu'ils existent sur uniswap
                }*/
            }

            balance = aBalance - realVBalance;
        }

        return balance;
    } // Strategy pure balance on Aave (full aToken supply balance - vToken debt balance = real balance on Aave)
    /*
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
    } // Health Factor on Aave*/
}
