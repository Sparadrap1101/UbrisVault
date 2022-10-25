// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./Erc20Token.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract UniswapMock {
    Erc20Token public tokenA;
    Erc20Token public tokenB;
    uint256 public ratioSwap;

    constructor(
        address _tokenA,
        address _tokenB,
        uint256 _ratioSwap
    ) {
        tokenA = Erc20Token(_tokenA);
        tokenB = Erc20Token(_tokenB);
        ratioSwap = _ratioSwap;
    }

    function exactInputSingle(ISwapRouter.ExactInputSingleParams memory params) public returns (uint256) {
        uint256 amountToMint;

        if (params.tokenIn == params.tokenOut) {
            amountToMint = params.amountIn;
        } else {
            amountToMint = params.amountIn * ratioSwap;
        }

        if (params.tokenIn == address(tokenA)) {
            require(tokenA.balanceOf(msg.sender) >= params.amountIn, "Fail from Uniswap: Not enough amout for tokenIn.");

            tokenA.burn(params.recipient, params.amountIn);
            tokenB.mint(params.recipient, amountToMint);
        } else if (params.tokenIn == address(tokenB)) {
            require(tokenB.balanceOf(msg.sender) >= params.amountIn, "Fail from Uniswap: Not enough amout for tokenIn.");

            tokenB.burn(params.recipient, params.amountIn);
            tokenA.mint(params.recipient, amountToMint);
        } else {
            revert();
        }

        return amountToMint;
    }

    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams memory params) public returns (uint256) {
        uint256 amountToBurn;

        if (params.tokenIn == params.tokenOut) {
            amountToBurn = params.amountOut;
        } else {
            amountToBurn = params.amountOut / ratioSwap;
        }

        if (params.tokenIn == address(tokenA)) {
            require(tokenA.balanceOf(msg.sender) >= amountToBurn, "Fail from Uniswap: Not enough amout for tokenIn.");

            tokenA.burn(params.recipient, amountToBurn);
            tokenB.mint(params.recipient, params.amountOut);
        } else if (params.tokenIn == address(tokenB)) {
            require(tokenB.balanceOf(msg.sender) >= amountToBurn, "Fail from Uniswap: Not enough amout for tokenIn.");

            tokenB.burn(params.recipient, amountToBurn);
            tokenA.mint(params.recipient, params.amountOut);
        } else {
            revert();
        }

        return amountToBurn;
    }

    function modifyRatioSwap(uint256 _newRatioSwap) public {
        require(_newRatioSwap != 0);

        ratioSwap = _newRatioSwap;
    }
}
