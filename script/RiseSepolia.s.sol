// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Haifu} from "../src/haifu/Haifu.sol";
import {wAIfuManager} from "../src/haifu/wAIfuManager.sol";
import {wAIfuFactory} from "../src/haifu/wAIfuFactory.sol";
import {MatchingEngine} from "@standardweb3/exchange/MatchingEngine.sol";

contract Deployer is Script {
    function _setDeployer() internal {
        uint256 deployerPrivateKey = vm.envUint("LAUNCHPAD_DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);
    }
}

contract DeployLaunchpad is Deployer {
    function run() public {
        _setDeployer();
        wAIfuManager launchpad;
        Haifu HAIFU;
        wAIfuFactory waifuFactory;
        MatchingEngine matchingEngine = MatchingEngine(payable(0x8E9e786f757B881C7B456682Ae7D2a06820220b1));
        address weth = 0x008fCD6315c68EbAa31244aea174993f63Ef14D5;
        address feeTo = 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
        address Haifu_address = 0x6dCDFAED70e55E350d5Bbe8C9F7b98d97B392bfD;
        address wAIfuManager_address = 0x27410D77F33aE122D9F58d7B4D5392f4CBFeB6e7;
        address wAIfuFactory_address = 0x627a2Db2b4caDb68AAd2306317CF3B027C29341b;

        HAIFU = new Haifu();
        launchpad = new wAIfuManager();
        waifuFactory = new wAIfuFactory();

        launchpad.initialize(
            address(waifuFactory),
            address(matchingEngine),
            address(weth),
            address(HAIFU),
            address(feeTo),
            0,
            10000 * 1e18
        );

        waifuFactory.initialize(address(launchpad), address(matchingEngine));

        bytes32 MARKET_MAKER_ROLE = keccak256("MARKET_MAKER_ROLE");

        // grant MARKET_MAKER_ROLE to launchpad
        matchingEngine.grantRole(MARKET_MAKER_ROLE, address(launchpad));
    }
}
