// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
/// @notice Fixed supply, 18 decimals, no privileged methods after deployment.
contract DynamicaToken is ERC20 {
    constructor(string memory name_, string memory symbol_, uint256 supply_, address recipient_) ERC20(name_, symbol_) {
        require(recipient_ != address(0), 'Zero recipient');
        require(supply_ > 0, 'Zero supply');
        _mint(recipient_, supply_);
    }
}
