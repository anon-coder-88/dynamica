// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DynamicaStrategyVault} from "../contracts/DynamicaStrategyVault.sol";
import {DynamicaReserve} from "../contracts/DynamicaReserve.sol";

// Only the cheatcodes used by this suite; no third-party test framework is vendored.
interface Vm {
    function prank(address sender) external;
    function startPrank(address sender) external;
    function stopPrank() external;
    function warp(uint256 timestamp) external;
    function expectRevert() external;
    function expectRevert(bytes4 selector) external;
    function expectRevert(bytes calldata reason) external;
    function assume(bool condition) external;
}

contract MockAsset is ERC20 {
    uint8 private immutable precision;
    constructor(uint8 decimals_) ERC20("Test Asset", "TEST") { precision = decimals_; }
    function decimals() public view override returns (uint8) { return precision; }
    function mint(address to, uint256 amount) external { _mint(to, amount); }
    function burn(address from, uint256 amount) external { _burn(from, amount); }
}

contract FeeAsset is MockAsset {
    bool public fees;
    constructor() MockAsset(18) {}
    function setFees(bool value) external { fees = value; }
    function _update(address from, address to, uint256 value) internal override {
        if (fees && from != address(0) && to != address(0)) {
            uint256 fee = value / 10;
            super._update(from, address(0), fee);
            super._update(from, to, value - fee);
        } else { super._update(from, to, value); }
    }
}

contract ReenterAsset is MockAsset {
    address public target;
    bool public armed;
    bool public attempted;
    bool public blocked;
    bytes4 public callbackError;
    constructor() MockAsset(18) {}
    function arm(address vault) external { target = vault; armed = true; }
    function _update(address from, address to, uint256 value) internal override {
        if (armed && from != address(0) && to != address(0)) {
            armed = false;
            attempted = true;
            (bool ok, bytes memory reason) = target.call(abi.encodeWithSignature("deposit(uint256,address)", 1, address(this)));
            blocked = !ok;
            if (reason.length >= 4) { bytes4 selector; assembly { selector := mload(add(reason, 32)) } callbackError = selector; }
        }
        super._update(from, to, value);
    }
}

contract FalseReturnAsset is MockAsset {
    constructor() MockAsset(18) {}
    function transferFrom(address, address, uint256) public pure override returns (bool) { return false; }
}

abstract contract TestSupport {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address internal constant ALICE = address(0xa11ce);
    address internal constant BOB = address(0xb0b);
    address internal constant KEEPER = address(0xbee);
    address internal constant OUTSIDER = address(0xbad);
    MockAsset internal token;
    DynamicaStrategyVault internal vault;
    DynamicaReserve internal reserve;

    function setUp() public virtual {
        vm.warp(100_000);
        token = new MockAsset(18);
        vault = new DynamicaStrategyVault(IERC20(address(token)), 1000 ether, address(this));
        reserve = vault.reserve();
        token.mint(ALICE, 1000 ether);
        token.mint(BOB, 1000 ether);
        vm.prank(ALICE);
        token.approve(address(vault), type(uint256).max);
        vm.prank(BOB);
        token.approve(address(vault), type(uint256).max);
    }

    function policy(uint16 target, uint256 maxMove, uint256 budget)
        internal view returns (DynamicaStrategyVault.Policy memory)
    {
        return DynamicaStrategyVault.Policy({operator: KEEPER, reserveBps: target,
            minInterval: 60, windowDuration: 1 hours, expiresAt: uint64(block.timestamp + 7 days),
            maxMove: maxMove, windowLimit: budget});
    }

    function configure(uint16 target, uint256 maxMove, uint256 budget) internal {
        vault.configurePolicy(policy(target, maxMove, budget));
    }

    function depositAlice(uint256 assets) internal returns (uint256 shares) {
        vm.prank(ALICE);
        return vault.deposit(assets, ALICE);
    }

    function rebalance() internal returns (uint256 assets) {
        uint256 version = vault.policyVersion();
        vm.prank(KEEPER);
        return vault.rebalance(version, 0);
    }

    function assertEq(uint256 actual, uint256 expected, string memory message) internal pure {
        require(actual == expected, message);
    }
    function assertEq(address actual, address expected, string memory message) internal pure {
        require(actual == expected, message);
    }
    function assertTrue(bool value, string memory message) internal pure { require(value, message); }
    function assertReason(DynamicaStrategyVault.BlockReason expected) internal view {
        (,, DynamicaStrategyVault.BlockReason actual) = vault.previewRebalance();
        require(actual == expected, "Unexpected preview block reason");
    }
    function assertConservation(uint256 expected) internal view {
        assertEq(vault.totalAssets(), expected, "Managed assets changed unexpectedly");
        assertEq(token.balanceOf(address(vault)) + token.balanceOf(address(reserve)), expected,
            "Custody locations do not reconcile with managed assets");
    }
}
