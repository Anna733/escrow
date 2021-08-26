// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract ERC20Stub is ERC20Upgradeable {
  function initialize() public virtual initializer {
    __ERC20_init("Test", "TST");
  }

  function mint(address _to, uint256 _amount) external {
    _mint(_to, _amount);
  }
}
