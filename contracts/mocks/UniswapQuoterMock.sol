// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./UniswapMock.sol";

abstract contract UniswapQuoterMock is UniswapMock {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24,
        uint256 amountIn,
        uint160
    ) public view returns (uint256) {
        uint256 amountToMint;

        if (tokenIn == tokenOut) {
            amountToMint = amountIn;
        } else {
            amountToMint = amountIn * ratioSwap;
        }

        return amountToMint;
    }

    function quoteExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24,
        uint256 amountOut,
        uint160
    ) public view returns (uint256) {
        uint256 amountToBurn;

        if (tokenIn == tokenOut) {
            amountToBurn = amountOut;
        } else {
            amountToBurn = amountOut / ratioSwap;
        }

        return amountToBurn;
    }
}
