// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Accessible is AccessControlUpgradeable {
  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
  address private _pendingOwner;
  address private _previousOwner;

  function initialize(address owner) public initializer {
    _setupRole(DEFAULT_ADMIN_ROLE, owner);
  }

  modifier onlyOperator() {
    require(
      isOperator(_msgSender()),
      "Accessible: Only the operator of this contract is allowed to make this call"
    );
    _;
  }

  modifier onlyOwner() {
    require(
      isOwner(_msgSender()),
      "Accessible: Only the admin of this contract is allowed to make this call"
    );
    _;
  }

  function isOperator(address operator) public view returns (bool) {
    return hasRole(OPERATOR_ROLE, operator);
  }

  function isOwner(address owner) public view returns (bool) {
    return hasRole(DEFAULT_ADMIN_ROLE, owner);
  }

  function addOperator(address operator) public onlyOwner {
    grantRole(OPERATOR_ROLE, operator);
  }

  function removeOperator(address operator) public onlyOwner {
    revokeRole(OPERATOR_ROLE, operator);
  }

  function transferOwnership(address pendingOwner) public onlyOwner {
    _previousOwner = msg.sender;
    _pendingOwner = pendingOwner;
  }

  function acceptOwnership() public {
    require(msg.sender == _pendingOwner);
    _setupRole(DEFAULT_ADMIN_ROLE, _pendingOwner);
    revokeRole(DEFAULT_ADMIN_ROLE, _previousOwner);
  }
}
