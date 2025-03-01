// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IHaifu {
    struct Config {
        uint256 totalSupply;
        address fundManager;
        uint256 carry;
        address deposit;
        uint256 depositPrice;
        uint256 goal;
        uint256 haifuPrice;
        uint256 haifuGoal;
        uint256 fundAcceptingExpiaryDate;
        uint256 fundExpiaryDate;
    }

    struct State {
        uint256 totalSupply;
        // carry in fraction of 1e8
        uint256 carry;
        address fundManager;
        address deposit;
        // {wAIfu token} / {deposit token}
        uint256 depositPrice;
        uint256 goal;
        address HAIFU;
        // {wAIfu token} / {$HAIFU}
        uint256 haifuPrice;
        uint256 haifuGoal;
        uint256 fundAcceptingExpiaryDate;
        uint256 fundExpiaryDate;
    }

    struct OrderInfo {
        uint256 makePrice;
        uint256 placed;
        uint32 orderId;
    }

    struct wAIfuOpenInfo {
        address creator;
        address deposit;
        uint256 depositPrice;
        uint256 haifuPrice;
    }

    function switchWhitelist(address sender, bool status) external;

    function setWhitelist(address sender, address account, bool status) external;

    function setConfig(address sender, Config memory config) external;

    function isWhitelisted(address account) external view returns (bool);

    function openInfo() external view returns (wAIfuOpenInfo memory);

    function fundAcceptingExpiaryDate() external view returns (uint256);

    function fundExpiaryDate() external view returns (uint256);

    function createHaifu(string memory name, string memory symbol, address creator, State memory haifu)
        external
        returns (address);

    function initialize(
        string memory name,
        string memory symbol,
        address matchingEngine,
        address launchpad,
        address creator,
        State memory wAIfuInfo
    ) external;

    function commit(address sender, address deposit, uint256 amount)
        external
        returns (address wAIfu, uint256 wAIfuTAmount);

    function commitHaifu(address sender, uint256 amount) external returns (address wAIfu, uint256 wAIfuTAmount);

    function withdraw(address sender, uint256 amount) external returns (address deposit, uint256 depositAmount);

    function withdrawHaifu(address sender, uint256 amount) external returns (address deposit, uint256 haifuAmount);

    function trackExpiary(address managingAsset, uint32 orderId)
        external
        returns (IHaifu.OrderInfo memory rematchOrderInfo);

    function claimExpiary(address sender, uint256 amount)
        external
        returns (address claim, uint256 haifuAmount, bool expiredEarly);

    function getCarry(address account, uint256 amount, bool isMaker) external view returns (uint256);

    function getwAIfu(string memory name, string memory symbol, address creator)
        external
        view
        returns (State memory state);

    function getCommitted(address account) external view returns (uint256 committed);

    function deposit() external view returns (address);

    function raised() external view returns (uint256);

    function creator() external view returns (address);

    function fundManager() external view returns (address);

    function goal() external view returns (uint256);

    function haifuGoal() external view returns (uint256);

    function depositPrice() external view returns (uint256);

    function haifuPrice() external view returns (uint256);

    function launchPrice() external view returns (uint256);

    function isCapitalRaised() external view returns (bool);

    function open()
        external
        returns (IHaifu.OrderInfo memory depositOrderInfo, IHaifu.OrderInfo memory wAIfuOrderInfo, uint256 leftHaifu);

    function expire(address deposit) external returns (IHaifu.OrderInfo memory rematchOrderInfo, bool expiredEarly);

    function expireFundManager(address fundManager) external returns (uint256 redeemed);
}
