// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExampleStrategy {
    address public haifu;

    constructor(address _haifu) {
        haifu = _haifu;
    }
    // ... other functions to manage funds in the strategy

    /// All assets are transferred to the haifu contract, and converted to $HAIFU for claiming expired assets
    function expire(address asset) public {
        // check if the caller is the haifu contract
        require(msg.sender == haifu, "Caller is not the haifu contract");
        uint256 balance = IERC20(asset).balanceOf(address(this));
        require(balance > 0, "No assets to transfer");
        IERC20(asset).transfer(haifu, balance);
    }
}
