// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Erc20Token} from "./Erc20Token.sol";
import {IPool, DataTypes} from "@aave/core-v3/contracts/interfaces/IPool.sol";

contract AaveMock {
    Erc20Token public tokenA;
    Erc20Token public tokenB;
    Erc20Token public aToken;
    Erc20Token public vToken;
    uint256 public ratio;

    mapping(address => uint256) public supplyAmounts;
    mapping(address => uint256) public borrowAmounts;

    error AaveWrongAddress();
    error AaveInsufficientBalance();

    constructor(
        address _tokenA,
        address _tokenB,
        address _aToken,
        address _vToken,
        uint256 _ratio
    ) {
        tokenA = Erc20Token(_tokenA);
        tokenB = Erc20Token(_tokenB);
        aToken = Erc20Token(_aToken);
        vToken = Erc20Token(_vToken);
        ratio = _ratio;
    }

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16
    ) public {
        if (asset != address(tokenA)) {
            revert AaveWrongAddress();
        }

        if (tokenA.balanceOf(onBehalfOf) < amount) {
            revert AaveInsufficientBalance();
        }

        supplyAmounts[onBehalfOf] += amount;
        tokenA.burn(onBehalfOf, amount);
        aToken.mint(onBehalfOf, amount);
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) public returns (uint256) {
        if (asset != address(tokenA)) {
            revert AaveWrongAddress();
        }

        if (supplyAmounts[msg.sender] < amount) {
            revert AaveInsufficientBalance();
        }

        supplyAmounts[msg.sender] -= amount;
        aToken.burn(msg.sender, amount);
        tokenA.mint(to, amount);

        return amount;
    }

    function borrow(
        address asset,
        uint256 amount,
        uint256,
        uint16,
        address onBehalfOf
    ) public {
        if (asset == address(tokenB)) {
            uint256 _amount = amount / ratio;

            if (supplyAmounts[onBehalfOf] < _amount) {
                revert AaveInsufficientBalance();
            }

            borrowAmounts[onBehalfOf] += amount;
            tokenB.mint(onBehalfOf, amount);
            vToken.mint(onBehalfOf, amount);
        } else if (asset == address(tokenA)) {
            if (supplyAmounts[onBehalfOf] < amount) {
                revert AaveInsufficientBalance();
            }

            borrowAmounts[onBehalfOf] += amount;
            tokenA.mint(onBehalfOf, amount);
            vToken.mint(onBehalfOf, amount);
        } else {
            revert AaveWrongAddress();
        }
    }

    function repay(
        address asset,
        uint256 amount,
        uint256,
        address onBehalfOf
    ) public returns (uint256) {
        if (asset != address(tokenB)) {
            revert AaveWrongAddress();
        }

        if (borrowAmounts[onBehalfOf] < amount) {
            revert AaveInsufficientBalance();
        }

        if (tokenB.balanceOf(msg.sender) < amount) {
            revert AaveInsufficientBalance();
        }

        borrowAmounts[onBehalfOf] -= amount;
        tokenB.burn(msg.sender, amount);
        vToken.burn(onBehalfOf, amount);

        return amount;
    }

    function repayWithATokens(
        address asset,
        uint256 amount,
        uint256
    ) public returns (uint256) {
        if (asset != address(tokenB)) {
            revert AaveWrongAddress();
        }

        uint256 _amount = amount * ratio;

        if (borrowAmounts[msg.sender] < _amount) {
            revert AaveInsufficientBalance();
        }

        if (supplyAmounts[msg.sender] < amount) {
            revert AaveInsufficientBalance();
        }

        supplyAmounts[msg.sender] -= amount;
        aToken.burn(msg.sender, amount);

        borrowAmounts[msg.sender] -= _amount;
        vToken.burn(msg.sender, _amount);

        return amount;
    }

    function getReserveData(address) public view returns (DataTypes.ReserveData memory) {
        DataTypes.ReserveConfigurationMap memory config;

        DataTypes.ReserveData memory params = DataTypes.ReserveData({
            configuration: config,
            liquidityIndex: 0,
            currentLiquidityRate: 0,
            variableBorrowIndex: 0,
            currentVariableBorrowRate: 0,
            currentStableBorrowRate: 0,
            lastUpdateTimestamp: 0,
            id: 0,
            aTokenAddress: address(aToken),
            stableDebtTokenAddress: address(vToken),
            variableDebtTokenAddress: address(vToken),
            interestRateStrategyAddress: address(0),
            accruedToTreasury: 0,
            unbacked: 0,
            isolationModeTotalDebt: 0
        });

        return params;
    }

    function getUserAccountData(address user)
        public
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        totalCollateralBase = supplyAmounts[user];
        totalDebtBase = borrowAmounts[user];
        availableBorrowsBase = totalCollateralBase - totalDebtBase;
        currentLiquidationThreshold = 1;
        ltv = 1;
        healthFactor = (totalCollateralBase * currentLiquidationThreshold) / totalDebtBase;

        return (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor);
    }

    function claimAllRewardsToSelf(address[] calldata)
        public
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        aToken.mint(msg.sender, 10);
        supplyAmounts[msg.sender] += 10;

        rewardsList = new address[](2);
        rewardsList[0] = address(aToken);
        rewardsList[1] = address(vToken);

        claimedAmounts = new uint256[](2);
        claimedAmounts[0] = 10;
        claimedAmounts[1] = 0;

        return (rewardsList, claimedAmounts);
    }
}
