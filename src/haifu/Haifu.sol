// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IHaifu} from "../interfaces/IHaifu.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import {IMatchingEngine} from "@standardweb3/exchange/interfaces/IMatchingEngine.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Haifu is ERC20, AccessControl, Initializable {
    // Define roles
    bytes32 public constant WHITELIST = keccak256("WHITELIST");
    IHaifu.State public info;
    uint256 depositOne;
    uint256 decDiff;
    address public creator;
    address public matchingEngine;
    string private _name;
    string private _symbol;
    address public launchpad;
    bool public isWhitelisted;

    constructor() ERC20("", "") {}

    error DepositWithMoreThan18Decimals(uint256 depositDecimal);
    error FundManagerIsHuman(address fundManager);

    modifier onlyLaunchpad() {
        require(msg.sender == launchpad, "Caller is not the launchpad contract");
        _;
    }

    // Initialize function to replace constructor
    function initialize(
        string memory name_,
        string memory symbol_,
        address matchingEngine_,
        address launchpad_,
        address creator_,
        IHaifu.State memory haifu
    ) public initializer {
        // Grant the admin role to the deployer
        _name = name_;
        _symbol = symbol_;
        creator = creator_;
        launchpad = launchpad_;
        isWhitelisted = true;
        _grantRole(DEFAULT_ADMIN_ROLE, creator);

        // get depositOne
        depositOne = 10 ** TransferHelper.decimals(haifu.deposit);
        decDiff = 1e18 / depositOne;

        // Mint initial supply to the token to the contract to trade
        _mint(address(this), haifu.totalSupply);
        matchingEngine = matchingEngine_;
        TransferHelper.safeApprove(haifu.deposit, matchingEngine, type(uint256).max);
        TransferHelper.safeApprove(haifu.HAIFU, matchingEngine, type(uint256).max);
        info = haifu;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function fundManager() external view returns (address) {
        return info.fundManager;
    }

    function raised() external view returns (uint256) {
        return info.raised;
    }

    function openInfo() external view returns (IHaifu.HaifuOpenInfo memory) {
        return IHaifu.HaifuOpenInfo({
            creator: creator,
            deposit: info.deposit,
            depositPrice: info.depositPrice,
            haifuPrice: info.haifuPrice
        });
    }

    function setConfig(address sender, IHaifu.Config memory config) public onlyLaunchpad {
        require(sender == creator, "Caller is not creator");
        require(config.totalSupply > totalSupply(), "New Total Supply should be greater than current");
        info.totalSupply = config.totalSupply;
        info.fundManager = config.fundManager;
        info.carry = config.carry;
        info.deposit = config.deposit;
        info.depositPrice = config.depositPrice;
        info.goal = config.goal;
        info.haifuPrice = config.haifuPrice;
        info.haifuGoal = config.haifuGoal;
        require(config.fundAcceptingExpiaryDate <= config.fundExpiaryDate, "Fund accepting expiary date is invalid");
        info.fundAcceptingExpiaryDate = config.fundAcceptingExpiaryDate;
        info.fundExpiaryDate = config.fundExpiaryDate;
    }

    function setWhitelist(address sender, address account, bool status) public onlyLaunchpad {
        require(sender == creator, "Caller is not creator");
        if (status) {
            _grantRole(WHITELIST, account);
        } else {
            _revokeRole(WHITELIST, account);
        }
    }

    function switchWhitelist(address sender, bool status) public onlyLaunchpad {
        require(sender == creator, "Caller is not creator");
        isWhitelisted = status;
    }

    function commitHaifu(address sender, uint256 amount)
        public
        onlyLaunchpad
        returns (address haifu, uint256 haifuTAmount)
    {
        if (isWhitelisted) {
            require(!hasRole(WHITELIST, sender), "Caller is whitelisted");
        }
        require(info.fundAcceptingExpiaryDate > block.timestamp, "Fund raising is expired");
        require(info.haifuRaised + amount <= info.haifuGoal, "Goal reached");
        info.haifuRaised += amount;
        // convert deposit to haifu with depositPrice
        haifuTAmount = (amount * 1e8) / info.haifuPrice;
        TransferHelper.safeTransfer(address(this), sender, haifuTAmount);
        return (address(this), haifuTAmount);
    }

    function commit(address sender, address deposit, uint256 amount)
        public
        onlyLaunchpad
        returns (address haifu, uint256 haifuTAmount)
    {
        require(deposit == info.deposit, "Deposit token is not supported");
        if (isWhitelisted) {
            require(hasRole(WHITELIST, sender), "Caller is not whitelisted");
        }
        require(info.fundAcceptingExpiaryDate > block.timestamp, "Fund raising is expired");
        require(info.raised + amount <= info.goal, "Goal reached");
        info.raised += amount;
        // convert deposit to haifu with depositPrice
        uint256 depositDecimal = TransferHelper.decimals(deposit);
        if (depositDecimal > 18) {
            revert DepositWithMoreThan18Decimals(depositDecimal);
        }
        haifuTAmount = ((amount * 1e8 * decDiff) / info.depositPrice);
        TransferHelper.safeTransfer(address(this), sender, haifuTAmount);
        return (address(this), haifuTAmount);
    }

    function withdrawHaifu(address sender, uint256 amount)
        public
        onlyLaunchpad
        returns (address deposit, uint256 haifuAmount)
    {
        require(info.fundAcceptingExpiaryDate > block.timestamp, "Fund raising is expired");
        // deposit is obviously haifu token
        // get converted haifu token to deposit amount
        haifuAmount = (amount * info.haifuPrice) / 1e8;
        require(info.haifuRaised - haifuAmount >= 0, "Not enough deposit");
        info.haifuRaised -= amount;
        TransferHelper.safeTransfer(info.HAIFU, sender, haifuAmount);
        return (info.HAIFU, haifuAmount);
    }

    function withdraw(address sender, uint256 amount)
        public
        onlyLaunchpad
        returns (address deposit, uint256 depositAmount)
    {
        // deposit is obviously haifu token
        require(info.fundAcceptingExpiaryDate > block.timestamp, "Fund raising is expired");

        require(hasRole(WHITELIST, sender), "Caller is not whitelisted");
        // get converted haifu token to deposit amount
        // convert deposit to haifu with depositPrice
        uint256 depositDecimal = TransferHelper.decimals(info.deposit);
        if (depositDecimal > 18) {
            revert DepositWithMoreThan18Decimals(depositDecimal);
        }
        depositAmount = ((amount * info.depositPrice) / 1e8 / decDiff);
        require(info.raised - depositAmount >= 0, "Not enough deposit");
        info.raised -= depositAmount;
        TransferHelper.safeTransfer(info.deposit, sender, depositAmount);
        return (info.deposit, depositAmount);
    }

    function isCapitalRaised() external view returns (bool) {
        return info.raised >= info.goal;
    }

    function open()
        external
        onlyLaunchpad
        returns (IHaifu.OrderInfo memory depositOrderInfo, IHaifu.OrderInfo memory haifuOrderInfo, uint256 leftHaifu)
    {
        require(block.timestamp >= info.fundAcceptingExpiaryDate, "Fund raising acceptance is not expired");
        require(block.timestamp < info.fundExpiaryDate, "Fund raising is expired");
        _grantRole(WHITELIST, info.fundManager);

        // send carry to creator
        TransferHelper.safeTransfer(
            info.deposit, creator, (IERC20(info.deposit).balanceOf(address(this)) * info.carry) / 1e8
        );

        // 10% of the deposit token will be placed as bid order in {haifu token}/{deposit token} pair, and rest will be sent to fund manager address.
        uint256 depositBalance = IERC20(info.deposit).balanceOf(address(this));
        (depositOrderInfo.makePrice, depositOrderInfo.placed, depositOrderInfo.orderId) = IMatchingEngine(
            matchingEngine
        ).marketBuy(address(this), info.deposit, depositBalance / 10, true, 20, info.fundManager, 10000000);
        // send 90% of deposit token to fund manager address
        TransferHelper.safeTransfer(info.deposit, info.fundManager, IERC20(info.deposit).balanceOf(address(this)));
        // Raised $HAIFU by $HAIFU token holders will be placed as bid order for {haifu token}/$HAIFU pair.
        uint256 haifuBalance = IERC20(info.HAIFU).balanceOf(address(this));
        if (haifuBalance > 0) {
            (haifuOrderInfo.makePrice, haifuOrderInfo.placed, haifuOrderInfo.orderId) = IMatchingEngine(matchingEngine)
                .marketBuy(address(this), info.HAIFU, haifuBalance, true, 20, address(this), 10000000);
        }
        // Rest of Haifu token will be sent to creator address.
        leftHaifu = balanceOf(address(this));
        TransferHelper.safeTransfer(address(this), creator, leftHaifu);
        // return order ids of each deposit and haifu pair
        return (depositOrderInfo, haifuOrderInfo, leftHaifu);
    }

    function expire(address expiringAsset)
        external
        onlyLaunchpad
        returns (IHaifu.OrderInfo memory expireOrderInfo, bool expiredEarly)
    {
        expiredEarly = (info.raised < info.goal) && (block.timestamp >= info.fundAcceptingExpiaryDate);
        require(
            block.timestamp > info.fundExpiaryDate || expiredEarly, "Haifu is not expired and fundraised with success"
        );
        // call Expire function to the fund manager to claim back the asset
        uint256 redeemed;

        if (expiredEarly) {
            // burn haifu token and only leave raised amount
            _burn(address(this), balanceOf(address(this)));
            info.totalSupply = totalSupply();
        } else {
            if (!_isContract(info.fundManager)) {
                revert FundManagerIsHuman(info.fundManager);
            }
            redeemed = IHaifu(info.fundManager).expireFundManager(expiringAsset);
            // turn redeemed asset to $HAIFU
            (expireOrderInfo.makePrice, expireOrderInfo.placed, expireOrderInfo.orderId) = IMatchingEngine(
                matchingEngine
            ).marketBuy(info.HAIFU, expiringAsset, redeemed, true, 20, address(this), 10000000);
        }
        // return order id from buying $HAIFU
        return (expireOrderInfo, expiredEarly);
    }

    function trackExpiary(address expiringAsset, uint32 orderId)
        external
        onlyLaunchpad
        returns (IHaifu.OrderInfo memory rematchOrderInfo)
    {
        require(block.timestamp >= info.fundExpiaryDate, "Fund is not expired");
        // track expiary, rematch bid order in HAIFU/{expiringAsset} pair for an order id
        uint256 refunded = IMatchingEngine(matchingEngine).cancelOrder(info.HAIFU, expiringAsset, true, orderId);

        // make market buy
        (rematchOrderInfo.makePrice, rematchOrderInfo.placed, rematchOrderInfo.orderId) = IMatchingEngine(
            matchingEngine
        ).marketBuy(info.HAIFU, expiringAsset, refunded, true, 20, address(this), 10000000);
        return rematchOrderInfo;
    }

    function claimExpiary(address sender, uint256 amount)
        external
        onlyLaunchpad
        returns (address claim, uint256 claimed, bool expiredEarly)
    {
        expiredEarly = (info.raised < info.goal) && (block.timestamp >= info.fundAcceptingExpiaryDate);
        // deposit is obviously haifu token
        require(block.timestamp >= info.fundExpiaryDate || expiredEarly, "Fund is not expired");
        claim = expiredEarly ? info.deposit : info.HAIFU;
        // calculate HAIFU amount to send
        claimed = (IERC20(claim).balanceOf(address(this)) * amount) / info.totalSupply;
        // send haifu token to haifu token contract
        TransferHelper.safeTransfer(claim, sender, claimed);
        // burn haifu token
        _burn(address(this), amount);
        return (claim, claimed, expiredEarly);
    }

    function checkFundAcceptingExpiaryDate() external view {
        require(block.timestamp < info.fundAcceptingExpiaryDate, "Fund raising is expired");
    }

    function checkFundExpiaryDate() external view {
        require(block.timestamp < info.fundExpiaryDate, "Fund raising is expired");
    }

    function _isContract(address _addr) private view returns (bool) {
        uint256 codeLength;

        // Assembly required for versions < 0.8.0 to check extcodesize.
        assembly {
            codeLength := extcodesize(_addr)
        }

        return codeLength > 0;
    }

    // Override supportsInterface to include AccessControl's interface
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
