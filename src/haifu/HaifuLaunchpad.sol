// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IHaifu} from "../interfaces/IHaifu.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import "../libraries/TransferHelper.sol";
import {IMatchingEngine} from "@standardweb3/exchange/interfaces/IMatchingEngine.sol";

interface IRevenue {
    function feeOf(address account) external view returns (uint32 feeNum);

    function isSubscribed(address account) external view returns (bool isSubscribed);
}

// HaifuLaunchpad is a MARKET_MAKER
contract HaifuLaunchpad is AccessControl, Initializable {
    // Define roles
    bytes32 public constant CREATOR = keccak256("CREATOR");
    uint256 constant DENOM = 1e8;

    address public haifuFactory;
    address public matchingEngine;
    address public WETH;
    address public HAIFU;
    address public feeTo;
    uint256 private baseFee;
    uint256 private creatorFee;

    // Haifu lifecycle
    event HaifuLaunched(TransferHelper.TokenInfo token, IHaifu.State haifu);
    event HaifuOpen(
        address haifu, uint256 timestamp, IHaifu.OrderInfo depositOrder, IHaifu.OrderInfo haifuOrder, uint256 leftHaifu
    );
    event HaifuExpired(address haifu, uint256 timestamp, IHaifu.OrderInfo expireOrder);
    event HaifuWhitelisted(address haifu, address account, bool isWhitelisted);

    // Investment
    event HaifuDeposit(address sender, address haifu, uint256 carry);
    event HaifuCommit(address haifu, address sender, address deposit, uint256 amount, bool isWhitelisted);
    event HaifuWithdraw(address haifu, address sender, address deposit, uint256 amount, bool isWhitelisted);

    // errors
    error HaifuAlreadyExists(address haifu);
    error HaifuIsNotAccepting(address haifu, uint256 fundAcceptingExpiaryDate, uint256 current);
    error HaifuIsNotOpen(address haifu, uint256 fundAcceptingExpiaryDate, uint256 current);
    error HaifuIsNotExpired(address haifu, uint256 fundExpiaryDate, uint256 current);
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

    // admin functions
    function setFeeTo(address _feeTo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeTo = _feeTo;
    }

    function setBaseFee(uint256 _baseFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseFee = _baseFee;
    }

    function setCreatorFee(uint256 _creatorFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        creatorFee = _creatorFee;
    }

    function commitETH(address haifu) external payable {
        // wrap ETH to WETH
        require(msg.value > 0, "Amount is zero");

        IWETH(WETH).deposit{value: msg.value}();
        // commit to fund
        IHaifu(haifu).commit(msg.sender, WETH, msg.value);
    }

    function commit(address haifu, address deposit, uint256 amount) external {
        uint256 withoutFee = _deposit(haifu, deposit, amount);
        // transfer to haifu token contract
        TransferHelper.safeTransfer(deposit, haifu, withoutFee);
        // commit to fund
        IHaifu(haifu).commit(msg.sender, deposit, amount);
        emit HaifuCommit(haifu, msg.sender, deposit, withoutFee, true);
    }

    function commitHaifu(address haifu, uint256 amount) external {
        uint256 withoutFee = _deposit(haifu, haifu, amount);
        // transfer to haifu token contract
        TransferHelper.safeTransfer(haifu, haifu, withoutFee);
        // commit to fund
        IHaifu(haifu).commitHaifu(msg.sender, amount);
        emit HaifuCommit(haifu, msg.sender, HAIFU, withoutFee, false);
    }

    function withdraw(address haifu, address deposit, uint256 amount) external {
        // transfer from haifu token contract to this contract
        TransferHelper.safeTransferFrom(haifu, msg.sender, address(this), amount);
        // transfer to hairu token contract
        TransferHelper.safeTransfer(haifu, haifu, amount);
        // withdraw from fund
        IHaifu(haifu).withdraw(msg.sender, deposit, amount);
        // TODO: finish event for indexers
        emit HaifuWithdraw(haifu, msg.sender, deposit, amount, true);
    }

    function withdrawHaifu(address haifu, uint256 amount) external {
        // transfer haifu token contract from sender to this contract
        TransferHelper.safeTransferFrom(haifu, msg.sender, address(this), amount);
        // transfer fund to haifu token contract
        TransferHelper.safeTransfer(haifu, haifu, amount);
        // withdraw from fund
        IHaifu(haifu).withdrawHaifu(msg.sender, amount);
        // TODO: finish event for indexers
        emit HaifuWithdraw(haifu, msg.sender, HAIFU, amount, false);
    }

    function launchHaifu(string memory name, string memory symbol, IHaifu.State memory haifu)
        external
        onlyRole(CREATOR)
    {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            // Pay $HAIFU token creation fee
            TransferHelper.safeTransferFrom(HAIFU, msg.sender, address(this), creatorFee);
            // Send to feeTo address
            TransferHelper.safeTransfer(HAIFU, feeTo, creatorFee);
        }

        // create haifu token
        address ai = IHaifu(haifuFactory).createHaifu(name, symbol, msg.sender, haifu);

        // TODO: finish event for indexers
        TransferHelper.TokenInfo memory tokenInfo = TransferHelper.TokenInfo({
            token: ai,
            decimals: 18,
            name: name,
            symbol: symbol,
            totalSupply: haifu.totalSupply
        });
        emit HaifuLaunched(tokenInfo, haifu);
    }

    function openHaifu(address haifu) external onlyRole(CREATOR) {
        IHaifu.HaifuOpenInfo memory info = _getHaifuInfo(haifu);
        _validateCreator(info.creator);

        if (IHaifu(haifu).isCapitalRaised()) {
            _handleCapitalRaised(haifu, info);
        } else {
            IHaifu.OrderInfo memory expireOrder = IHaifu(haifu).expire(info.deposit);
            emit HaifuExpired(haifu, block.timestamp, expireOrder);
        }

        // TODO: finish event for indexers
    }

    // Internal function to retrieve Haifu info
    function _getHaifuInfo(address haifu) internal view returns (IHaifu.HaifuOpenInfo memory) {
        return IHaifu(haifu).openInfo();
    }

    // Internal function to validate the creator
    function _validateCreator(address creator) internal view {
        if (creator != msg.sender) {
            revert InvalidAccess(msg.sender, creator);
        }
    }

    // Internal function to handle capital raised scenario
    function _handleCapitalRaised(address haifu, IHaifu.HaifuOpenInfo memory info) internal {
        IMatchingEngine(matchingEngine).addPair(haifu, info.deposit, info.depositPrice, 0, info.deposit);
        IMatchingEngine(matchingEngine).addPair(haifu, HAIFU, info.haifuPrice, 0, info.deposit);

        (IHaifu.OrderInfo memory depositOrder, IHaifu.OrderInfo memory haifuOrder, uint256 leftHaifu) =
            IHaifu(haifu).open();
        emit HaifuOpen(haifu, block.timestamp, depositOrder, haifuOrder, leftHaifu);
    }

    function expireHaifu(address haifu, address managingAsset) external onlyRole(CREATOR) {
        // check if the haifu fund manager is contract
        address fundManager = IHaifu(haifu).fundManager();
        if (!_isContract(fundManager)) {
            revert FundManagerIsHuman(fundManager);
        }
        // expire haifu's managing assets to distribute pro-rata funds to investors
        IHaifu.OrderInfo memory expireOrder = IHaifu(haifu).expire(managingAsset);

        // TODO: finish event for indexers
        emit HaifuExpired(haifu, block.timestamp, expireOrder);
    }

    function trackExpiary(address haifu, address managingAsset, uint32 orderId) external {
        // track expiary, rematch bid order in HAIFU/{managingAsset} pair
        IHaifu(haifu).trackExpiary(managingAsset, orderId);

        // TODO: finish event for indexers
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
    function getHaifu(string memory name, string memory symbol, address creator)
        public
        view
        returns (IHaifu.State memory haifu)
    {
        return IHaifu(haifuFactory).getHaifu(name, symbol, creator);
    }

    function _deposit(address haifu, address deposit, uint256 amount) internal returns (uint256 withoutFee) {
        // check if amount is zero
        if (amount == 0) {
            revert AmountIsZero();
        }

        if (haifu == address(0)) {
            revert InvalidHaifu();
        }

        if (deposit != WETH) {
            TransferHelper.safeTransferFrom(deposit, msg.sender, address(this), amount);
        }
        // check sender's fee
        uint256 fee = _fee(amount, msg.sender);
        withoutFee = amount - fee;

        TransferHelper.safeTransfer(deposit, feeTo, fee);

        return (withoutFee);
    }

    function _fee(uint256 amount, address account) internal view returns (uint256 fee) {
        if (_isContract(feeTo) && IRevenue(feeTo).isSubscribed(account)) {
            uint32 feeNum = IRevenue(feeTo).feeOf(account);
            return (amount * feeNum) / DENOM;
        }
        return (amount * baseFee) / DENOM;
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
