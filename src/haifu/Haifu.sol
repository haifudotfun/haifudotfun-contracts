// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IHaifu} from "../interfaces/IHaifu.sol";

contract Haifu is ERC20, AccessControl, Initializable, IHaifu {
    // Define roles
    bytes32 public constant WHITELIST = keccak256("WHITELIST");
    IHaifu.State public info;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }

    // Initialize function to replace constructor
    function initialize(IHaifu.State memory haifu) public initializer {
        
        // Grant the admin role to the deployer
        grantRole(DEFAULT_ADMIN_ROLE, haifu.admin);

        // Mint initial supply to the token to the contract to trade
        _mint(address(this), haifu.totalSupply);

        info = haifu;
    }

    function setWhiteList(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        grantRole(WHITELIST, account);
    }

    function commit(address deposit, uint256 amount) public {
        require(hasRole(WHITELIST, msg.sender), "Caller is not whitelisted");
        require(info.deposit + amount <= info.goal, "Goal reached");
        info.deposit += amount;
        _mint(deposit, amount);
    }

    function withdraw(address deposit, uint256 amount) public {
        require(hasRole(WHITELIST, msg.sender), "Caller is not whitelisted");
        require(info.deposit - amount >= 0, "Not enough deposit");
        info.deposit -= amount;
        _burn(deposit, amount);
    }

    function open() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(block.timestamp >= info.fundAcceptingExpiaryDate, "Fund raising is not expired");
        require(block.timestamp < info.fundExpiaryDate, "Fund raising is expired");
        grantRole(WHITELIST, info.fundManager);
    }

    function expire() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(block.timestamp >= info.fundExpiaryDate, "Fund raising is not expired");
        revokeRole(WHITELIST, info.fundManager);
    }

    function checkFundAcceptingExpiaryDate() external view {
        require(block.timestamp < info.fundAcceptingExpiaryDate, "Fund raising is expired");
    }

    function checkFundExpiaryDate() external view {
        require(block.timestamp < info.fundExpiaryDate, "Fund raising is expired");
    }

    // Override supportsInterface to include AccessControl's interface
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
