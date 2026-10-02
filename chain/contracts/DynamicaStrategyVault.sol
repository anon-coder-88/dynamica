// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DynamicaVault} from "./DynamicaVault.sol";
import {DynamicaReserve} from "./DynamicaReserve.sol";

/// @notice Capped ERC-4626 vault with bounded idle/reserve rebalancing.
/// @dev Only the fixed, fully liquid reserve is an execution destination.
/// There is no arbitrary call, swap, borrowing, external investment or yield.
contract DynamicaStrategyVault is DynamicaVault, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_RESERVE_BPS = 8_000;
    uint256 public constant MIN_WINDOW = 1 hours;
    uint256 public constant MAX_WINDOW = 30 days;

    struct Policy {
        address operator;
        uint16 reserveBps;
        uint64 minInterval;
        uint64 windowDuration;
        uint64 expiresAt;
        uint256 maxMove;
        uint256 windowLimit;
    }

    enum BlockReason {
        Ready,
        Paused,
        NoOperator,
        Expired,
        Cooldown,
        WindowExhausted,
        AtTarget
    }

    DynamicaReserve public immutable reserve;
    Policy public policy;
    uint256 public policyVersion;
    bool public executionPaused;
    uint256 public lastExecutionAt;
    uint256 public windowStartedAt;
    uint256 public windowSpent;
    uint256 public executionCount;

    error InvalidPolicy();
    error OnlyOperator();
    error StalePolicy(uint256 expected, uint256 actual);
    error ExecutionBlocked(BlockReason reason);
    error Slippage(uint256 minimum, uint256 actual);
    error ZeroAmount();
    error UnsupportedTransfer();

    event PolicyConfigured(uint256 indexed version, address indexed operator, uint16 reserveBps,
        uint64 minInterval, uint64 windowDuration, uint64 expiresAt, uint256 maxMove, uint256 windowLimit);
    event OperatorRevoked(uint256 indexed version);
    event ExecutionPaused(bool paused);
    event Rebalanced(uint256 indexed sequence, uint256 indexed version, address indexed operator,
        bool toReserve, uint256 assets, uint256 idleAfter, uint256 reserveAfter);
    event ReserveRecalledForWithdrawal(uint256 assets);

    constructor(IERC20 asset_, uint256 cap_, address owner_)
        DynamicaVault(asset_, cap_, owner_)
    {
        reserve = new DynamicaReserve(asset_);
    }

    // Include both custody locations; share conversions see the complete balance.
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + reserve.totalAssets();
    }

    function idleAssets() public view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /// @notice Owner authorizes only this narrow reserve strategy.
    /// @dev A new version resets its budget. Policy changes are immediately effective.
    function configurePolicy(Policy calldata next) external onlyOwner {
        if (
            next.operator == address(0) || next.reserveBps > MAX_RESERVE_BPS
                || next.windowDuration < MIN_WINDOW || next.windowDuration > MAX_WINDOW
                || next.minInterval == 0 || next.minInterval > next.windowDuration
                || next.expiresAt <= block.timestamp || next.maxMove == 0
                || next.windowLimit < next.maxMove
        ) revert InvalidPolicy();
        policy = next;
        policyVersion++;
        windowStartedAt = block.timestamp;
        windowSpent = 0;
        lastExecutionAt = 0;
        emit PolicyConfigured(policyVersion, next.operator, next.reserveBps, next.minInterval,
            next.windowDuration, next.expiresAt, next.maxMove, next.windowLimit);
    }

    // Existing assets remain redeemable after revocation or either pause control.
    function revokeOperator() external onlyOwner {
        policy.operator = address(0);
        policyVersion++;
        emit OperatorRevoked(policyVersion);
    }

    function setExecutionPaused(bool paused) external onlyOwner {
        executionPaused = paused;
        emit ExecutionPaused(paused);
    }

    function windowRemaining() public view returns (uint256) {
        if (policy.windowDuration == 0) return 0;
        if (block.timestamp >= windowStartedAt + policy.windowDuration) return policy.windowLimit;
        return windowSpent >= policy.windowLimit ? 0 : policy.windowLimit - windowSpent;
    }

    /// @notice Inspect direction, bounded amount, and a machine-readable block reason.
    function previewRebalance() public view returns (bool toReserve, uint256 assets, BlockReason reason) {
        if (executionPaused) return (false, 0, BlockReason.Paused);
        Policy memory p = policy;
        if (p.operator == address(0)) return (false, 0, BlockReason.NoOperator);
        if (block.timestamp >= p.expiresAt) return (false, 0, BlockReason.Expired);
        if (lastExecutionAt != 0 && block.timestamp < lastExecutionAt + p.minInterval) {
            return (false, 0, BlockReason.Cooldown);
        }
        uint256 remaining = windowRemaining();
        if (remaining == 0) return (false, 0, BlockReason.WindowExhausted);
        uint256 held = reserve.totalAssets();
        uint256 target = Math.mulDiv(totalAssets(), p.reserveBps, BPS);
        if (held == target) return (false, 0, BlockReason.AtTarget);
        toReserve = target > held;
        uint256 difference = toReserve ? target - held : held - target;
        assets = Math.min(difference, Math.min(p.maxMove, remaining));
        return (toReserve, assets, BlockReason.Ready);
    }

    /// @notice Operators submit ordinary transactions; external scheduling is required.
    /// @param expectedVersion Reject a transaction prepared for an old policy.
    /// @param minMoved Protect the caller against a changed balance/preview.
    function rebalance(uint256 expectedVersion, uint256 minMoved) external nonReentrant returns (uint256 assets) {
        if (msg.sender != policy.operator) revert OnlyOperator();
        if (expectedVersion != policyVersion) revert StalePolicy(expectedVersion, policyVersion);
        bool toReserve;
        BlockReason reason;
        (toReserve, assets, reason) = previewRebalance();
        if (reason != BlockReason.Ready) revert ExecutionBlocked(reason);
        if (assets < minMoved) revert Slippage(minMoved, assets);

        if (block.timestamp >= windowStartedAt + policy.windowDuration) {
            // Fixed windows anchored to policy creation, with no carried-over credit.
            uint256 elapsed = (block.timestamp - windowStartedAt) / policy.windowDuration;
            windowStartedAt += elapsed * policy.windowDuration;
            windowSpent = 0;
        }
        windowSpent += assets;
        lastExecutionAt = block.timestamp;
        executionCount++;
        IERC20 token = IERC20(asset());
        if (toReserve) {
            token.forceApprove(address(reserve), assets);
            reserve.allocate(assets);
            token.forceApprove(address(reserve), 0);
        } else {
            reserve.recall(assets);
        }
        emit Rebalanced(executionCount, policyVersion, msg.sender, toReserve, assets,
            idleAssets(), reserve.totalAssets());
    }

    // Guard every standard ERC-4626 write, including delegated withdrawals.
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256) {
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner_) public override nonReentrant returns (uint256) {
        return super.withdraw(assets, receiver, owner_);
    }

    function redeem(uint256 shares, address receiver, address owner_) public override nonReentrant returns (uint256) {
        return super.redeem(shares, receiver, owner_);
    }

    // Optional bounds for callers requiring on-chain protection of a preview.
    function depositWithMinShares(uint256 assets, address receiver, uint256 minShares) external returns (uint256 shares) {
        shares = deposit(assets, receiver);
        if (shares < minShares) revert Slippage(minShares, shares);
    }

    function redeemWithMinAssets(uint256 shares, address receiver, address owner_, uint256 minAssets)
        external returns (uint256 assets)
    {
        assets = redeem(shares, receiver, owner_);
        if (assets < minAssets) revert Slippage(minAssets, assets);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        if (assets == 0 || shares == 0) revert ZeroAmount();
        uint256 beforeBalance = idleAssets();
        super._deposit(caller, receiver, assets, shares);
        if (idleAssets() - beforeBalance != assets) revert UnsupportedTransfer();
    }

    function _withdraw(address caller, address receiver, address owner_, uint256 assets, uint256 shares)
        internal override
    {
        if (assets == 0 || shares == 0) revert ZeroAmount();
        uint256 idle = idleAssets();
        if (assets > idle) {
            uint256 shortfall = assets - idle;
            reserve.recall(shortfall);
            emit ReserveRecalledForWithdrawal(shortfall);
        }
        uint256 beforeBalance = IERC20(asset()).balanceOf(receiver);
        super._withdraw(caller, receiver, owner_, assets, shares);
        if (IERC20(asset()).balanceOf(receiver) - beforeBalance != assets) revert UnsupportedTransfer();
    }
}
