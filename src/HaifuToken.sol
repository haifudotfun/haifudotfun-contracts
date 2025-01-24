// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MyToken is ERC20, AccessControl {
    // Define roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(string memory name, string memory symbol, uint256 initialSupply, address admin) ERC20(name, symbol) {
        // Grant the admin role to the deployer
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        
        // Grant the minter and burner roles to the admin
        _setupRole(MINTER_ROLE, admin);
        _setupRole(BURNER_ROLE, admin);

        // Mint initial supply to the admin
        _mint(admin, initialSupply);
    }

    // Function to mint new tokens (only for accounts with MINTER_ROLE)
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // Function to burn tokens (only for accounts with BURNER_ROLE)
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    // Override supportsInterface to include AccessControl's interface
    function supportsInterface(bytes4 interfaceId) public view override(ERC20, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}