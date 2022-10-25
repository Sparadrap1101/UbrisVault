// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./Erc20Token.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";

contract AaveMock {
    Erc20Token public tokenA;
    Erc20Token public tokenB;
    Erc20Token public aToken;
    Erc20Token public vToken;

    mapping(address => uint256) public supplyAmounts;
    mapping(address => uint256) public borrowAmounts;

    constructor(
        address _tokenA,
        address _tokenB,
        address _aToken,
        address _vToken
    ) {
        tokenA = Erc20Token(_tokenA);
        tokenB = Erc20Token(_tokenB);
        aToken = Erc20Token(_aToken);
        vToken = Erc20Token(_vToken);
    }

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16
    ) public {
        require(asset == address(tokenA), "Fail from Aave: Wrong asset address.");
        require(amount > 0, "Fail from Aave: Can't supply anything.");
        require(tokenA.balanceOf(onBehalfOf) >= amount, "Fail from Aave: Don't have enough funds to supply.");

        supplyAmounts[onBehalfOf] += amount;
        tokenA.burn(onBehalfOf, amount);
        aToken.mint(onBehalfOf, amount);
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) public returns (uint256) {
        require(asset == address(tokenA), "Fail from Aave: Wrong asset address.");
        require(amount > 0, "Fail from Aave: Can't withdraw anything.");
        require(aToken.balanceOf(msg.sender) >= amount, "Fail from Aave: Don't have enough aToken to withdraw.");
        require(supplyAmounts[msg.sender] >= amount, "Fail from Aave: Don't have enough funds to withdraw.");

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
        require(asset == address(tokenB), "Fail from Aave: Wrong asset address.");
        require(amount > 0, "Fail from Aave: Can't borrow anything.");
        require(aToken.balanceOf(onBehalfOf) >= amount, "Fail from Aave: Don't have enough collateral to borrow.");

        borrowAmounts[onBehalfOf] += amount;
        tokenB.mint(onBehalfOf, amount);
        vToken.mint(onBehalfOf, amount);
    }

    function repay(
        address asset,
        uint256 amount,
        uint256,
        address onBehalfOf
    ) public returns (uint256) {
        require(asset == address(tokenB), "Fail from Aave: Wrong asset address.");
        require(amount > 0, "Fail from Aave: Can't repay anything.");
        require(vToken.balanceOf(onBehalfOf) >= amount, "Fail from Aave: Don't have enough vToken to repay.");
        require(tokenB.balanceOf(msg.sender) >= amount, "Fail from Aave: Don't have enough tokenB to repay.");
        require(borrowAmounts[msg.sender] >= amount, "Fail from Aave: Don't have enough debt to repay.");

        borrowAmounts[msg.sender] -= amount;
        tokenB.burn(msg.sender, amount);
        vToken.burn(onBehalfOf, amount);

        return amount;
    }

    function repayWithATokens(
        address asset,
        uint256 amount,
        uint256
    ) public returns (uint256) {
        require(asset == address(tokenB), "Fail from Aave: Wrong asset address.");
        require(amount > 0, "Fail from Aave: Can't repay anything.");
        require(vToken.balanceOf(msg.sender) >= amount, "Fail from Aave: Don't have enough vToken to repay.");
        require(borrowAmounts[msg.sender] >= amount, "Fail from Aave: Don't have enough debt to repay.");
        require(aToken.balanceOf(msg.sender) >= amount, "Fail from Aave: Don't have enough aToken to repay.");
        require(supplyAmounts[msg.sender] >= amount, "Fail from Aave: Don't have enough funds to repay.");

        supplyAmounts[msg.sender] -= amount;
        aToken.burn(msg.sender, amount);

        borrowAmounts[msg.sender] -= amount;
        vToken.burn(msg.sender, amount);

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
}
