// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Haifu official token contract
 * @notice $HAIFU is a multichain token that can be minted and burned with max supply of 1 billion tokens. 
 * Minting and burning roles are assigned to the bridge providers.
 * The max supply can decrease by the admin to protect the value of the token in case of preventing further damage from bridge attacks.
 * From all chains, the total supply of $HAIFU is kept at 1 billion.
 */
contract Haifu is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private MAX_SUPPLY = 1000_000_000 * 10 ** 18; // 1 billion tokens with 18 decimals

    error MaxSupplyReached(uint256 currentSupply, uint256 newSupply);
    error SupplyTooHigh(uint256 maxSupply, uint256 currentSupply, uint256 newSupply);
    event MaxSupplySet(uint256 newMaxSupply);

    function maxSupply() public view returns (uint256) {
        return MAX_SUPPLY;
    }

    function setMaxSupply(uint256 newMaxSupply) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMaxSupply < totalSupply()) {
            revert MaxSupplyReached(totalSupply(), newMaxSupply);
        }
        if (newMaxSupply > MAX_SUPPLY) {
            revert SupplyTooHigh(MAX_SUPPLY, totalSupply(), newMaxSupply);
        }
        MAX_SUPPLY = newMaxSupply;
        emit MaxSupplySet(newMaxSupply);
    }

    constructor() ERC20("Haifu", "HAIFU") {
        // Grant the contract deployer the default admin role: they can grant and revoke any roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Grant the minter and pauser roles to the deployer
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert MaxSupplyReached(totalSupply(), totalSupply() + amount);
        }
        _mint(to, amount);
    }

    function remainingMintableSupply() public view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
}
