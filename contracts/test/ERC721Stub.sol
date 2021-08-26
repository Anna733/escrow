// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract ERC721Stub is ERC721Upgradeable {
  function initialize() public virtual initializer {
    __ERC721_init("Test", "TST");
  }

  function mint(address _to, uint256 _tokenId) external {
    _mint(_to, _tokenId);
  }
}
