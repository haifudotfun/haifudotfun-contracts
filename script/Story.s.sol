// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

function deploy() public {
    console.log("Deploying contract");
    Script.deploy("Story", "script/Story.s.sol");
}