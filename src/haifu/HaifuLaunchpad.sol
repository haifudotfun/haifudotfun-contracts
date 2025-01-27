// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IHaifu} from "../interfaces/IHaifu.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import "../libraries/TransferHelper.sol";
import {IMatchingEngine} from "@standardweb3/exchange/interfaces/IMatchingEngine.sol";

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
        _deposit(haifu, deposit, amount);
        // commit to fund
        IHaifu(haifu).commit(msg.sender, deposit, amount);
        // TODO: finish event for indexers
        emit HaifuCommit(haifu, deposit, amount);
    }

    function commitETH(address haifu) external payable {
        // wrap ETH to WETH
        require(msg.value > 0, "Amount is zero");

        IWETH(WETH).deposit{value: msg.value}();
        // commit to fund
        IHaifu(haifu).commit(msg.sender, WETH, msg.value);
        // TODO: finish event for indexers
        emit HaifuCommit(haifu, WETH, msg.value);
    }

    function commitHaifu(address haifu, uint256 amount) external {
        // commit to fund
        IHaifu(haifu).commitHaifu(msg.sender, amount);
        // TODO: finish event for indexers
        emit HaifuCommit(haifu, HAIFU, amount);
    }

    function withdraw(address haifu, address deposit, uint256 amount) external {
        // withdraw from fund
        IHaifu(haifu).withdraw(msg.sender, deposit, amount);
        // TODO: finish event for indexers
        emit HaifuWithdraw(haifu, deposit, amount);
    }

    function withdrawHaifu(address haifu, uint256 amount) external {
        // withdraw from fund
        IHaifu(haifu).withdrawHaifu(msg.sender, amount);
        // TODO: finish event for indexers
        emit HaifuWithdraw(haifu, HAIFU, amount);
    }

    function launchHaifu(
        string memory name,
        string memory symbol,
        IHaifu.State memory haifu
    ) external onlyRole(CREATOR) {
        // Pay $HAIFU token creation fee
        TransferHelper.safeTransferFrom(HAIFU, msg.sender, address(this), fee);
        // Send to feeTo address
        TransferHelper.safeTransfer(HAIFU, feeTo, fee);
        // create haifu token
        IHaifu(haifuFactory).createHaifu(name, symbol, msg.sender, haifu);

        // TODO: finish event for indexers
    }

    function openHaifu(address haifu) external onlyRole(CREATOR) {
        IHaifu.HaifuOpenInfo memory info = _getHaifuInfo(haifu);
        _validateCreator(info.creator);

        if (IHaifu(haifu).isCapitalRaised()) {
            _handleCapitalRaised(haifu, info);
        } else {
            IHaifu(haifu).expire(info.deposit);
        }

        // TODO: finish event for indexers
    }

    // Internal function to retrieve Haifu info
    function _getHaifuInfo(
        address haifu
    ) internal view returns (IHaifu.HaifuOpenInfo memory) {
        return IHaifu(haifu).openInfo();
    }

    // Internal function to validate the creator
    function _validateCreator(address creator) internal view {
        if (creator != msg.sender) {
            revert InvalidAccess(msg.sender, creator);
        }
    }

    // Internal function to handle capital raised scenario
    function _handleCapitalRaised(
        address haifu,
        IHaifu.HaifuOpenInfo memory info
    ) internal {
        IMatchingEngine(matchingEngine).addPair(
            haifu,
            info.deposit,
            info.depositPrice,
            0,
            info.deposit
        );
        IMatchingEngine(matchingEngine).addPair(
            haifu,
            HAIFU,
            info.haifuPrice,
            0,
            info.deposit
        );

        IHaifu(haifu).open();
    }

    function expireHaifu(
        address haifu,
        address managingAsset
    ) external onlyRole(CREATOR) {
        // check if the haifu fund manager is contract
        address fundManager = IHaifu(haifu).fundManager();
        if (!_isContract(fundManager)) {
            revert FundManagerIsHuman(fundManager);
        }
        // expire haifu's managing assets to distribute pro-rata funds to investors
        IHaifu(haifu).expire(managingAsset);

        // TODO: finish event for indexers
    }

    function trackExpiary(
        address haifu,
        address managingAsset,
        uint32 orderId
    ) external {
        // track expiary, rematch bid order in HAIFU/{managingAsset} pair
        IHaifu(haifu).trackExpiary(managingAsset, orderId);
    }

    function claimExpiary(address haifu, uint256 amount) external {
        // send haifu token to haifu token contract
        TransferHelper.safeTransfer(haifu, haifu, amount);
        // claim expiary to receive $HAIFU from haifu token supply, the token contract will send $HAIFU to the sender
        IHaifu(haifu).claimExpiary(amount);

        // TODO: finish event for indexers
    }

    /**
     * @dev Returns the address of the haifu for the given name, symbol and creator.
     * @param name name of the haifu.
     * @param symbol symbol of the haifu.
     * @param creator creator of the haifu.
     * @return haifu The address of haifu.
     */
    function getHaifu(
        string memory name,
        string memory symbol,
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
        // TransferHelper.safeTransfer(deposit, feeTo, fee);

        return (withoutCarry, pair);
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
