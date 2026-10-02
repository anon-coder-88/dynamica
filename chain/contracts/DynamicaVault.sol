// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Testnet MVP: capped, fully liquid asset custody with ERC-4626 shares.
/// @dev No strategy execution, yield, fees, or withdrawal queue is implemented.
contract DynamicaVault is ERC4626, Ownable {
    uint256 public assetCap;
    bool public depositsPaused;

    event AssetCapUpdated(uint256 cap);
    event DepositsPaused(bool paused);

    constructor(IERC20 asset_, uint256 cap_, address owner_)
        ERC20("Dynamica Vault Share", "DVS")
        ERC4626(asset_)
        Ownable(owner_)
    {
        require(address(asset_) != address(0), "Zero asset");
        require(cap_ > 0, "Zero cap");
        assetCap = cap_;
    }

    function setAssetCap(uint256 cap_) external onlyOwner {
        require(cap_ >= totalAssets(), "Below assets");
        assetCap = cap_;
        emit AssetCapUpdated(cap_);
    }

    function setDepositsPaused(bool paused_) external onlyOwner {
        depositsPaused = paused_;
        emit DepositsPaused(paused_);
    }

    function maxDeposit(address) public view override returns (uint256) {
        if (depositsPaused) return 0;
        uint256 assets = totalAssets();
        return assets >= assetCap ? 0 : assetCap - assets;
    }

    function maxMint(address receiver) public view override returns (uint256) {
        return convertToShares(maxDeposit(receiver));
    }
}
