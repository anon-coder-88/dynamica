// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DynamicaStrategyVault} from "./DynamicaStrategyVault.sol";

/// @notice Permissionless creation and discovery of independent strategy vaults.
/// @dev Registration is provenance, not an endorsement of an asset or its owner.
contract DynamicaVaultFactory {
    struct Record {
        address vault;
        address asset;
        address creator;
        uint64 createdAt;
    }

    Record[] private records;
    mapping(address => bool) public isVault;
    mapping(bytes32 => address) public vaultByKey;

    error InvalidAsset();
    error DuplicateSalt();
    error PageTooLarge();

    event VaultCreated(address indexed vault, address indexed asset, address indexed creator,
        bytes32 salt, uint256 assetCap);

    function createVault(IERC20 asset, uint256 cap, bytes32 salt) external returns (address deployed) {
        if (address(asset).code.length == 0) revert InvalidAsset();
        bytes32 key = keccak256(abi.encode(msg.sender, salt));
        if (vaultByKey[key] != address(0)) revert DuplicateSalt();
        deployed = address(new DynamicaStrategyVault{salt: key}(asset, cap, msg.sender));
        vaultByKey[key] = deployed;
        isVault[deployed] = true;
        records.push(Record(deployed, address(asset), msg.sender, uint64(block.timestamp)));
        emit VaultCreated(deployed, address(asset), msg.sender, salt, cap);
    }

    function predictVault(IERC20 asset, uint256 cap, address creator, bytes32 salt)
        external view returns (address)
    {
        bytes32 key = keccak256(abi.encode(creator, salt));
        bytes32 initHash = keccak256(abi.encodePacked(type(DynamicaStrategyVault).creationCode,
            abi.encode(asset, cap, creator)));
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), key, initHash)))));
    }

    function vaultCount() external view returns (uint256) {
        return records.length;
    }

    function vaultAt(uint256 index) external view returns (Record memory) {
        return records[index];
    }

    // Bound public enumeration so a large registry need not be fetched at once.
    function listVaults(uint256 offset, uint256 limit) external view returns (Record[] memory page) {
        if (limit > 100) revert PageTooLarge();
        if (offset >= records.length || limit == 0) return new Record[](0);
        uint256 length = records.length - offset;
        if (length > limit) length = limit;
        page = new Record[](length);
        for (uint256 i; i < length; i++) page[i] = records[offset + i];
    }
}
