// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IHaifu} from "../interfaces/IHaifu.sol";
import "../libraries/TransferHelper.sol";

contract HaifuLaunchpad is AccessControl, Initializable {
    // Define roles
    bytes32 public constant CREATOR = keccak256("CREATOR");

    address public haifuFactory;
    address public matchingEngine;
    address public WETH;
    address public HAIFU;
    address public feeTo;
    uint256 public fee;

    // Haifu lifecycle
    event HaifuCreated(IHaifu.State haifu);
    event HaifuOpen(address haifu);
    event HaifuWhitelisted(address haifu, address account);

    // Investment
    event HaifuDeposit(address sender, address haifu, uint256 carry);
    event HaifuCommit(address haifu, address deposit, uint256 amount);
    event HaifuWithdraw(address haifu, address deposit, uint256 amount);

    // errors
    error HaifuAlreadyExists(address haifu);
    error HaifuIsNotAccepting(
        address haifu,
        uint256 fundAcceptingExpiaryDate,
        uint256 current
    );
    error HaifuIsNotOpen(
        address haifu,
        uint256 fundAcceptingExpiaryDate,
        uint256 current
    );
    error HaifuIsNotExpired(
        address haifu,
        uint256 fundExpiaryDate,
        uint256 current
    );
    error HaifuIsNotWhitelisted(address haifu, address account);
    error AmountIsZero();
    error InvalidHaifu();
    error InvalidWithdrawAmount(uint256 amount, uint256 committed);
    error OrderSizeTooSmall(uint256 converted, uint256 minRequired);
    error InvalidAccess(address sender, address allowed);
    error FundManagerIsHuman(address fundManager);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR, msg.sender);
    }

    function commit(address haifu, address deposit, uint256 amount) external {
        // check if sender is whitelisted
        if (!IHaifu(haifu).isWhitelisted(msg.sender)) {
            revert HaifuIsNotWhitelisted(haifu, msg.sender);
        }

        // check fund raising accepting ending date
        uint256 acceptingExpiaryDate = IHaifu(haifu).fundAcceptingExpiaryDate();
        if (block.timestamp > acceptingExpiaryDate) {
            revert HaifuIsNotAccepting(
                haifu,
                acceptingExpiaryDate,
                block.timestamp
            );
        }

        // commit to fund
        IHaifu(haifu).commit(msg.sender, deposit, amount);

        emit HaifuCommit(haifu, deposit, amount);
    }

    function withdraw(address haifu, address deposit, uint256 amount) external {
        // check if sender has committed to fund
        uint256 committed = IHaifu(haifu).getCommitted(msg.sender);
        if (committed < amount) {
            revert InvalidWithdrawAmount(amount, committed);
        }
        // check fund raising accepting ending date
        uint256 acceptingExpiaryDate = IHaifu(haifu).fundAcceptingExpiaryDate();
        if (block.timestamp > acceptingExpiaryDate) {
            revert HaifuIsNotAccepting(
                haifu,
                acceptingExpiaryDate,
                block.timestamp
            );
        }

        // withdraw from fund
        IHaifu(haifu).withdraw(msg.sender, deposit, amount);

        emit HaifuWithdraw(haifu, deposit, amount);
    }

    function launchHaifu(IHaifu.State memory haifu) external onlyRole(CREATOR) {
        // Pay $HAIFU token creation fee
        TransferHelper.safeTransferFrom(HAIFU, msg.sender, address(this), fee);
        // Send to feeTo address
        TransferHelper.safeTransfer(HAIFU, feeTo, fee);
        // create haifu token
        IHaifu(haifuFactory).createHaifu(haifu);
    }

    function openHaifu(address haifu) external onlyRole(CREATOR) {
        // check if Haifu creator is the sender
        address creator = IHaifu(haifu).creator();
        address deposit = IHaifu(haifu).deposit();
        uint256 depositPrice = IHaifu(haifu).depositPrice();
        uint256 haifuPrice = IHaifu(haifu).haifuPrice();
        if (creator != msg.sender) {
            revert InvalidAccess(msg.sender, creator);
        }

        // open haifu if fund has reached goal, else expire haifu
        if (IHaifu(haifu).isCapitalRaised()) {
            // make pair on clob for haifu for 10% of total haifu supply after sale
            IMatchingEngine(matchingEngine).addPair(haifu, deposit, 10);
            // make pair on clob for haifu for 10% of total haifu supply after sale
            IMatchingEngine(matchingEngine).addPair(haifu, HAIFU, 10);
            // if fund is successfully raised, open haifu will bring funds to this contract for MM.
            uint256 haifuLeft = IHaifu(haifu).open();
            // send 80% of total haifu supply after sale to haifu creator
            TransferHelper.safeTransfer(haifu, creator, haifuLeft);
        } else {
            // if fund is not raised, expired haifu will keep the funds in the contract to distribute to investors on expiary
            IHaifu(haifu).expire(deposit);
        }
    }

    function expireHaifu(
        address haifu,
        address managingAsset
    ) external onlyRole(CREATOR) {
        // check if the haifu fund manager is contract
        address fundManager = IHaifu(haifu).fundManager();
        if (!_isContract(fundManager)) {
            revert FundManagerIsHuman(managingAsset, fundManager);
        }
        // expire haifu's managing assets to distribute pro-rata funds to investors
        IHaifu(haifu).expire(managingAsset);
    }

    function trackExpiary(
        address haifu,
        address managingAsset,
        uint256 orderId
    ) external {
        // track expiary, rematch bid order in HAIFU/{managingAsset} pair
        IHaifu(haifu).trackExpiary(managingAsset, orderId);
    }

    function claimExpiary(address haifu, uint256 amount) external {
        // send haifu token to haifu token contract
        TransferHelper.safeTransfer(haifu, haifu, amount);
        // claim expiary to receive $HAIFU from haifu token supply, the token contract will send $HAIFU to the sender
        IHaifu(haifu).claimExpiary(amount);
    }

    /**
     * @dev Returns the address of the haifu for the given name, symbol and creator.
     * @param name name of the haifu.
     * @param symbol symbol of the haifu.
     * @param creator creator of the haifu.
     * @return haifu The address of haifu.
     */
    function getHaifu(
        string name,
        string symbol,
        address creator
    ) public view returns (IHaifu.State memory haifu) {
        return IHaifu(haifuFactory).getHaifu(name, symbol, creator);
    }

    function _deposit(
        address haifu,
        address deposit,
        uint256 amount
    ) internal returns (uint256 withoutCarry, address pair) {
        // check if amount is zero
        if (amount == 0) {
            revert AmountIsZero();
        }

        if (haifu == address(0)) {
            revert InvalidHaifu();
        }

        if (deposit != WETH) {
            TransferHelper.safeTransferFrom(
                deposit,
                msg.sender,
                address(this),
                amount
            );
        }
        TransferHelper.safeTransfer(deposit, feeTo, fee);

        return (withoutCarry, pair);
    }

    function _carry(
        address haifu,
        uint256 amount,
        address account,
        bool isMaker
    ) internal returns (uint256 carryAmount) {
        // get Carry from Haifu
        uint256 carry = IHaifu(haifu).getCarry(account, amount, isMaker);
        // calculate carry
        return (amount * carry) / 100000000;
    }

    function _isContract(address _addr) private view returns (bool) {
        uint256 codeLength;

        // Assembly required for versions < 0.8.0 to check extcodesize.
        assembly {
            codeLength := extcodesize(_addr)
        }

        return codeLength > 0;
    }
}
