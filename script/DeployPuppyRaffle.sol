// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import {Script} from "../lib/forge-std/src/Script.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract DeployPuppyRaffle is Script {
    uint256 entranceFee = 1e18;
    address feeAddress;
    uint256 duration = 1 days;

    function run() public {
        feeAddress = msg.sender;

        vm.broadcast();
        new PuppyRaffle(1e18, feeAddress, duration);
    }
}
