// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
interface IHaifu {
    struct State {
        string name;
        string symbol;
        address creator;
        uint256 totalSupply;
        address haifu;
        address fundManager;
        uint256 deposit;
        uint256 goal;
        uint256 launchPrice;
        uint256 whitelistAmount;
        uint256 fundAcceptingExpiaryDate;
        uint256 fundExpiaryDate;
    }
}
