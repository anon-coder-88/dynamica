// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TestSupport, FeeAsset, ReenterAsset} from "./TestSupport.sol";
import {DynamicaStrategyVault} from "../contracts/DynamicaStrategyVault.sol";
import {DynamicaReserve} from "../contracts/DynamicaReserve.sol";

contract OperatorPolicyTest is TestSupport {
    function testUnconfiguredVaultCannotExecute() public {
        depositAlice(100 ether);
        assertReason(DynamicaStrategyVault.BlockReason.NoOperator);
        vm.expectRevert(DynamicaStrategyVault.OnlyOperator.selector);
        vm.prank(KEEPER);
        vault.rebalance(0, 0);
        assertEq(vault.executionCount(), 0, "Unconfigured execution created an activity record");
        assertConservation(100 ether);
    }

    function testOnlyOwnerCanConfigurePolicy() public {
        DynamicaStrategyVault.Policy memory p = policy(5000, 10 ether, 20 ether);
        vm.expectRevert();
        vm.prank(OUTSIDER);
        vault.configurePolicy(p);
        assertEq(vault.policyVersion(), 0, "Unauthorized configuration changed version");
        assertReason(DynamicaStrategyVault.BlockReason.NoOperator);
    }

    function testConfigurationStoresAndVersionsAllParameters() public {
        DynamicaStrategyVault.Policy memory p = policy(5000, 10 ether, 30 ether);
        vault.configurePolicy(p);
        (address operator, uint16 target, uint64 interval, uint64 duration, uint64 expiry,
            uint256 limit, uint256 budget) = vault.policy();
        assertEq(operator, KEEPER, "Operator address was not stored");
        assertEq(target, 5000, "Reserve target was not stored");
        assertEq(interval, 60, "Execution interval was not stored");
        assertEq(duration, 1 hours, "Window duration was not stored");
        assertEq(expiry, p.expiresAt, "Policy expiry was not stored");
        assertEq(limit, 10 ether, "Per-call limit was not stored");
        assertEq(budget, 30 ether, "Window budget was not stored");
        assertEq(vault.policyVersion(), 1, "First policy must have version one");
        assertEq(vault.windowRemaining(), budget, "New policy budget is not fully available");
        assertEq(vault.windowStartedAt(), block.timestamp, "New window is not anchored at configuration");
    }

    function testRejectZeroOperator() public {
        DynamicaStrategyVault.Policy memory p = policy(5000, 10 ether, 20 ether);
        p.operator = address(0);
        vm.expectRevert(DynamicaStrategyVault.InvalidPolicy.selector);
        vault.configurePolicy(p);
    }

    function testRejectTargetAboveMaximum() public {
        DynamicaStrategyVault.Policy memory p = policy(8001, 10 ether, 20 ether);
        vm.expectRevert(DynamicaStrategyVault.InvalidPolicy.selector);
        vault.configurePolicy(p);
        assertEq(vault.MAX_RESERVE_BPS(), 8000, "Policy must retain the documented 20% idle target floor");
    }

    function testRejectZeroExecutionInterval() public {
        DynamicaStrategyVault.Policy memory p = policy(5000, 10 ether, 20 ether);
        p.minInterval = 0;
        vm.expectRevert(DynamicaStrategyVault.InvalidPolicy.selector);
        vault.configurePolicy(p);
    }

    function testRejectIntervalLongerThanWindow() public {
        DynamicaStrategyVault.Policy memory p = policy(5000, 10 ether, 20 ether);
        p.minInterval = 3601;
        vm.expectRevert(DynamicaStrategyVault.InvalidPolicy.selector);
        vault.configurePolicy(p);
    }

    function testRejectWindowShorterThanHour() public {
        DynamicaStrategyVault.Policy memory p = policy(5000, 10 ether, 20 ether);
        p.windowDuration = 3599;
        vm.expectRevert(DynamicaStrategyVault.InvalidPolicy.selector);
        vault.configurePolicy(p);
    }

    function testRejectWindowLongerThanThirtyDays() public {
        DynamicaStrategyVault.Policy memory p = policy(5000, 10 ether, 20 ether);
        p.windowDuration = uint64(30 days + 1);
        vm.expectRevert(DynamicaStrategyVault.InvalidPolicy.selector);
        vault.configurePolicy(p);
    }

    function testRejectAlreadyExpiredPolicy() public {
        DynamicaStrategyVault.Policy memory p = policy(5000, 10 ether, 20 ether);
        p.expiresAt = uint64(block.timestamp);
        vm.expectRevert(DynamicaStrategyVault.InvalidPolicy.selector);
        vault.configurePolicy(p);
        assertEq(vault.policyVersion(), 0, "Invalid expiry still created a version");
    }

    function testRejectZeroMoveLimit() public {
        DynamicaStrategyVault.Policy memory p = policy(5000, 0, 20 ether);
        vm.expectRevert(DynamicaStrategyVault.InvalidPolicy.selector);
        vault.configurePolicy(p);
    }

    function testRejectWindowBudgetBelowMoveLimit() public {
        DynamicaStrategyVault.Policy memory p = policy(5000, 10 ether, 9 ether);
        vm.expectRevert(DynamicaStrategyVault.InvalidPolicy.selector);
        vault.configurePolicy(p);
    }

    function testPreviewBoundsFirstAllocation() public {
        depositAlice(100 ether);
        configure(5000, 10 ether, 30 ether);
        (bool direction, uint256 amount, DynamicaStrategyVault.BlockReason reason) = vault.previewRebalance();
        assertTrue(direction, "Below-target reserve should receive assets");
        assertEq(amount, 10 ether, "Preview did not apply per-call cap");
        assertTrue(reason == DynamicaStrategyVault.BlockReason.Ready, "Valid first execution must be ready");
        assertConservation(100 ether);
    }

    function testOnlyConfiguredOperatorCanExecute() public {
        depositAlice(100 ether);
        configure(5000, 10 ether, 30 ether);
        uint256 version = vault.policyVersion();
        vm.expectRevert(DynamicaStrategyVault.OnlyOperator.selector);
        vm.prank(OUTSIDER);
        vault.rebalance(version, 0);
        vm.expectRevert(DynamicaStrategyVault.OnlyOperator.selector);
        vault.rebalance(version, 0);
        assertEq(vault.executionCount(), 0, "Unauthorized calls created records");
        assertEq(vault.windowSpent(), 0, "Unauthorized calls spent policy budget");
    }

    function testAllocationMovesAssetsAndClearsTokenApproval() public {
        depositAlice(100 ether);
        configure(5000, 10 ether, 30 ether);
        uint256 moved = rebalance();
        assertEq(moved, 10 ether, "Execution moved wrong amount");
        assertEq(vault.idleAssets(), 90 ether, "Idle assets were not debited");
        assertEq(reserve.totalAssets(), 10 ether, "Reserve assets were not credited");
        assertEq(token.allowance(address(vault), address(reserve)), 0, "Reserve retains a token approval");
        assertEq(token.balanceOf(KEEPER), 0, "Operator received user assets");
        assertEq(vault.executionCount(), 1, "Confirmed execution was not recorded");
        assertEq(vault.windowSpent(), 10 ether, "Executed amount missing from budget");
        assertConservation(100 ether);
    }

    function testAllocationPreservesExistingShareClaims() public {
        depositAlice(100 ether);
        uint256 beforeShares = vault.balanceOf(ALICE);
        uint256 beforeClaim = vault.maxWithdraw(ALICE);
        configure(5000, 10 ether, 30 ether);
        rebalance();
        assertEq(vault.balanceOf(ALICE), beforeShares, "Rebalancing minted or burned user shares");
        assertEq(vault.maxWithdraw(ALICE), beforeClaim, "Rebalancing changed redeemable principal");
        assertEq(vault.totalSupply(), beforeShares, "Rebalancing changed total share supply");
    }

    function testCooldownRejectsImmediateRepeat() public {
        depositAlice(100 ether);
        configure(5000, 10 ether, 30 ether);
        rebalance();
        assertReason(DynamicaStrategyVault.BlockReason.Cooldown);
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.ExecutionBlocked.selector,
            DynamicaStrategyVault.BlockReason.Cooldown));
        vm.prank(KEEPER);
        vault.rebalance(1, 0);
        assertEq(vault.executionCount(), 1, "Cooldown failure created an execution record");
        assertEq(vault.windowSpent(), 10 ether, "Cooldown failure spent budget");
    }

    function testCooldownBoundaryAllowsExecution() public {
        depositAlice(100 ether);
        configure(5000, 10 ether, 30 ether);
        rebalance();
        vm.warp(block.timestamp + 59);
        assertReason(DynamicaStrategyVault.BlockReason.Cooldown);
        vm.warp(block.timestamp + 1);
        assertReason(DynamicaStrategyVault.BlockReason.Ready);
        rebalance();
        assertEq(vault.executionCount(), 2, "Exact cooldown boundary did not allow execution");
        assertEq(reserve.totalAssets(), 20 ether, "Second allocation missing");
    }

    function testWindowBudgetClampsFinalPartialExecution() public {
        depositAlice(100 ether);
        configure(8000, 10 ether, 25 ether);
        rebalance();
        vm.warp(block.timestamp + 60);
        rebalance();
        vm.warp(block.timestamp + 60);
        (, uint256 preview,) = vault.previewRebalance();
        assertEq(preview, 5 ether, "Final preview must clamp to remaining window credit");
        assertEq(rebalance(), 5 ether, "Final execution exceeded remaining budget");
        assertEq(vault.windowSpent(), 25 ether, "Budget does not reconcile with all movements");
        assertEq(vault.windowRemaining(), 0, "Exhausted budget still exposes credit");
        assertConservation(100 ether);
    }

    function testExhaustedBudgetBlocksAfterCooldown() public {
        depositAlice(100 ether);
        configure(8000, 10 ether, 10 ether);
        rebalance();
        vm.warp(block.timestamp + 60);
        assertReason(DynamicaStrategyVault.BlockReason.WindowExhausted);
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.ExecutionBlocked.selector,
            DynamicaStrategyVault.BlockReason.WindowExhausted));
        vm.prank(KEEPER);
        vault.rebalance(1, 0);
        assertEq(reserve.totalAssets(), 10 ether, "Budget-exhausted call moved assets");
    }

    function testWindowBoundaryRestoresBudget() public {
        depositAlice(100 ether);
        configure(8000, 10 ether, 10 ether);
        uint256 anchor = vault.windowStartedAt();
        rebalance();
        vm.warp(anchor + 1 hours - 1);
        assertReason(DynamicaStrategyVault.BlockReason.WindowExhausted);
        vm.warp(anchor + 1 hours);
        assertEq(vault.windowRemaining(), 10 ether, "Exact window boundary did not restore budget");
        rebalance();
        assertEq(vault.windowStartedAt(), anchor + 1 hours, "Window anchor drifted");
        assertEq(vault.windowSpent(), 10 ether, "Old window spend carried into new window");
        assertEq(reserve.totalAssets(), 20 ether, "New window did not execute");
    }

    function testSkippedWindowsDoNotAccumulateCredit() public {
        depositAlice(100 ether);
        configure(8000, 10 ether, 10 ether);
        uint256 anchor = vault.windowStartedAt();
        rebalance();
        vm.warp(anchor + 5 hours + 30);
        assertEq(vault.windowRemaining(), 10 ether, "Skipped windows accumulated unauthorized credit");
        rebalance();
        assertEq(vault.windowStartedAt(), anchor + 5 hours, "Skipped windows drifted fixed anchor");
        assertEq(vault.windowSpent(), 10 ether, "Reset window budget incorrectly");
        assertEq(vault.windowRemaining(), 0, "Full execution did not exhaust current window");
    }

    function testTargetClampsMovementBelowPerCallCap() public {
        depositAlice(100 ether);
        configure(1234, 50 ether, 100 ether);
        (,uint256 preview,) = vault.previewRebalance();
        assertEq(preview, 12.34 ether, "Target difference must clamp per-call limit");
        assertEq(rebalance(), 12.34 ether, "Execution overshot reserve target");
        vm.warp(block.timestamp + 60);
        assertReason(DynamicaStrategyVault.BlockReason.AtTarget);
        assertConservation(100 ether);
    }

    function testReserveReductionRecallsTowardLowerTarget() public {
        depositAlice(100 ether);
        configure(8000, 100 ether, 100 ether);
        rebalance();
        configure(2000, 100 ether, 100 ether);
        (bool direction, uint256 preview,) = vault.previewRebalance();
        assertTrue(!direction, "Above-target reserve should return assets to idle custody");
        assertEq(preview, 60 ether, "Recall amount does not match new target");
        assertEq(rebalance(), 60 ether, "Recall execution moved wrong amount");
        assertEq(vault.idleAssets(), 80 ether, "Recall did not restore idle balance");
        assertEq(reserve.totalAssets(), 20 ether, "Recall overshot target");
        assertConservation(100 ether);
    }

    function testZeroTargetCanRecallEntireReserve() public {
        depositAlice(100 ether);
        configure(8000, 100 ether, 100 ether);
        rebalance();
        configure(0, 100 ether, 100 ether);
        assertEq(rebalance(), 80 ether, "Zero target should recall reserve");
        assertEq(reserve.totalAssets(), 0, "Zero target left reserve assets");
        assertEq(vault.idleAssets(), 100 ether, "Zero target failed to restore all idle assets");
    }

    function testExecutionPauseIsSeparateFromDepositPause() public {
        depositAlice(100 ether);
        configure(5000, 100 ether, 100 ether);
        vault.setExecutionPaused(true);
        assertReason(DynamicaStrategyVault.BlockReason.Paused);
        assertTrue(vault.maxDeposit(BOB) > 0, "Execution pause wrongly closes deposits");
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.ExecutionBlocked.selector,
            DynamicaStrategyVault.BlockReason.Paused));
        vm.prank(KEEPER);
        vault.rebalance(1, 0);
        vault.setExecutionPaused(false);
        assertReason(DynamicaStrategyVault.BlockReason.Ready);
        rebalance();
        assertEq(reserve.totalAssets(), 50 ether, "Execution did not resume after pause");
    }

    function testOnlyOwnerCanPauseExecutionOrDeposits() public {
        vm.expectRevert();
        vm.prank(OUTSIDER);
        vault.setExecutionPaused(true);
        vm.expectRevert();
        vm.prank(OUTSIDER);
        vault.setDepositsPaused(true);
        assertTrue(!vault.executionPaused(), "Unauthorized execution pause changed state");
        assertTrue(!vault.depositsPaused(), "Unauthorized deposit pause changed state");
    }

    function testPolicyExpiresAtExactBoundary() public {
        depositAlice(100 ether);
        DynamicaStrategyVault.Policy memory p = policy(5000, 10 ether, 20 ether);
        p.expiresAt = uint64(block.timestamp + 100);
        vault.configurePolicy(p);
        vm.warp(p.expiresAt - 1);
        assertReason(DynamicaStrategyVault.BlockReason.Ready);
        vm.warp(p.expiresAt);
        assertReason(DynamicaStrategyVault.BlockReason.Expired);
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.ExecutionBlocked.selector,
            DynamicaStrategyVault.BlockReason.Expired));
        vm.prank(KEEPER);
        vault.rebalance(1, 0);
        assertEq(vault.executionCount(), 0, "Expired execution created a record");
    }

    function testRevocationDisablesOldOperatorImmediately() public {
        depositAlice(100 ether);
        configure(5000, 10 ether, 20 ether);
        uint256 oldVersion = vault.policyVersion();
        vault.revokeOperator();
        assertEq(vault.policyVersion(), oldVersion + 1, "Revocation did not invalidate prepared transactions");
        assertReason(DynamicaStrategyVault.BlockReason.NoOperator);
        vm.expectRevert(DynamicaStrategyVault.OnlyOperator.selector);
        vm.prank(KEEPER);
        vault.rebalance(oldVersion, 0);
        assertConservation(100 ether);
    }

    function testOnlyOwnerCanRevokeOperator() public {
        configure(5000, 10 ether, 20 ether);
        vm.expectRevert();
        vm.prank(KEEPER);
        vault.revokeOperator();
        (address operator,,,,,,) = vault.policy();
        assertEq(operator, KEEPER, "Unauthorized revocation removed operator");
        assertEq(vault.policyVersion(), 1, "Unauthorized revocation changed policy version");
    }

    function testOldPolicyVersionCannotExecuteNewPolicy() public {
        depositAlice(100 ether);
        configure(5000, 10 ether, 20 ether);
        uint256 oldVersion = vault.policyVersion();
        configure(6000, 20 ether, 40 ether);
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.StalePolicy.selector, oldVersion, oldVersion + 1));
        vm.prank(KEEPER);
        vault.rebalance(oldVersion, 0);
        assertEq(vault.windowSpent(), 0, "Stale execution consumed new policy credit");
        assertEq(reserve.totalAssets(), 0, "Stale execution moved assets");
    }

    function testPolicyReplacementRemovesPreviousOperatorAuthority() public {
        depositAlice(100 ether);
        configure(5000, 10 ether, 20 ether);
        DynamicaStrategyVault.Policy memory p = policy(6000, 20 ether, 40 ether);
        p.operator = BOB;
        vault.configurePolicy(p);
        uint256 version = vault.policyVersion();
        vm.expectRevert(DynamicaStrategyVault.OnlyOperator.selector);
        vm.prank(KEEPER);
        vault.rebalance(version, 0);
        vm.prank(BOB);
        vault.rebalance(version, 0);
        assertEq(reserve.totalAssets(), 20 ether, "Replacement operator cannot execute");
    }

    function testPolicyReplacementExplicitlyResetsBudgetAndCooldown() public {
        depositAlice(100 ether);
        configure(8000, 10 ether, 10 ether);
        rebalance();
        configure(8000, 10 ether, 10 ether);
        assertEq(vault.windowSpent(), 0, "Owner policy update did not reset budget");
        assertEq(vault.lastExecutionAt(), 0, "Owner policy update did not reset cooldown");
        rebalance();
        assertEq(vault.executionCount(), 2, "Execution history count must survive policy update");
        assertEq(reserve.totalAssets(), 20 ether, "New policy did not execute immediately");
    }

    function testMinimumMovementRevertsWithoutSpendingCredit() public {
        depositAlice(100 ether);
        configure(5000, 10 ether, 20 ether);
        uint256 version = vault.policyVersion();
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.Slippage.selector, 11 ether, 10 ether));
        vm.prank(KEEPER);
        vault.rebalance(version, 11 ether);
        assertEq(vault.windowSpent(), 0, "Slippage failure spent budget");
        assertEq(vault.lastExecutionAt(), 0, "Slippage failure started cooldown");
        assertEq(vault.executionCount(), 0, "Slippage failure created a record");
        assertConservation(100 ether);
    }

    function testWithdrawalAfterOperatorRevocationRemainsAvailable() public {
        depositAlice(100 ether);
        configure(8000, 100 ether, 100 ether);
        rebalance();
        vault.revokeOperator();
        vm.prank(ALICE);
        vault.withdraw(100 ether, ALICE, ALICE);
        assertConservation(0);
        assertEq(token.balanceOf(ALICE), 1000 ether, "Revocation trapped depositor principal");
    }

    function testWithdrawalAfterPolicyExpiryRemainsAvailable() public {
        depositAlice(100 ether);
        configure(8000, 100 ether, 100 ether);
        rebalance();
        vm.warp(block.timestamp + 8 days);
        assertReason(DynamicaStrategyVault.BlockReason.Expired);
        vm.prank(ALICE);
        vault.withdraw(100 ether, ALICE, ALICE);
        assertConservation(0);
        assertEq(reserve.totalAssets(), 0, "Expired policy trapped reserve assets");
    }

    function testWithdrawalIgnoresExecutionBudgetAndBothPauses() public {
        depositAlice(100 ether);
        configure(8000, 10 ether, 10 ether);
        rebalance();
        vault.setExecutionPaused(true);
        vault.setDepositsPaused(true);
        vm.prank(ALICE);
        vault.withdraw(100 ether, ALICE, ALICE);
        assertConservation(0);
        assertEq(vault.windowSpent(), 10 ether, "User withdrawal must not consume or reset execution budget");
        assertEq(token.balanceOf(ALICE), 1000 ether, "Pause controls trapped withdrawal assets");
    }

    function testReserveCannotBeDrainedByKeeperOrOwner() public {
        depositAlice(100 ether);
        configure(8000, 100 ether, 100 ether);
        rebalance();
        vm.expectRevert(DynamicaReserve.OnlyVault.selector);
        vm.prank(KEEPER);
        reserve.recall(1 ether);
        vm.expectRevert(DynamicaReserve.OnlyVault.selector);
        reserve.recall(1 ether);
        assertEq(reserve.totalAssets(), 80 ether, "Unauthorized reserve recall moved assets");
        assertEq(token.balanceOf(KEEPER), 0, "Operator received stolen reserve assets");
    }

    function testReserveCannotAcceptAllocationCallFromOutsider() public {
        vm.expectRevert(DynamicaReserve.OnlyVault.selector);
        vm.prank(OUTSIDER);
        reserve.allocate(1 ether);
        assertEq(reserve.totalAssets(), 0, "Unauthorized allocation mutated reserve");
        assertEq(reserve.vault(), address(vault), "Reserve authority does not point to its creating vault");
        assertEq(address(reserve.asset()), address(token), "Reserve asset does not match vault asset");
    }

    function testDonationAboveCapBlocksDepositsButAllowsExit() public {
        vault.setAssetCap(100 ether);
        depositAlice(100 ether);
        token.mint(address(reserve), 50 ether);
        assertEq(vault.maxDeposit(BOB), 0, "Donation above cap created capacity");
        uint256 shares = vault.balanceOf(ALICE);
        vm.prank(ALICE);
        uint256 returned = vault.redeem(shares, ALICE, ALICE);
        assertTrue(returned > 149 ether, "Donation above cap trapped shareholder return");
        assertTrue(vault.totalAssets() <= 1, "Unexpected residual assets after full donated redemption");
    }

    function testFeeOnTransferReserveAllocationRevertsEntireExecution() public {
        FeeAsset fee = new FeeAsset();
        DynamicaStrategyVault taxed = new DynamicaStrategyVault(IERC20(address(fee)), 1000 ether, address(this));
        fee.mint(ALICE, 100 ether);
        vm.startPrank(ALICE);
        fee.approve(address(taxed), 100 ether);
        taxed.deposit(100 ether, ALICE);
        vm.stopPrank();
        taxed.configurePolicy(policy(5000, 100 ether, 100 ether));
        fee.setFees(true);
        uint256 version = taxed.policyVersion();
        vm.expectRevert(DynamicaReserve.UnsupportedTransfer.selector);
        vm.prank(KEEPER);
        taxed.rebalance(version, 0);
        assertEq(taxed.windowSpent(), 0, "Failed reserve transfer consumed budget");
        assertEq(taxed.executionCount(), 0, "Failed reserve transfer created a record");
        assertEq(taxed.totalAssets(), 100 ether, "Failed reserve transfer burned custody assets");
        assertEq(fee.allowance(address(taxed), address(taxed.reserve())), 0, "Failed execution retained approval");
    }

    function testReentrancyDuringReserveAllocationIsBlocked() public {
        ReenterAsset callback = new ReenterAsset();
        DynamicaStrategyVault guarded = new DynamicaStrategyVault(IERC20(address(callback)), 1000 ether, address(this));
        callback.mint(ALICE, 100 ether);
        vm.startPrank(ALICE);
        callback.approve(address(guarded), 100 ether);
        guarded.deposit(100 ether, ALICE);
        vm.stopPrank();
        guarded.configurePolicy(policy(5000, 100 ether, 100 ether));
        callback.arm(address(guarded));
        uint256 version = guarded.policyVersion();
        vm.prank(KEEPER);
        guarded.rebalance(version, 0);
        assertTrue(callback.blocked(), "Reserve allocation allowed reentrant vault deposit");
        assertTrue(callback.callbackError() == bytes4(keccak256("ReentrancyGuardReentrantCall()")), "Callback failed for another reason instead of the reentrancy guard");
        assertEq(guarded.totalAssets(), 100 ether, "Reentrant callback changed managed assets");
        assertEq(guarded.totalSupply(), 100 ether, "Reentrant callback changed outstanding shares");
    }

    function testFuzzRebalanceRespectsLimitsAndConservesAssets(uint96 amountSeed, uint16 targetSeed,
        uint96 capSeed, uint96 budgetSeed) public
    {
        uint256 amount = uint256(amountSeed) % (500 ether) + 1 ether;
        uint16 target = uint16(uint256(targetSeed) % 8001);
        uint256 moveLimit = uint256(capSeed) % amount + 1;
        uint256 budget = moveLimit + uint256(budgetSeed) % amount;
        depositAlice(amount);
        configure(target, moveLimit, budget);
        (,uint256 preview,DynamicaStrategyVault.BlockReason reason) = vault.previewRebalance();
        if (reason == DynamicaStrategyVault.BlockReason.Ready) {
            uint256 moved = rebalance();
            assertEq(moved, preview, "Execution diverges from fresh preview");
            assertTrue(moved <= moveLimit, "Execution exceeds per-call cap");
            assertTrue(moved <= budget, "Execution exceeds window cap");
            assertEq(vault.windowSpent(), moved, "Window accounting diverges from movement");
        } else {
            assertTrue(reason == DynamicaStrategyVault.BlockReason.AtTarget, "Unexpected initial block reason");
        }
        assertConservation(amount);
        assertEq(vault.maxWithdraw(ALICE), amount, "Allocation changed withdrawable principal");
        vm.prank(ALICE);
        vault.withdraw(amount, ALICE, ALICE);
        assertConservation(0);
    }

    function testFuzzRepeatedMovesNeverExceedWindowBudget(uint96 amountSeed, uint96 moveSeed,
        uint96 budgetSeed) public
    {
        uint256 amount = uint256(amountSeed) % (500 ether) + 10 ether;
        uint256 moveLimit = uint256(moveSeed) % (amount / 5) + 1;
        uint256 budget = moveLimit + uint256(budgetSeed) % (amount / 2);
        depositAlice(amount);
        configure(8000, moveLimit, budget);
        uint256 aggregate;
        for (uint256 i; i < 10; i++) {
            (,,DynamicaStrategyVault.BlockReason reason) = vault.previewRebalance();
            if (reason != DynamicaStrategyVault.BlockReason.Ready) break;
            aggregate += rebalance();
            assertTrue(aggregate <= budget, "Repeated calls exceeded cumulative budget");
            assertEq(vault.windowSpent(), aggregate, "Window spend lost an execution");
            assertConservation(amount);
            vm.warp(block.timestamp + 60);
        }
        assertEq(vault.maxWithdraw(ALICE), amount, "Repeated moves changed shareholder principal");
    }
}
