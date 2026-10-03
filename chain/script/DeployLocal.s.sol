// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DynamicaTestAsset} from "../contracts/DynamicaTestAsset.sol";
import {DynamicaVaultFactory} from "../contracts/DynamicaVaultFactory.sol";

/// @notice Local deployment only. No authority or scheduler is enabled automatically.
contract DeployLocal is Script {
    function run() external returns (DynamicaTestAsset asset, DynamicaVaultFactory factory, address vault) {
        require(block.chainid == 31337, "Local deployment only");
        vm.startBroadcast();
        asset = new DynamicaTestAsset();
        factory = new DynamicaVaultFactory();
        vault = factory.createVault(IERC20(address(asset)), 1000 ether, keccak256("dynamica-local-v1"));
        vm.stopBroadcast();
    }
}
