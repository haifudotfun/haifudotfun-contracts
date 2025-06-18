pragma solidity >=0.8;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Utils} from "../utils/Utils.sol";
import {Haifu} from "../../src/haifu/Haifu.sol";

contract HaifuSetup is Test {
    Haifu public haifu;

    function setUp() public {
        haifu = new Haifu();
    }

    function testHAIFUMaxSupplyCannotExceedOneBillion() public {
        haifu.setMaxSupply(1_000_000_000 * 10 ** 18);
        assertEq(haifu.maxSupply(), 1_000_000_000 * 10 ** 18);

        vm.expectRevert();
        haifu.setMaxSupply(1_000_000_000 * 10 ** 18 + 1);
    }

    function testHAIFUMaxSupplyCannotBeReducedBelowCurrentSupply() public {
        uint256 initialSupply = haifu.totalSupply();
        haifu.setMaxSupply(initialSupply + 1);
        assertEq(haifu.maxSupply(), initialSupply + 1);
        haifu.mint(address(this), 1);
        assertEq(haifu.totalSupply(), initialSupply + 1);

        vm.expectRevert();
        haifu.setMaxSupply(0);
    }

    function testHAIFUMintingIsLimitedByMaxSupplyByOneBillionByDefault() public {
       haifu.mint(address(this), 1_000_000_000 * 10 ** 18);

       vm.expectRevert();
       haifu.mint(address(this), 1);
    }

    function testHAIFUMintingIsLimitedByMaxSupplyByReducedMaxSupply() public {
        haifu.setMaxSupply(900_000_000 * 10 ** 18);
        assertEq(haifu.maxSupply(), 900_000_000 * 10 ** 18);

        haifu.mint(address(this), 900_000_000 * 10 ** 18);

        vm.expectRevert();
        haifu.mint(address(this), 1);
    }
}