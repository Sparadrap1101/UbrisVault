// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Erc20Token} from "./Erc20Token.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract UniswapMock {
    Erc20Token public tokenA;
    Erc20Token public tokenB;
    uint256 public ratioSwap;

    error UniswapWrongAddress();
    error UniswapInsufficientBalance();
    error UniswapRatioZero();

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
            if (tokenA.balanceOf(msg.sender) < params.amountIn) {
                revert UniswapInsufficientBalance();
            }

            tokenA.burn(params.recipient, params.amountIn);
            tokenB.mint(params.recipient, amountToMint);
        } else if (params.tokenIn == address(tokenB)) {
            if (tokenB.balanceOf(msg.sender) < params.amountIn) {
                revert UniswapInsufficientBalance();
            }

            tokenB.burn(params.recipient, params.amountIn);
            tokenA.mint(params.recipient, amountToMint);
        } else {
            revert UniswapWrongAddress();
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
            if (tokenA.balanceOf(msg.sender) < amountToBurn) {
                revert UniswapInsufficientBalance();
            }

            tokenA.burn(params.recipient, amountToBurn);
            tokenB.mint(params.recipient, params.amountOut);
        } else if (params.tokenIn == address(tokenB)) {
            if (tokenB.balanceOf(msg.sender) < amountToBurn) {
                revert UniswapInsufficientBalance();
            }

            tokenB.burn(params.recipient, amountToBurn);
            tokenA.mint(params.recipient, params.amountOut);
        } else {
            revert UniswapWrongAddress();
        }

        return amountToBurn;
    }

    function modifyRatioSwap(uint256 _newRatioSwap) public {
        if (_newRatioSwap == 0) {
            revert UniswapRatioZero();
        }

        ratioSwap = _newRatioSwap;
    }

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
