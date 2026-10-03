// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "../lib/forge-std/src/Test.sol";
import {StdInvariant} from "../lib/forge-std/src/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DynamicaStrategyVault} from "../contracts/DynamicaStrategyVault.sol";
import {MockAsset} from "./TestSupport.sol";

/// @dev Only these actors hold shares or minted underlying in this campaign.
contract VaultHandler is Test {
    MockAsset public immutable token;
    DynamicaStrategyVault public immutable vault;
    address[3] public actors = [address(0xa11ce), address(0xb0b), address(0xcafe)];
    uint256 public deposits;
    uint256 public withdrawals;
    uint256 public executions;
    uint256 public policyChanges;

    constructor(MockAsset token_, DynamicaStrategyVault vault_) {
        token = token_;
        vault = vault_;
        for (uint256 i; i < actors.length; ++i) {
            token.mint(actors[i], 1000 ether);
            vm.prank(actors[i]);
            token.approve(address(vault), type(uint256).max);
        }
    }

    function configure(uint16 targetSeed, uint96 moveSeed, uint96 budgetSeed) public {
        uint256 maximum = bound(moveSeed, 1, 100 ether);
        uint256 budget = bound(budgetSeed, maximum, 500 ether);
        vault.configurePolicy(
            DynamicaStrategyVault.Policy({
                operator: address(this),
                reserveBps: uint16(bound(targetSeed, 0, 8000)),
                minInterval: 60,
                windowDuration: 1 hours,
                expiresAt: uint64(block.timestamp + 7 days),
                maxMove: maximum,
                windowLimit: budget
            })
        );
        policyChanges++;
    }

    function deposit(uint256 actorSeed, uint96 amountSeed) public {
        address actor = actors[actorSeed % actors.length];
        uint256 available = vault.maxDeposit(actor);
        uint256 balance = token.balanceOf(actor);
        if (available > balance) available = balance;
        if (available == 0) return;
        uint256 assets = bound(amountSeed, 1, available);
        uint256 shares = vault.previewDeposit(assets);
        if (shares == 0) return;
        vm.prank(actor);
        vault.depositWithMinShares(assets, actor, shares);
        deposits += assets;
    }

    function redeem(uint256 actorSeed, uint96 sharesSeed) public {
        address actor = actors[actorSeed % actors.length];
        uint256 held = vault.balanceOf(actor);
        if (held == 0) return;
        uint256 shares = bound(sharesSeed, 1, held);
        uint256 assets = vault.previewRedeem(shares);
        if (assets == 0) return;
        vm.prank(actor);
        vault.redeemWithMinAssets(shares, actor, actor, assets);
        withdrawals += assets;
    }

    function execute(uint32 elapsedSeed) public {
        vm.warp(block.timestamp + bound(elapsedSeed, 1, 3600));
        (, uint256 assets, DynamicaStrategyVault.BlockReason reason) = vault.previewRebalance();
        if (reason != DynamicaStrategyVault.BlockReason.Ready) return;
        vault.rebalanceWithBounds(
            vault.policyVersion(), vault.executionCount(), assets, assets, block.timestamp
        );
        executions++;
    }

    function pause(bool value) public {
        vault.setExecutionPaused(value);
        vault.setDepositsPaused(value);
    }

    function revoke() public {
        vault.revokeOperator();
    }

    function exitAll() public {
        for (uint256 i; i < actors.length; ++i) {
            uint256 shares = vault.balanceOf(actors[i]);
            if (shares == 0) continue;
            vm.prank(actors[i]);
            uint256 assets = vault.redeem(shares, actors[i], actors[i]);
            withdrawals += assets;
        }
    }
}

contract VaultInvariantTest is StdInvariant, Test {
    MockAsset internal token;
    DynamicaStrategyVault internal vault;
    VaultHandler internal handler;

    function setUp() public {
        vm.warp(100_000);
        token = new MockAsset(18);
        vault = new DynamicaStrategyVault(IERC20(address(token)), 1000 ether, address(this));
        handler = new VaultHandler(token, vault);
        vault.transferOwnership(address(handler));
        handler.configure(8000, 10 ether, 50 ether);
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.redeem.selector;
        selectors[2] = handler.execute.selector;
        selectors[3] = handler.configure.selector;
        selectors[4] = handler.pause.selector;
        selectors[5] = handler.revoke.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariantConservationAcrossCustodyAndUsers() public view {
        uint256 total = vault.totalAssets();
        for (uint256 i; i < 3; ++i) {
            total += token.balanceOf(handler.actors(i));
        }
        assertEq(total, 3000 ether);
        assertEq(
            vault.totalAssets(), token.balanceOf(address(vault)) + token.balanceOf(address(vault.reserve()))
        );
        assertEq(vault.totalAssets(), handler.deposits() - handler.withdrawals());
    }

    function invariantSharesAreFullyAttributedAndCapacityEnforced() public view {
        uint256 shares;
        for (uint256 i; i < 3; ++i) {
            shares += vault.balanceOf(handler.actors(i));
        }
        assertEq(shares, vault.totalSupply());
        assertLe(vault.totalAssets(), vault.assetCap());
        assertEq(token.allowance(address(vault), address(vault.reserve())), 0);
    }

    function invariantBudgetAndExecutionCountRemainConsistent() public view {
        (,,,,,, uint256 budget) = vault.policy();
        assertLe(vault.windowSpent(), budget);
        assertEq(vault.executionCount(), handler.executions());
    }

    function afterInvariant() public {
        // Exercise final recovery under both pauses and revoked authority.
        handler.pause(true);
        handler.revoke();
        handler.exitAll();
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(handler.deposits(), handler.withdrawals());
        invariantConservationAcrossCustodyAndUsers();
    }
}
