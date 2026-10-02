// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Valueless faucet asset for the Robinhood Chain testnet MVP only.
contract DynamicaTestAsset is ERC20 {
    mapping(address => bool) public claimed;
    uint256 public constant CLAIM_AMOUNT = 100 ether;

    constructor() ERC20("Dynamica Test Asset", "dTEST") {}

    function claim() external {
        require(!claimed[msg.sender], "Already claimed");
        claimed[msg.sender] = true;
        _mint(msg.sender, CLAIM_AMOUNT);
    }
}
