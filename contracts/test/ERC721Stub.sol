// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract ERC721Stub is ERC721Upgradeable {
  function initialize(uint256 tokenId) public virtual initializer {
    __ERC721_init("Test", "TST");
    _mint(msg.sender, tokenId);
  }
}
