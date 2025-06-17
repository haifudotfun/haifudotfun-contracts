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

contract DeployHaifu is Deployer {
    function run() public {
        _setDeployer();
        new Haifu();
    }
}

contract DeployLaunchpad is Deployer {
    function run() public {
        _setDeployer();
        wAIfuManager launchpad;
        Haifu HAIFU;
        wAIfuFactory waifuFactory;
        MatchingEngine matchingEngine = MatchingEngine(payable(0x39800D00B0573317E8EABA8BFce1c71a59fD26ee));
        address weth = 0xe8CabF9d1FFB6CE23cF0a86641849543ec7BD7d5;
        address feeTo = 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;

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
