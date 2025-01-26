// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
interface IHaifu {
    struct State {
        string name;
        string symbol;
        address creator;
        uint256 totalSupply;
        address HAIFU;
        address fundManager;
        uint256 deposit;
        uint256 goal;
        uint256 launchPrice;
        uint256 haifuPrice;
        uint256 haifuCap;
        uint256 fundAcceptingExpiaryDate;
        uint256 fundExpiaryDate;
    }

    function isWhitelisted(address account) external view returns (bool);

    function fundAcceptingExpiaryDate() external view returns (uint256);

    function fundExpiaryDate() external view returns (uint256);

    function createHaifu(State memory haifu) external;

    function commit(address sender, address deposit, uint256 amount) external;

    function withdraw(address sender, address deposit, uint256 amount) external;

    function trackExpiary(address managingAsset, uint32 orderId) external;

    function claimExpiary(uint256 amount) external;

    function getCarry(address account, uint256 amount, bool isMaker) external view returns (uint256);

    function getHaifu(string memory name, string memory symbol, address creator) external view returns (State memory state);

    function getCommitted(address account) external view returns (uint256 committed);

    function deposit() external view returns (address);

    function creator() external view returns (address);

    function fundManager() external view returns (address);

    function goal() external view returns (uint256);

    function haifuCap() external view returns (uint256);

    function haifuPrice() external view returns (uint256);

    function launchPrice() external view returns (uint256);

    function isCapitalRaised() external view returns (bool);

    function open() external returns (uint256 leftHaifu);

    function expire() external;
}
