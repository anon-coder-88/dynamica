// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Liquid reserve controlled exclusively by its creating vault.
/// @dev It has no owner, trading permissions, fees or yield promise.
contract DynamicaReserve {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    address public immutable vault;

    error OnlyVault();
    error InvalidAsset();
    error UnsupportedTransfer();

    event Allocated(uint256 assets);
    event Recalled(uint256 assets);

    constructor(IERC20 asset_) {
        if (address(asset_).code.length == 0) revert InvalidAsset();
        asset = asset_;
        vault = msg.sender;
    }

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    function totalAssets() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    // Check actual receipt: fee-on-transfer assets are not supported.
    function allocate(uint256 assets) external onlyVault {
        uint256 beforeBalance = asset.balanceOf(address(this));
        asset.safeTransferFrom(vault, address(this), assets);
        if (asset.balanceOf(address(this)) - beforeBalance != assets) {
            revert UnsupportedTransfer();
        }
        emit Allocated(assets);
    }

    // Recall always returns to the vault; an operator cannot choose a recipient.
    function recall(uint256 assets) external onlyVault {
        uint256 beforeBalance = asset.balanceOf(vault);
        asset.safeTransfer(vault, assets);
        if (asset.balanceOf(vault) - beforeBalance != assets) {
            revert UnsupportedTransfer();
        }
        emit Recalled(assets);
    }
}
