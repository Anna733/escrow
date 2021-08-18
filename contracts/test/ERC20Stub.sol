// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract ERC20Stub is ERC20Upgradeable {
  function initialize(uint256 initialSupply) public virtual initializer {
    __ERC20_init("Test", "TST");
    _mint(msg.sender, initialSupply);
  }
}
