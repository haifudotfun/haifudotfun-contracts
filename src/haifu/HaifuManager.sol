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

// HaifuManager is a MARKET_MAKER
contract HaifuManager is AccessControl, Initializable {
    // Define roles
    bytes32 public constant CREATOR = keccak256("CREATOR");
    uint256 constant DENOM = 1e8;

    address public wAIfuFactory;
    address public matchingEngine;
    address public WETH;
    address public HAIFU;
    address public feeTo;
    uint256 private baseFee;
    uint256 private creatorFee;

    // Haifu lifecycle
    event wAIfuLaunched(TransferHelper.TokenInfo wAIfuTokenInfo, IHaifu.State wAIfuInfo, uint256 creatorFee);
    event wAIfuOpen(
        address wAIfu, uint256 timestamp, IHaifu.OrderInfo depositOrder, IHaifu.OrderInfo haifuOrder, uint256 leftHaifu
    );
    event wAIfuExpired(address wAIfu, uint256 timestamp, IHaifu.OrderInfo expireOrder, bool expiredEarly);
    event wAIfuTrackExpiary(address wAIfu, address managingAsset, IHaifu.OrderInfo orderInfo);
    event wAIfuWhitelisted(address wAIfu, address account, bool isWhitelisted);
    event wAIfuSwitchWhitelist(address wAIfu, bool isWhitelisted);
    event wAIfuConfig(address wAIfu, IHaifu.Config config);

    // Investment
    event wAIfuCommit(
        address wAIfu,
        address sender,
        address sent,
        uint256 sentAmount,
        address received,
        uint256 receivedAmount,
        bool isWhitelisted
    );
    event wAIfuWithdraw(
        address wAIfu,
        address sender,
        address sent,
        uint256 sentAmount,
        address received,
        uint256 receivedAmount,
        bool isWhitelisted
    );
    event wAIfuClaimExpiary(
        address account, address sent, uint256 sentAmount, address received, uint256 receivedAmount, bool expiredEarly
    );

    // errors
    error wAIfuAlreadyExists(address wAIfu);
    error wAIfuIsNotAccepting(address wAIfu, uint256 fundAcceptingExpiaryDate, uint256 current);
    error wAIfuIsNotOpen(address wAIfu, uint256 fundAcceptingExpiaryDate, uint256 current);
    error wAIfuIsNotExpired(address wAIfu, uint256 fundExpiaryDate, uint256 current);
    error wAIfuIsNotWhitelisted(address wAIfu, address account);
    error AmountIsZero();
    error InvalidwAIfu();
    error InvalidWithdrawAmount(uint256 amount, uint256 committed);
    error OrderSizeTooSmall(uint256 converted, uint256 minRequired);
    error InvalidAccess(address sender, address allowed);
    error wAIfuFailedToRaiseCapital(address wAIfu);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR, msg.sender);
    }

    function initialize(
        address _wAIfuFactory,
        address _matchingEngine,
        address _WETH,
        address _HAIFU,
        address _feeTo,
        uint256 _baseFee,
        uint256 _creatorFee
    ) external initializer {
        wAIfuFactory = _wAIfuFactory;
        matchingEngine = _matchingEngine;
        WETH = _WETH;
        HAIFU = _HAIFU;
        feeTo = _feeTo;
        baseFee = _baseFee;
        creatorFee = _creatorFee;
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

    function commitETH(address wAIfu) external payable {
        // wrap ETH to WETH
        require(msg.value > 0, "Amount is zero");

        IWETH(WETH).deposit{value: msg.value}();
        // commit to fund
        IHaifu(wAIfu).commit(msg.sender, WETH, msg.value);
    }

    function commit(address wAIfu, address deposit, uint256 amount)
        external
        returns (address wAIfuT, uint256 wAIfuTAmount)
    {
        uint256 withoutFee = _deposit(wAIfu, deposit, amount);
        // transfer to haifu token contract
        TransferHelper.safeTransfer(deposit, wAIfu, withoutFee);
        // commit to fund
        (wAIfuT, wAIfuTAmount) = IHaifu(wAIfu).commit(msg.sender, deposit, withoutFee);
        emit wAIfuCommit(wAIfu, msg.sender, deposit, amount, wAIfuT, wAIfuTAmount, true);
        return (wAIfu, wAIfuTAmount);
    }

    function commitHaifu(address wAIfu, uint256 amount) external returns (address wAIfuT, uint256 wAIfuTAmount) {
        uint256 withoutFee = _deposit(wAIfu, HAIFU, amount);
        // transfer to haifu token contract
        TransferHelper.safeTransfer(HAIFU, wAIfu, withoutFee);
        // commit to fund
        (wAIfuT, wAIfuTAmount) = IHaifu(wAIfu).commitHaifu(msg.sender, withoutFee);
        emit wAIfuCommit(wAIfu, msg.sender, HAIFU, amount, wAIfuT, wAIfuTAmount, false);
        return (wAIfu, wAIfuTAmount);
    }

    function withdraw(address wAIfu, uint256 amount) external returns (address deposit, uint256 depositAmount) {
        // transfer from haifu token contract to this contract
        TransferHelper.safeTransferFrom(wAIfu, msg.sender, address(this), amount);
        // transfer to hairu token contract
        TransferHelper.safeTransfer(wAIfu, wAIfu, amount);
        // withdraw from fund
        (deposit, depositAmount) = IHaifu(wAIfu).withdraw(msg.sender, amount);
        emit wAIfuWithdraw(wAIfu, msg.sender, wAIfu, amount, deposit, depositAmount, true);
        return (deposit, depositAmount);
    }

    function withdrawHaifu(address wAIfu, uint256 amount) external returns (address deposit, uint256 depositAmount) {
        // transfer haifu token contract from sender to this contract
        TransferHelper.safeTransferFrom(wAIfu, msg.sender, address(this), amount);
        // transfer fund to haifu token contract
        TransferHelper.safeTransfer(wAIfu, wAIfu, amount);
        // withdraw from fund
        (deposit, depositAmount) = IHaifu(wAIfu).withdrawHaifu(msg.sender, amount);
        emit wAIfuWithdraw(wAIfu, msg.sender, wAIfu, amount, deposit, depositAmount, false);
        return (deposit, depositAmount);
    }

    function launchwAIfu(string memory name, string memory symbol, IHaifu.State memory wAIfuInfo)
        external
        onlyRole(CREATOR)
        returns (address wAIfu)
    {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            // Pay $HAIFU token creation fee
            TransferHelper.safeTransferFrom(HAIFU, msg.sender, address(this), creatorFee);
            // Send to feeTo address
            TransferHelper.safeTransfer(HAIFU, feeTo, creatorFee);
        }

        // create haifu token
        wAIfu = IHaifu(wAIfuFactory).createHaifu(name, symbol, msg.sender, wAIfuInfo);

        TransferHelper.TokenInfo memory tokenInfo = TransferHelper.TokenInfo({
            token: wAIfu,
            decimals: 18,
            name: name,
            symbol: symbol,
            totalSupply: wAIfuInfo.totalSupply
        });
        emit wAIfuLaunched(tokenInfo, wAIfuInfo, creatorFee);
        return wAIfu;
    }

    function setWhitelist(address wAIfu, address account, bool isWhitelisted)
        external
        onlyRole(CREATOR)
        returns (bool)
    {
        IHaifu(wAIfu).setWhitelist(msg.sender, account, isWhitelisted);
        emit wAIfuWhitelisted(wAIfu, account, isWhitelisted);
        return true;
    }

    function setConfig(address wAIfu, IHaifu.Config memory config) external onlyRole(CREATOR) returns (bool) {
        IHaifu(wAIfu).setConfig(msg.sender, config);
        emit wAIfuConfig(wAIfu, config);
        return true;
    }

    function switchWhitelist(address wAIfu, bool isWhitelisted) external onlyRole(CREATOR) returns (bool) {
        IHaifu(wAIfu).switchWhitelist(msg.sender, isWhitelisted);
        emit wAIfuSwitchWhitelist(wAIfu, isWhitelisted);
        return true;
    }

    function openwAIfu(address wAIfu) external onlyRole(CREATOR) returns (bool) {
        IHaifu.wAIfuOpenInfo memory info = _getwAIfuInfo(wAIfu);
        _validateCreator(info.creator);

        if (IHaifu(wAIfu).isCapitalRaised()) {
            _handleCapitalRaised(wAIfu, info);
        } else {
            revert wAIfuFailedToRaiseCapital(wAIfu);
        }
        return true;
    }

    // Internal function to retrieve Haifu info
    function _getwAIfuInfo(address wAIfu) internal view returns (IHaifu.wAIfuOpenInfo memory) {
        return IHaifu(wAIfu).openInfo();
    }

    // Internal function to validate the creator
    function _validateCreator(address creator) internal view {
        if (creator != msg.sender) {
            revert InvalidAccess(msg.sender, creator);
        }
    }

    // Internal function to handle capital raised scenario
    function _handleCapitalRaised(address wAIfu, IHaifu.wAIfuOpenInfo memory info) internal {
        try IMatchingEngine(matchingEngine).addPair(wAIfu, info.deposit, info.depositPrice, 0, info.deposit) {
            // Successfully added the first pair
        } catch Error(string memory) {}

        try IMatchingEngine(matchingEngine).addPair(wAIfu, HAIFU, info.haifuPrice, 0, info.deposit) {
            // Successfully added the second pair
        } catch Error(string memory) {}

        (IHaifu.OrderInfo memory depositOrder, IHaifu.OrderInfo memory haifuOrder, uint256 leftHaifu) =
            IHaifu(wAIfu).open();
        emit wAIfuOpen(wAIfu, block.timestamp, depositOrder, haifuOrder, leftHaifu);
    }

    function expirewAIfu(address wAIfu, address managingAsset)
        external
        onlyRole(CREATOR)
        returns (IHaifu.OrderInfo memory expireOrder, bool expiredEarly)
    {
        // expire haifu's managing assets to distribute pro-rata funds to investors
        (expireOrder, expiredEarly) = IHaifu(wAIfu).expire(managingAsset);

        emit wAIfuExpired(wAIfu, block.timestamp, expireOrder, expiredEarly);
        return (expireOrder, expiredEarly);
    }

    function trackExpiary(address wAIfu, address managingAsset, uint32 orderId)
        external
        returns (IHaifu.OrderInfo memory rematchOrderInfo)
    {
        // track expiary, rematch bid order in HAIFU/{managingAsset} pair
        rematchOrderInfo = IHaifu(wAIfu).trackExpiary(managingAsset, orderId);

        emit wAIfuTrackExpiary(wAIfu, managingAsset, rematchOrderInfo);
        return rematchOrderInfo;
    }

    function claimExpiary(address wAIfu, uint256 amount)
        external
        returns (address claim, uint256 claimed, bool expiredEarly)
    {
        TransferHelper.safeTransferFrom(wAIfu, msg.sender, address(this), amount);
        // send haifu token to haifu token contract
        TransferHelper.safeTransfer(wAIfu, wAIfu, amount);
        // claim expiary to receive $HAIFU from haifu token supply, the token contract will send $HAIFU to the sender
        (claim, claimed, expiredEarly) = IHaifu(wAIfu).claimExpiary(msg.sender, amount);

        emit wAIfuClaimExpiary(msg.sender, wAIfu, amount, claim, claimed, expiredEarly);
        return (claim, claimed, expiredEarly);
    }

    /**
     * @dev Returns the address of the haifu for the given name, symbol and creator.
     * @param name name of the haifu.
     * @param symbol symbol of the haifu.
     * @param creator creator of the haifu.
     * @return wAIfu The address of haifu.
     */
    function getwAIfu(string memory name, string memory symbol, address creator)
        public
        view
        returns (IHaifu.State memory wAIfu)
    {
        return IHaifu(wAIfuFactory).getwAIfu(name, symbol, creator);
    }

    function _deposit(address wAIfu, address deposit, uint256 amount) internal returns (uint256 withoutFee) {
        // check if amount is zero
        if (amount == 0) {
            revert AmountIsZero();
        }

        if (wAIfu == address(0)) {
            revert InvalidwAIfu();
        }

        TransferHelper.safeTransferFrom(deposit, msg.sender, address(this), amount);
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
