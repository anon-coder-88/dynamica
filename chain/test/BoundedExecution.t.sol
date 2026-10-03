// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TestSupport} from "./TestSupport.sol";
import {DynamicaStrategyVault} from "../contracts/DynamicaStrategyVault.sol";

contract BoundedExecutionTest is TestSupport {
    uint256 internal requestVersion = 1;

    function setUp() public override {
        super.setUp();
        depositAlice(100 ether);
        configure(8000, 10 ether, 50 ether);
    }

    function execute(uint256 sequence, uint256 minimum, uint256 maximum, uint256 deadline)
        internal
        returns (uint256)
    {
        uint256 version = requestVersion;
        vm.prank(KEEPER);
        return vault.rebalanceWithBounds(version, sequence, minimum, maximum, deadline);
    }

    function testBoundedExecutionRecordsExactlyOneMovement() public {
        assertEq(execute(0, 10 ether, 10 ether, block.timestamp), 10 ether);
        assertEq(vault.executionCount(), 1);
        assertEq(vault.windowSpent(), 10 ether);
        assertEq(reserve.totalAssets(), 10 ether);
        assertConservation(100 ether);
    }

    function testReplayRejectedEvenAfterCooldown() public {
        uint256 deadline = block.timestamp + 600;
        execute(0, 1, 10 ether, deadline);
        vm.warp(block.timestamp + 60);
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.StaleExecution.selector, 0, 1));
        execute(0, 1, 10 ether, deadline);
        assertEq(vault.windowSpent(), 10 ether);
        assertEq(vault.executionCount(), 1);
    }

    function testLegacyExecutionInvalidatesPreparedBoundedRequest() public {
        rebalance();
        vm.warp(block.timestamp + 60);
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.StaleExecution.selector, 0, 1));
        execute(0, 1, 10 ether, block.timestamp + 1);
    }

    function testUpperBoundFailureRollsBackTransfersAndBudget() public {
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.Slippage.selector, 9 ether, 10 ether));
        execute(0, 1, 9 ether, block.timestamp);
        assertEq(vault.executionCount(), 0);
        assertEq(vault.windowSpent(), 0);
        assertEq(reserve.totalAssets(), 0);
        assertEq(token.allowance(address(vault), address(reserve)), 0);
        assertConservation(100 ether);
    }

    function testExpiredRequestRejectsAtOneSecondAfterDeadline() public {
        uint256 deadline = block.timestamp;
        vm.warp(deadline + 1);
        vm.expectRevert(DynamicaStrategyVault.ExpiredRequest.selector);
        execute(0, 1, 10 ether, deadline);
        assertEq(vault.executionCount(), 0);
    }

    function testInvalidBoundsRejectZeroAndInvertedRange() public {
        vm.expectRevert(DynamicaStrategyVault.InvalidBounds.selector);
        execute(0, 0, 10 ether, block.timestamp);
        vm.expectRevert(DynamicaStrategyVault.InvalidBounds.selector);
        execute(0, 10 ether, 9 ether, block.timestamp);
    }

    function testBoundedExecutionStillRequiresOperatorAndCurrentPolicy() public {
        vm.expectRevert(DynamicaStrategyVault.OnlyOperator.selector);
        vm.prank(OUTSIDER);
        vault.rebalanceWithBounds(1, 0, 1, 10 ether, block.timestamp);
        configure(7000, 10 ether, 50 ether);
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.StalePolicy.selector, 1, 2));
        vm.prank(KEEPER);
        vault.rebalanceWithBounds(1, 0, 1, 10 ether, block.timestamp);
    }

    function testReconfigurationDoesNotResetSequence() public {
        execute(0, 1, 10 ether, block.timestamp);
        configure(7000, 10 ether, 50 ether);
        requestVersion = 2;
        assertEq(vault.executionCount(), 1);
        vm.expectRevert(abi.encodeWithSelector(DynamicaStrategyVault.StaleExecution.selector, 0, 1));
        execute(0, 1, 10 ether, block.timestamp);
        execute(1, 1, 10 ether, block.timestamp);
        assertEq(vault.executionCount(), 2);
    }

    function testFuzzCallerBoundsConserveAssets(uint96 minimumSeed, uint96 maximumSeed) public {
        uint256 minimum = bound(minimumSeed, 1, 10 ether);
        uint256 maximum = bound(maximumSeed, minimum, 20 ether);
        if (maximum < 10 ether) {
            vm.expectRevert(
                abi.encodeWithSelector(DynamicaStrategyVault.Slippage.selector, maximum, 10 ether)
            );
            execute(0, minimum, maximum, block.timestamp);
            assertEq(vault.executionCount(), 0);
            assertEq(reserve.totalAssets(), 0);
        } else {
            execute(0, minimum, maximum, block.timestamp);
            assertEq(vault.executionCount(), 1);
            assertEq(reserve.totalAssets(), 10 ether);
        }
        assertConservation(100 ether);
    }
}
