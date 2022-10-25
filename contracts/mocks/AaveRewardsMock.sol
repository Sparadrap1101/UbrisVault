// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./AaveMock.sol";

abstract contract AaveRewardsMock is AaveMock {
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
