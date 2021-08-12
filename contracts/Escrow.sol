// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;
import "./Accessible.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Escrow is Accessible {
  using SafeMath for uint256;

  address public buyer;
  address payable public seller;
  address public mediator;

  address[] internal stakeholders;

  ///@dev stakeholder -> stake
  mapping(address => uint256) internal stakes;

  ///@dev stakeNFTholder -> stakeNFT
  mapping(address => uint256) internal stakeNFT;

  ///@dev Stake time for each stakeholder.
  mapping(address => uint256) internal stakeTime;

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

  /// @notice ERC20 token contract
  ERC20 public token;

  /// @notice NFT token contract
  ERC721 public tokenNFT;

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
    address payable _seller
  ) public initializer {
    require(_owner != address(0));
    buyer = _buyer;
    seller = _seller;
    mediator = _mediator;
    super.initialize(_owner);
  }

  ///@notice A method to check if an address is a stakeholder.
  /// @param _userAddress The address to verify.
  /// @return bool, uint256 Whether the address is a stakeholder, and if so its position in the stakeholders array.
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

  ///@notice A method to add a stakeholder.
  ///@param _stakeholder The stakeholder to add.
  function addStakeholder(address _stakeholder) internal {
    (bool _isStakeholder, ) = isStakeholder(_stakeholder);
    if (!_isStakeholder) stakeholders.push(_stakeholder);

    emit AddedStakeHolder(_stakeholder);
  }

  ///@notice A method to remove a stakeholder.
  ///@param _stakeholder The stakeholder to remove.
  function removeStakeholder(address _stakeholder) internal {
    (bool _isStakeholder, uint256 stakeholderIndex) = isStakeholder(
      _stakeholder
    );
    if (_isStakeholder) {
      stakeholders[stakeholderIndex] = stakeholders[stakeholders.length - 1];
      stakeholders.pop();
    }

    emit RemovedStakeholder(_stakeholder);
  }

  ///@notice A method to retrieve the stake for a stakeholder.
  ///@param _stakeholder The stakeholder to retrieve the stake for.
  ///@return stakedAmount The amount of wei staked.
  function stakeOf(address _stakeholder)
    public
    view
    returns (uint256 stakedAmount)
  {
    stakedAmount = stakes[_stakeholder];
    return stakedAmount;
  }

  ///@notice A method for getting the amount of the stakeholder's reward.
  /// @param _stakeholder The stakeholder to retrieve the reward for.
  /// @return uint256 The amount of the user's stake ballance with reward.
  function balanceOf(address _stakeholder) public view returns (uint256) {
    return stakeOf(_stakeholder).mul(3);
  }

  ///@notice A method to the aggregated stakes from all stakeholders.
  /// @return _totalStakes The aggregated stakes from all stakeholders.
  function totalStakes() external view returns (uint256 _totalStakes) {
    _totalStakes = 0;
    for (
      uint256 stakeholderIndex = 0;
      stakeholderIndex < stakeholders.length;
      stakeholderIndex += 1
    ) {
      _totalStakes = _totalStakes.add(stakes[stakeholders[stakeholderIndex]]);
    }
    return _totalStakes;
  }

  /// @notice A method for getting the current time.
  /// @return uint256 current time
  function timeCall() public view returns (uint256) {
    return now;
  }

  ///@notice A method for a stakeholder to create a stake.
  ///@param _stake The size of the stake to be created.
  function stake(uint256 _stake) external {
    if (stakes[msg.sender] == 0) addStakeholder(msg.sender);
    stakes[msg.sender] = stakes[msg.sender].add(_stake);
    stakeTime[msg.sender] = timeCall();
    token.transferFrom(msg.sender, address(this), _stake);

    emit Staked(msg.sender, _stake);
  }

  ///@notice A method for a stakeholder to remove a stake.
  ///@param _stake The size of the stake to be removed.
  function unstake(uint256 _stake) external returns (uint256 _currentStake) {
    require(now >= getUnstakePossibilityTime(msg.sender), "Wrong unstake time");
    stakes[msg.sender] = stakes[msg.sender].sub(_stake);
    if (stakes[msg.sender] == 0) removeStakeholder(msg.sender);
    token.transfer(msg.sender, _stake);
    _currentStake = stakes[msg.sender];
    emit Unstaked(msg.sender, _stake, _currentStake);
    return _currentStake;
  }

  /// @notice A title that should describe the contract/interface
  /// @return The name of the author
  function getUnstakePossibilityTime(address _stakeholder)
    public
    view
    returns (uint256)
  {
    (bool _isStakeholder, ) = isStakeholder(_stakeholder);
    require(_isStakeholder, "!stakeholder");
    uint256 unstakeTimeLimit = 3;
    uint256 unstakePossibilityTime = stakeTime[_stakeholder] +
      (unstakeTimeLimit * 1 days);
    return unstakePossibilityTime;
  }
}
