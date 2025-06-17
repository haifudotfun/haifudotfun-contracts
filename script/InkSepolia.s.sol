// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Haifu} from "../src/haifu/Haifu.sol";
import {wAIfuManager} from "../src/haifu/wAIfuManager.sol";
import {wAIfuFactory} from "../src/haifu/wAIfuFactory.sol";
import {MatchingEngine} from "@standardweb3/exchange/MatchingEngine.sol";
import {IHaifu} from "../src/interfaces/IHaifu.sol";

contract Deployer is Script {
    function _setDeployer() internal {
        uint256 deployerPrivateKey = vm.envUint("LAUNCHPAD_DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);
    }
}

contract LaunchwAIfu is Deployer {
    function run() public {
        _setDeployer();
        wAIfuManager manager;
        
        address Haifu_address = 0xEf53e5A0cd6be3BEc47270dB5F65c1c507e8512e;
        address wAIfuManager_address = 0xc63E21C4285Ffe3F258A3486A679C7ac5EDD696C;
        manager = wAIfuManager(wAIfuManager_address);
        IHaifu.State memory info = IHaifu.State({
            totalSupply: 100000000 * 1e18,
            fundManager: 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0,
            carry: 1000000,
            HAIFU: Haifu_address,
            deposit: 0x4200000000000000000000000000000000000006,
            depositPrice: 400000000,
            goal: 100000000 * 1e18,
            haifuPrice: 0,
            haifuGoal: 0,
            fundAcceptingExpiaryDate: block.timestamp + 1 days,
            fundExpiaryDate: block.timestamp + 2 days
        });
        manager.launchwAIfu("Wegumi", "WEGMI", info);
    }
}

contract DeploywAIfuManager is Deployer {
    function run() public {
        _setDeployer();
        wAIfuManager manager;
        Haifu HAIFU;
        wAIfuFactory waifuFactory;
        MatchingEngine matchingEngine = MatchingEngine(
            payable(0x00cB733CBF6fb7079eeeC9EA9b50863756dDbfBE)
        );
        address weth = 0x4200000000000000000000000000000000000006;
        address feeTo = 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;

        HAIFU = new Haifu();
        manager = new wAIfuManager();
        waifuFactory = new wAIfuFactory();

        manager.initialize(
            address(waifuFactory),
            address(matchingEngine),
            address(weth),
            address(HAIFU),
            address(feeTo),
            0,
            10000 * 1e18
        );

        waifuFactory.initialize(address(manager), address(matchingEngine));

        bytes32 MARKET_MAKER_ROLE = keccak256("MARKET_MAKER_ROLE");

        // grant MARKET_MAKER_ROLE to manager
        matchingEngine.grantRole(MARKET_MAKER_ROLE, address(manager));
    }
}

contract RunwAIfuIndexOnLifecycle is Deployer {
    function run() public {
        _setDeployer();
        wAIfuManager manager;
        Haifu HAIFU;
        wAIfuFactory waifuFactory;
        MatchingEngine matchingEngine = MatchingEngine(
            payable(0x00cB733CBF6fb7079eeeC9EA9b50863756dDbfBE)
        );
        address weth = 0x008fCD6315c68EbAa31244aea174993f63Ef14D5;
        address feeTo = 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;

        HAIFU = new Haifu();
        manager = new wAIfuManager();
        waifuFactory = new wAIfuFactory();

        manager.initialize(
            address(waifuFactory),
            address(matchingEngine),
            address(weth),
            address(HAIFU),
            address(feeTo),
            0,
            10000 * 1e18
        );

        waifuFactory.initialize(address(manager), address(matchingEngine));

        bytes32 MARKET_MAKER_ROLE = keccak256("MARKET_MAKER_ROLE");

        // grant MARKET_MAKER_ROLE to manager
        matchingEngine.grantRole(MARKET_MAKER_ROLE, address(manager));
    }
}
