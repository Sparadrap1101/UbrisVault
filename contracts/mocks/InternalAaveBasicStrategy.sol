// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {AaveBasicStrategy} from "../strategies/AaveBasicStrategy.sol";

contract InternalAaveBasicStrategy is AaveBasicStrategy {
    constructor(
        address _tokenAddress,
        address _tokenToBorrow,
        address _aaveAddress,
        address _aaveRewardsAddress,
        address _uniswapAddress,
        uint24 _uniswapFees,
        address _chainlinkAddressTokenA,
        address _chainlinkAddressTokenB
    )
        AaveBasicStrategy(
            _tokenAddress,
            _tokenToBorrow,
            _aaveAddress,
            _aaveRewardsAddress,
            _uniswapAddress,
            _uniswapFees,
            _chainlinkAddressTokenA,
            _chainlinkAddressTokenB
        )
    {}

    function supplyOnAavePool(address tokenSupply, uint256 amount) public {
        _supplyOnAavePool(tokenSupply, amount);
    }

    function withdrawFromAavePool(address tokenWithdraw, uint256 amount) public {
        _withdrawFromAavePool(tokenWithdraw, amount);
    }

    function borrowOnAave(
        address tokenBorrow,
        uint256 amountToBorrow,
        uint256 interestRateMode
    ) public {
        _borrowOnAave(tokenBorrow, amountToBorrow, interestRateMode);
    }

    function repayOnAave(
        address tokenRepay,
        uint256 amountToRepay,
        uint256 interestRateMode
    ) public {
        _repayOnAave(tokenRepay, amountToRepay, interestRateMode);
    }

    function repayWithATokenOnAave(
        address tokenRepay,
        uint256 amountToRepay,
        uint256 interestRateMode
    ) public {
        _repayWithATokenOnAave(tokenRepay, amountToRepay, interestRateMode);
    }

    function swapOnUniswap(
        address tokenToSwap,
        address tokenToGet,
        uint256 amount,
        bool isInput
    ) public returns (uint256) {
        uint256 amountOut = _swapOnUniswap(tokenToSwap, tokenToGet, amount, isInput);

        return amountOut;
    }

    function chainlinkPriceFeed(bool isFromAtoB) public view returns (uint256) {
        uint256 priceToken = _chainlinkPriceFeed(isFromAtoB);

        return priceToken;
    }

    function strategy(uint256 amount) public {
        _strategy(amount);
    }

    function strategyGasLess(uint256 amount) public {
        _strategyGasLess(amount);
    }

    function exitAave(uint256 amount) public {
        _exitAave(amount);
    }

    function exitAaveGasLess(uint256 amount) public {
        _exitAaveGasLess(amount);
    }
}
