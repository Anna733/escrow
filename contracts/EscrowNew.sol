// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;
import "./Accessible.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Escrow {
  address mediator;
  address buyer;
  address seller;

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

  Trade[] trades;

  address[] internal stakeholders;

  mapping(address => uint256) internal stakes;

  modifier onlyBuyer() {
    require(msg.sender == buyer, "Only buyer can call this method");
    _;
  }
  modifier onlyMediator() {
    require(msg.sender == mediator, "Only mediator can call this method");
    _;
  }
  modifier onlySeller() {
    require(msg.sender == seller, "Only seller can call this method");
    _;
  }

  function initialize(
    address _owner,
    address _buyer,
    address _seller,
    address _mediator
  ) public initializer {
    require(_owner != address(0));
    buyer = _buyer;
    seller = _seller;
    mediator = _mediator;
    super.initialize(_owner);
  }

  function isStakeholder(address _userAddress)
    public
    view
    returns (bool, uint256)
  {
    for (
      uint256 stakeholderIndex = 0;
      stakeholderIndex < stakeholders.length;
      stakeholderIndex += 1
    ) {
      if (_userAddress == stakeholders[stakeholderIndex])
        return (true, stakeholderIndex);
    }
    return (false, 0);
  }

  function addStakeholder(address _stakeholder) internal {
    (bool _isStakeholder, ) = isStakeholder(_stakeholder);
    if (!_isStakeholder) stakeholders.push(_stakeholder);

    emit AddedStakeHolder(_stakeholder);
  }

  function stake(uint256 _stake) external onlyBuyer {
    Trade trade;
    trades.push(trade);

    if (stakes[msg.sender] == 0) addStakeholder(msg.sender);
    stakes[msg.sender] = stakes[msg.sender].add(_stake);
    stakeTime[msg.sender] = timeCall();
    token.transferFrom(msg.sender, address(this), _stake);

    emit Staked(msg.sender, _stake);
  }

  function stakeOf(address _stakeholder)
    public
    view
    returns (uint256 stakedAmount)
  {
    stakedAmount = stakes[_stakeholder];
    return stakedAmount;
  }

  function confirmDelivery(uint256 tradeId) external onlyMediator {
    Trade trade = trades[tradeId];
    require(trade.tradeState == State[0], "Cannot confirm delivery");

    trade.tradeState = State[2];
  }
}
