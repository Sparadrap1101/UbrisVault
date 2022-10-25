// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./Erc20Token.sol";

contract ChainlinkMock {
    Erc20Token public token;
    uint256 private tokenValue;

    constructor(address _token, uint256 _tokenValue) {
        token = Erc20Token(_token);
        tokenValue = _tokenValue;
    }

    function latestRoundData() public view returns (uint256) {
        return tokenValue;
    }

    function modifyTokenValue(uint256 _newValue) public {
        require(_newValue != 0, "Fail from Chainlink: Can't set value to O.");

        tokenValue = _newValue;
    }
}