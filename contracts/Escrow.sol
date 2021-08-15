// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;
import "./Accessible.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Escrow is Accessible {
  using SafeMath for uint256;

  address public buyer;
  address public seller;
  address public mediator;

  IERC20Upgradeable public token;
  IERC721Upgradeable public NFTtoken;

  enum State {
    AwaitingPayment,
    AwaitingDelivery,
    Complete
  }

  struct Trade {
    address buyer;
    address seller;
    address mediator;
    State tradeState;
  }


  modifier onlyMediator(uint256 _tradeIndex) {
    require(msg.sender == trades[_tradeIndex].mediator);
    _;
  }

  modifier onlySeller(uint256 _tradeIndex) {
    require(msg.sender == trades[_tradeIndex].seller);
    _;
  }

  modifier onlyBuyer(uint256 _tradeIndex) {
    require(msg.sender == trades[_tradeIndex].buyer);
    _;
  }

  function initialize(
    address _owner,
    address _buyer,
    address _seller,
    address _mediator,
    IERC20Upgradeable _token,
    IERC721Upgradeable _NFTtoken
  ) public initializer {
    require(_owner != address(0));
    buyer = _buyer;
    seller = _seller;
    mediator = _mediator;

    token = _token;
    NFTtoken = _NFTtoken;

    super.initialize(_owner);
  }
  function createTrade() external {}

  function stakeNFT() external {}

  function stake() external {}

  function confirmDelivery() external {}
}
