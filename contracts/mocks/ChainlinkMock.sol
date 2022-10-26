// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Erc20Token} from "./Erc20Token.sol";

contract ChainlinkMock {
    Erc20Token public token;
    int256 private tokenValue;

    constructor(address _token, int256 _tokenValue) {
        token = Erc20Token(_token);
        tokenValue = _tokenValue;
    }

    function latestRoundData()
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, tokenValue, 0, 0, 0);
    }

    function modifyTokenValue(int256 _newValue) public {
        tokenValue = _newValue;
    }
}
