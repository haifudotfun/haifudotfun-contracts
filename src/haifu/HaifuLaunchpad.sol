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
        uint256 acceptingExpiaryDate = IHaifu(haifu).checkFundAcceptingExpiaryDate();
        if (block.timestamp > acceptingExpiaryDate) {
            revert HaifuIsNotAccepting(haifu, acceptingExpiaryDate, block.timestamp);
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
        uint256 acceptingExpiaryDate = IHaifu(haifu).checkFundAcceptingExpiaryDate();
        if (block.timestamp > acceptingExpiaryDate) {
            revert HaifuIsNotAccepting(haifu, acceptingExpiaryDate, block.timestamp);
        }

        // withdraw from fund
        IHaifu(haifu).withdraw(msg.sender, deposit, amount);

        emit HaifuWithdraw(haifu, deposit, amount);
    }

    function launchHaifu(IHaifu.State memory haifu) external onlyRole(CREATOR) {
        // Pay $HAIFU token creation fee
        TransferHelper.safeTransferFrom(
            HAIFU,
            msg.sender,
            address(this),
            fee
        );
        // Send to feeTo address
        TransferHelper.safeTransfer(HAIFU, feeTo, fee);
        // create haifu token
        IHaifu(haifuFactory).createHaifu(haifu);
    }

    function openHaifu(address haifu) external onlyRole(CREATOR) {
        // check if Haifu creator is the sender
        if (IHaifu(haifu).creator() != msg.sender) {
            revert InvalidAccess(msg.sender, IHaifu(haifu).creator());
        }

        // open haifu if fund has reached goal, else expire haifu
        if(IHaifu(haifu).isFundRaised()) {
            // if fund is successfully raised, open haifu will bring funds to this contract for MM.
            IHaifu(haifu).open();
        }
        else {
            // if fund is not raised, expired haifu will keep the funds in the contract to distribute to investors on expiary
            IHaifu(haifu).expire();
        }
        // make pair on dex for haifu for 10% of total haifu supply after sale
        IMatchingEngine(matchingEngine).addPair(haifu, WETH, 10);

        // send 90% of total haifu supply after sale to haifu creator
    }

    function expireHaifu(address haifu) external onlyRole(CREATOR) {
        // expire haifu to distribute pro-rata funds to investors
    }

    function claimExpiary(address haifu) external {
        // claim expiary
    }

    /**
     * @dev Returns the address of the haifu for the given name, symbol and creator.
     * @param name name of the haifu.
     * @param symbol symbol of the haifu.
     * @param creator creator of the haifu.
     * @return book The address of haifu.
     */
    function getHaifu(
        string name,
        string symbol,
        address creator
    ) public view returns (address haifu) {
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

        emit HaifuDeposit(msg.sender, haifu, carry);

        return (withoutFee, pair);
    }

    function _carry(
        address Haifu,
        uint256 amount,
        address account,
        bool isMaker
    ) internal returns (uint256 carryAmount) {
        // get Carry from Haifu
        uint256 carry = IHaifu(Haifu).getCarry(account, amount, isMaker);
        // calculate carry
        return (amount * carry) / 100000000;
    }
}
