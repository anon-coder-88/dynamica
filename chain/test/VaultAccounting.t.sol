// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TestSupport, MockAsset, FeeAsset, ReenterAsset, FalseReturnAsset} from "./TestSupport.sol";
import {DynamicaStrategyVault} from "../contracts/DynamicaStrategyVault.sol";

contract VaultAccountingTest is TestSupport {
    function testDepositIssuesSharesAndAccountsForAssets() public {
        uint256 beforeBalance = token.balanceOf(ALICE);
        uint256 preview = vault.previewDeposit(100 ether);
        uint256 issued = depositAlice(100 ether);
        assertEq(issued, preview, "Deposit must match its fresh preview");
        assertEq(vault.balanceOf(ALICE), 100 ether, "First deposit must issue one share per asset");
        assertEq(vault.totalSupply(), issued, "Supply must include the new shares");
        assertEq(token.balanceOf(ALICE), beforeBalance - 100 ether, "User asset balance not debited");
        assertConservation(100 ether);
    }

    function testDepositCanMintSharesToAnotherReceiver() public {
        vm.prank(ALICE);
        uint256 shares = vault.deposit(50 ether, BOB);
        assertEq(vault.balanceOf(ALICE), 0, "Payer must not receive shares when a receiver is given");
        assertEq(vault.balanceOf(BOB), shares, "Receiver must own minted shares");
        assertEq(vault.maxWithdraw(BOB), 50 ether, "Receiver owns the withdrawal claim");
        assertConservation(50 ether);
    }

    function testMintChargesPreviewedAssets() public {
        depositAlice(100 ether);
        token.mint(address(vault), 50 ether);
        uint256 assets = vault.previewMint(10 ether);
        uint256 beforeBalance = token.balanceOf(BOB);
        vm.prank(BOB);
        uint256 spent = vault.mint(10 ether, BOB);
        assertEq(spent, assets, "Mint must round its asset cost as previewed");
        assertEq(beforeBalance - token.balanceOf(BOB), assets, "Mint cost does not match actual transfer");
        assertEq(vault.balanceOf(BOB), 10 ether, "Mint did not issue the requested shares");
    }

    function testWithdrawBurnsPreviewedShares() public {
        depositAlice(100 ether);
        uint256 burnedPreview = vault.previewWithdraw(25 ether);
        uint256 beforeShares = vault.balanceOf(ALICE);
        vm.prank(ALICE);
        uint256 burned = vault.withdraw(25 ether, ALICE, ALICE);
        assertEq(burned, burnedPreview, "Withdraw burn must match its preview");
        assertEq(vault.balanceOf(ALICE), beforeShares - burned, "Burned shares remain in the account");
        assertEq(token.balanceOf(ALICE), 925 ether, "Withdrawal was not returned to the receiver");
        assertConservation(75 ether);
    }

    function testRedeemBurnsAllShares() public {
        depositAlice(100 ether);
        uint256 shares = vault.balanceOf(ALICE);
        uint256 preview = vault.previewRedeem(shares);
        vm.prank(ALICE);
        uint256 assets = vault.redeem(shares, ALICE, ALICE);
        assertEq(assets, preview, "Redeem assets must match their preview");
        assertEq(vault.totalSupply(), 0, "Full redemption left outstanding shares");
        assertEq(token.balanceOf(ALICE), 1000 ether, "Full redemption lost principal");
        assertConservation(0);
    }

    function testCannotWithdrawAnotherUsersShares() public {
        depositAlice(100 ether);
        vm.expectRevert();
        vm.prank(OUTSIDER);
        vault.withdraw(1 ether, OUTSIDER, ALICE);
        assertEq(vault.balanceOf(ALICE), 100 ether, "Unauthorized withdrawal changed owner shares");
        assertConservation(100 ether);
    }

    function testDelegatedWithdrawalConsumesShareAllowance() public {
        depositAlice(100 ether);
        vm.prank(ALICE);
        vault.approve(BOB, 30 ether);
        vm.prank(BOB);
        vault.withdraw(20 ether, BOB, ALICE);
        assertEq(vault.allowance(ALICE, BOB), 10 ether, "Delegated withdrawal did not consume allowance");
        assertEq(token.balanceOf(BOB), 1020 ether, "Authorized receiver did not receive assets");
        assertEq(vault.balanceOf(ALICE), 80 ether, "Owner shares not burned for delegation");
    }

    function testDelegatedRedeemCannotExceedAllowance() public {
        depositAlice(100 ether);
        vm.prank(ALICE);
        vault.approve(BOB, 5 ether);
        vm.expectRevert();
        vm.prank(BOB);
        vault.redeem(6 ether, BOB, ALICE);
        assertEq(vault.allowance(ALICE, BOB), 5 ether, "Revert changed allowance");
        assertEq(vault.balanceOf(ALICE), 100 ether, "Revert burned shares");
    }

    function testShareTransferMovesWithdrawalRights() public {
        depositAlice(100 ether);
        vm.prank(ALICE);
        vault.transfer(BOB, 40 ether);
        assertEq(vault.maxWithdraw(ALICE), 60 ether, "Sender retains transferred withdrawal rights");
        assertEq(vault.maxWithdraw(BOB), 40 ether, "Receiver lacks transferred withdrawal rights");
        vm.prank(BOB);
        vault.withdraw(40 ether, BOB, BOB);
        assertConservation(60 ether);
    }

    function testCapBlocksDepositWithoutPartialMutation() public {
        vault.setAssetCap(100 ether);
        depositAlice(90 ether);
        uint256 beforeBalance = token.balanceOf(BOB);
        vm.expectRevert();
        vm.prank(BOB);
        vault.deposit(11 ether, BOB);
        assertEq(token.balanceOf(BOB), beforeBalance, "Failed deposit consumed user assets");
        assertEq(vault.balanceOf(BOB), 0, "Failed deposit minted shares");
        assertEq(vault.maxDeposit(BOB), 10 ether, "Capacity changed after failure");
    }

    function testCapIncludesAssetsInReserve() public {
        vault.setAssetCap(100 ether);
        depositAlice(100 ether);
        configure(8000, 100 ether, 100 ether);
        rebalance();
        assertEq(vault.idleAssets(), 20 ether, "Test requires allocated reserve");
        assertEq(vault.maxDeposit(BOB), 0, "Allocated reserve incorrectly creates spare capacity");
        vm.expectRevert();
        vm.prank(BOB);
        vault.deposit(1, BOB);
        assertConservation(100 ether);
    }

    function testOwnerCannotLowerCapBelowManagedAssets() public {
        depositAlice(100 ether);
        configure(5000, 100 ether, 100 ether);
        rebalance();
        vm.expectRevert();
        vault.setAssetCap(99 ether);
        assertEq(vault.assetCap(), 1000 ether, "Rejected cap changed state");
    }

    function testOwnerCanIncreaseCapAndRestoreCapacity() public {
        vault.setAssetCap(100 ether);
        depositAlice(100 ether);
        vault.setAssetCap(200 ether);
        assertEq(vault.maxDeposit(BOB), 100 ether, "New capacity is not reflected");
        vm.prank(BOB);
        vault.deposit(100 ether, BOB);
        assertConservation(200 ether);
    }

    function testZeroCapCanCloseAnEmptyVault() public {
        vault.setAssetCap(0);
        assertEq(vault.maxDeposit(ALICE), 0, "Zero cap must close deposits");
        assertEq(vault.maxMint(ALICE), 0, "Zero cap must close share minting");
        vault.setAssetCap(10 ether);
        depositAlice(10 ether);
        assertConservation(10 ether);
    }

    function testDepositPauseBlocksBothDepositAndMint() public {
        vault.setDepositsPaused(true);
        assertEq(vault.maxDeposit(ALICE), 0, "Paused maxDeposit must be zero");
        assertEq(vault.maxMint(ALICE), 0, "Paused maxMint must be zero");
        vm.expectRevert();
        vm.prank(ALICE);
        vault.deposit(1 ether, ALICE);
        vm.expectRevert();
        vm.prank(ALICE);
        vault.mint(1 ether, ALICE);
        assertConservation(0);
    }

    function testDepositPauseDoesNotBlockWithdrawal() public {
        depositAlice(100 ether);
        configure(8000, 100 ether, 100 ether);
        rebalance();
        vault.setDepositsPaused(true);
        vm.prank(ALICE);
        vault.withdraw(100 ether, ALICE, ALICE);
        assertConservation(0);
        assertEq(vault.balanceOf(ALICE), 0, "Paused withdrawal did not burn shares");
    }

    function testWithdrawRecallsOnlyItsShortfall() public {
        depositAlice(100 ether);
        configure(8000, 100 ether, 100 ether);
        rebalance();
        vm.prank(ALICE);
        vault.withdraw(30 ether, ALICE, ALICE);
        assertEq(vault.idleAssets(), 0, "Withdrawal should consume available idle assets first");
        assertEq(reserve.totalAssets(), 70 ether, "Withdrawal recalled more than its shortfall");
        assertConservation(70 ether);
    }

    function testWithdrawalWithinIdleDoesNotRecallReserve() public {
        depositAlice(100 ether);
        configure(5000, 100 ether, 100 ether);
        rebalance();
        vm.prank(ALICE);
        vault.withdraw(10 ether, ALICE, ALICE);
        assertEq(reserve.totalAssets(), 50 ether, "Idle withdrawal unexpectedly recalled reserve");
        assertEq(vault.idleAssets(), 40 ether, "Idle balance does not reflect withdrawal");
        assertConservation(90 ether);
    }

    function testDepositSlippageBoundRevertsWholeTransfer() public {
        uint256 beforeBalance = token.balanceOf(ALICE);
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.Slippage.selector, 11 ether, 10 ether));
        vm.prank(ALICE);
        vault.depositWithMinShares(10 ether, ALICE, 11 ether);
        assertEq(token.balanceOf(ALICE), beforeBalance, "Failed slippage check consumed assets");
        assertEq(vault.balanceOf(ALICE), 0, "Failed slippage check minted shares");
        assertConservation(0);
    }

    function testDepositSlippageBoundAllowsExactPreview() public {
        uint256 preview = vault.previewDeposit(10 ether);
        vm.prank(ALICE);
        uint256 shares = vault.depositWithMinShares(10 ether, ALICE, preview);
        assertEq(shares, preview, "Exact minimum should allow deposit");
        assertConservation(10 ether);
    }

    function testRedeemSlippageBoundRevertsBurnAndRecall() public {
        depositAlice(100 ether);
        configure(8000, 100 ether, 100 ether);
        rebalance();
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.Slippage.selector, 101 ether, 100 ether));
        vm.prank(ALICE);
        vault.redeemWithMinAssets(100 ether, ALICE, ALICE, 101 ether);
        assertEq(vault.balanceOf(ALICE), 100 ether, "Slippage revert must restore burned shares");
        assertEq(reserve.totalAssets(), 80 ether, "Slippage revert must restore reserve recall");
        assertEq(vault.idleAssets(), 20 ether, "Slippage revert must restore idle balance");
        assertConservation(100 ether);
    }

    function testDonationIncreasesShareValueWithoutMinting() public {
        depositAlice(100 ether);
        token.mint(address(vault), 50 ether);
        assertEq(vault.totalSupply(), 100 ether, "Donation minted shares");
        assertTrue(vault.maxWithdraw(ALICE) > 149 ether, "Donation does not accrue to existing shareholders");
        assertConservation(150 ether);
    }

    function testReserveDonationIsIncludedInShareValue() public {
        depositAlice(100 ether);
        token.mint(address(reserve), 25 ether);
        assertConservation(125 ether);
        assertTrue(
            vault.previewRedeem(vault.balanceOf(ALICE)) > 124 ether,
            "Reserve donation was omitted from share valuation"
        );
    }

    function testSixDecimalAssetUsesItsOwnUnits() public {
        MockAsset usdc = new MockAsset(6);
        DynamicaStrategyVault small = new DynamicaStrategyVault(IERC20(address(usdc)), 1000e6, address(this));
        usdc.mint(ALICE, 100e6);
        vm.startPrank(ALICE);
        usdc.approve(address(small), 100e6);
        uint256 shares = small.deposit(100e6, ALICE);
        assertEq(shares, 100e6, "Share units should follow six-decimal asset");
        assertEq(small.decimals(), 6, "Share decimals must follow asset decimals");
        small.withdraw(100e6, ALICE, ALICE);
        vm.stopPrank();
        assertEq(usdc.balanceOf(ALICE), 100e6, "Six-decimal withdrawal lost value");
    }

    function testZeroDepositAndZeroRedeemAreRejected() public {
        vm.expectRevert(DynamicaStrategyVault.ZeroAmount.selector);
        vm.prank(ALICE);
        vault.deposit(0, ALICE);
        depositAlice(1 ether);
        vm.expectRevert(DynamicaStrategyVault.ZeroAmount.selector);
        vm.prank(ALICE);
        vault.redeem(0, ALICE, ALICE);
        assertConservation(1 ether);
    }

    function testDustDepositCannotDonateAssetsForZeroShares() public {
        depositAlice(1);
        token.mint(address(vault), 1 ether);
        vm.expectRevert(DynamicaStrategyVault.ZeroAmount.selector);
        vm.prank(BOB);
        vault.deposit(1, BOB);
        assertEq(vault.balanceOf(BOB), 0, "Dust deposit unexpectedly minted shares");
        assertEq(token.balanceOf(BOB), 1000 ether, "Dust deposit must return payer assets by reverting");
    }

    function testFeeOnTransferDepositIsRejectedAtomically() public {
        FeeAsset fee = new FeeAsset();
        DynamicaStrategyVault taxed =
            new DynamicaStrategyVault(IERC20(address(fee)), 1000 ether, address(this));
        fee.mint(ALICE, 100 ether);
        fee.setFees(true);
        vm.prank(ALICE);
        fee.approve(address(taxed), 100 ether);
        vm.expectRevert(DynamicaStrategyVault.UnsupportedTransfer.selector);
        vm.prank(ALICE);
        taxed.deposit(100 ether, ALICE);
        assertEq(fee.balanceOf(ALICE), 100 ether, "Taxed deposit revert must restore asset balance");
        assertEq(taxed.totalSupply(), 0, "Taxed deposit minted unbacked shares");
        assertEq(taxed.totalAssets(), 0, "Taxed deposit revert left assets behind");
    }

    function testFeeOnTransferWithdrawalCannotBurnSharesForLessAssets() public {
        FeeAsset fee = new FeeAsset();
        DynamicaStrategyVault taxed =
            new DynamicaStrategyVault(IERC20(address(fee)), 1000 ether, address(this));
        fee.mint(ALICE, 100 ether);
        vm.startPrank(ALICE);
        fee.approve(address(taxed), 100 ether);
        taxed.deposit(100 ether, ALICE);
        vm.stopPrank();
        fee.setFees(true);
        vm.expectRevert(DynamicaStrategyVault.UnsupportedTransfer.selector);
        vm.prank(ALICE);
        taxed.withdraw(100 ether, ALICE, ALICE);
        assertEq(taxed.balanceOf(ALICE), 100 ether, "Taxed withdrawal must restore burned shares");
        assertEq(taxed.totalAssets(), 100 ether, "Taxed withdrawal must restore custody assets");
    }

    function testFalseReturningAssetFailsSafeTransfer() public {
        FalseReturnAsset bad = new FalseReturnAsset();
        DynamicaStrategyVault invalid =
            new DynamicaStrategyVault(IERC20(address(bad)), 1000 ether, address(this));
        bad.mint(ALICE, 100 ether);
        vm.prank(ALICE);
        bad.approve(address(invalid), 100 ether);
        vm.expectRevert();
        vm.prank(ALICE);
        invalid.deposit(100 ether, ALICE);
        assertEq(invalid.totalSupply(), 0, "False-returning token minted shares");
    }

    function testReentrantDepositCallbackIsBlocked() public {
        ReenterAsset callback = new ReenterAsset();
        DynamicaStrategyVault guarded =
            new DynamicaStrategyVault(IERC20(address(callback)), 1000 ether, address(this));
        callback.mint(ALICE, 100 ether);
        callback.arm(address(guarded));
        vm.startPrank(ALICE);
        callback.approve(address(guarded), 100 ether);
        guarded.deposit(100 ether, ALICE);
        vm.stopPrank();
        assertTrue(callback.attempted(), "Malicious asset never attempted its callback");
        assertTrue(callback.blocked(), "Reentrant deposit callback was not blocked");
        assertTrue(
            callback.callbackError() == bytes4(keccak256("ReentrancyGuardReentrantCall()")),
            "Callback failed for another reason instead of the reentrancy guard"
        );
        assertEq(guarded.totalAssets(), 100 ether, "Reentrant attempt broke asset accounting");
        assertEq(guarded.totalSupply(), 100 ether, "Reentrant attempt broke share accounting");
    }

    function testReentrantWithdrawalCallbackIsBlocked() public {
        ReenterAsset callback = new ReenterAsset();
        DynamicaStrategyVault guarded =
            new DynamicaStrategyVault(IERC20(address(callback)), 1000 ether, address(this));
        callback.mint(ALICE, 100 ether);
        vm.startPrank(ALICE);
        callback.approve(address(guarded), 100 ether);
        guarded.deposit(100 ether, ALICE);
        vm.stopPrank();
        callback.arm(address(guarded));
        vm.prank(ALICE);
        guarded.withdraw(100 ether, ALICE, ALICE);
        assertTrue(callback.blocked(), "Reentrant withdrawal callback was not blocked");
        assertTrue(
            callback.callbackError() == bytes4(keccak256("ReentrancyGuardReentrantCall()")),
            "Callback failed for another reason instead of the reentrancy guard"
        );
        assertEq(guarded.totalAssets(), 0, "Callback left assets after full withdrawal");
        assertEq(guarded.totalSupply(), 0, "Callback left shares after full withdrawal");
    }

    function testMaxMintDoesNotExceedAssetCapacityAfterDonation() public {
        depositAlice(100 ether);
        token.mint(address(vault), 25 ether);
        vault.setAssetCap(150 ether);
        uint256 maxShares = vault.maxMint(BOB);
        assertTrue(vault.previewMint(maxShares) <= 25 ether, "maxMint exceeds available capacity");
        vm.prank(BOB);
        vault.mint(maxShares, BOB);
        assertTrue(vault.totalAssets() <= vault.assetCap(), "Mint crossed asset cap");
    }

    function testFuzzDepositWithdrawConservesPrincipal(uint96 seed) public {
        uint256 assets = uint256(seed) % (999 ether) + 1;
        depositAlice(assets);
        uint256 shares = vault.balanceOf(ALICE);
        vm.prank(ALICE);
        uint256 returned = vault.redeem(shares, ALICE, ALICE);
        assertEq(returned, assets, "Deposit/redeem cycle lost principal");
        assertEq(token.balanceOf(ALICE), 1000 ether, "Round trip changed user balance");
        assertConservation(0);
    }

    function testFuzzTwoUsersCannotWithdrawEachOthersPrincipal(uint96 first, uint96 second) public {
        uint256 a = uint256(first) % (400 ether) + 1;
        uint256 b = uint256(second) % (400 ether) + 1;
        depositAlice(a);
        vm.prank(BOB);
        vault.deposit(b, BOB);
        uint256 aliceShares = vault.balanceOf(ALICE);
        vm.prank(ALICE);
        vault.redeem(aliceShares, ALICE, ALICE);
        assertEq(token.balanceOf(ALICE), 1000 ether, "First user round trip consumed second user assets");
        assertEq(vault.maxWithdraw(BOB), b, "Second user claim changed after first user exit");
        uint256 bobShares = vault.balanceOf(BOB);
        vm.prank(BOB);
        vault.redeem(bobShares, BOB, BOB);
        assertEq(token.balanceOf(BOB), 1000 ether, "Second user round trip changed its principal");
        assertConservation(0);
    }
}
