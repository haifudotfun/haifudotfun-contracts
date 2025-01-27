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

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    error DepositWithMoreThan18Decimals(uint256 depositDecimal);

    // Initialize function to replace constructor
    function initialize(address matchingEngine_, address creator_, IHaifu.State memory haifu) public initializer {
        // Grant the admin role to the deployer
        creator = creator_;
        grantRole(DEFAULT_ADMIN_ROLE, creator);

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

    function openInfo() public view returns (IHaifu.HaifuOpenInfo memory) {
        return IHaifu.HaifuOpenInfo({
            creator: creator,
            deposit: info.deposit,
            depositPrice: info.depositPrice,
            haifuPrice: info.haifuPrice
        });
    }

    function setWhiteList(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        grantRole(WHITELIST, account);
    }

    function commitHaifu(address sender, uint256 amount) public returns (address haifu, uint256 haifuAmount) {
        require(!hasRole(WHITELIST, sender), "Caller is whitelisted");
        require(info.haifuRaised + amount <= info.haifuGoal, "Goal reached");
        info.haifuRaised += amount;
        // convert deposit to haifu with depositPrice
        haifuAmount = (amount * 1e8) / info.haifuPrice;
        TransferHelper.safeTransfer(address(this), sender, haifuAmount);
        return (address(this), haifuAmount);
    }

    function commit(address deposit, address sender, uint256 amount)
        public
        returns (address haifu, uint256 haifuTAmount)
    {
        require(deposit == info.deposit, "Deposit token is not supported");
        require(hasRole(WHITELIST, sender), "Caller is not whitelisted");
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

    function withdrawHaifu(address sender, uint256 amount) public returns (address deposit, uint256 haifuAmount) {
        require(!hasRole(WHITELIST, sender), "Caller is whitelisted");
        // deposit is obviously haifu token
        // get converted haifu token to deposit amount
        haifuAmount = (amount * info.haifuPrice) / 1e8;
        require(info.haifuRaised - haifuAmount >= 0, "Not enough deposit");
        info.haifuRaised -= amount;
        TransferHelper.safeTransfer(info.HAIFU, sender, haifuAmount);
        return (info.HAIFU, haifuAmount);
    }

    function withdraw(address sender, uint256 amount) public returns (address deposit, uint256 depositAmount) {
        // deposit is obviously haifu token
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

    function open()
        public
        returns (IHaifu.OrderInfo memory depositOrderInfo, IHaifu.OrderInfo memory haifuOrderInfo, uint256 leftHaifu)
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(block.timestamp >= info.fundAcceptingExpiaryDate, "Fund raising acceptance is not expired");
        require(block.timestamp < info.fundExpiaryDate, "Fund raising is expired");
        grantRole(WHITELIST, info.fundManager);

        // send carry to creator
        TransferHelper.safeTransfer(info.deposit, creator, IERC20(info.deposit).balanceOf(address(this)) * info.carry / 1e8);

        // 10% of the deposit token will be placed as bid order in {haifu token}/{deposit token} pair, and rest will be sent to fund manager address.
        uint256 depositBalance = IERC20(info.deposit).balanceOf(address(this));
        (depositOrderInfo.makePrice, depositOrderInfo.placed, depositOrderInfo.orderId) = IMatchingEngine(
            matchingEngine
        ).marketBuy(address(this), info.deposit, depositBalance / 10, true, 20, info.fundManager);
        // send 90% of deposit token to fund manager address
        TransferHelper.safeTransfer(address(this), info.fundManager, IERC20(info.deposit).balanceOf(address(this)));
        // Raised $HAIFU by $HAIFU token holders will be placed as bid order for {haifu token}/$HAIFU pair.
        uint256 haifuBalance = IERC20(info.HAIFU).balanceOf(address(this));
        (haifuOrderInfo.makePrice, haifuOrderInfo.placed, haifuOrderInfo.orderId) =
            IMatchingEngine(matchingEngine).marketBuy(address(this), info.HAIFU, haifuBalance, true, 20, address(this));
        // Rest of Haifu token will be sent to creator address.
        TransferHelper.safeTransfer(address(this), creator, leftHaifu);
        // return order ids of each deposit and haifu pair
        return (depositOrderInfo, haifuOrderInfo, leftHaifu);
    }

    function expire(address expiringAsset) public returns (IHaifu.OrderInfo memory rematchOrderInfo) {
        require(block.timestamp >= info.fundExpiaryDate, "Fund raising is not expired");
        // call Expire function to the fund manager to claim back the asset
        uint256 redeemed = IHaifu(info.fundManager).expireFundManager(expiringAsset);
        // turn redeemed asset to $HAIFU
        (rematchOrderInfo.makePrice, rematchOrderInfo.placed, rematchOrderInfo.orderId) =
            IMatchingEngine(matchingEngine).marketBuy(info.HAIFU, expiringAsset, redeemed, true, 20, address(this));
        // return order id from buying $HAIFU
        return rematchOrderInfo;
    }

    function trackExpiary(address expiringAsset, uint32 orderId)
        public
        returns (IHaifu.OrderInfo memory rematchOrderInfo)
    {
        require(block.timestamp >= info.fundExpiaryDate, "Fund is not expired");
        // track expiary, rematch bid order in HAIFU/{expiringAsset} pair for an order id
        uint256 refunded = IMatchingEngine(matchingEngine).cancelOrder(info.HAIFU, expiringAsset, true, orderId);

        // make market buy
        (rematchOrderInfo.makePrice, rematchOrderInfo.placed, rematchOrderInfo.orderId) =
            IMatchingEngine(matchingEngine).marketBuy(info.HAIFU, expiringAsset, refunded, true, 20, address(this));
        return rematchOrderInfo;
    }

    function claimExpiary(address sender, uint256 amount) public {
        // deposit is obviously haifu token
        require(block.timestamp >= info.fundExpiaryDate, "Fund is not expired");
        // burn haifu token
        _burn(address(this), amount);
        // calculate HAIFU amount to send
        uint256 haifuAmount = IERC20(info.HAIFU).balanceOf(address(this)) * amount / info.totalSupply;
        // send haifu token to haifu token contract
        TransferHelper.safeTransfer(sender, info.HAIFU, haifuAmount);
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
