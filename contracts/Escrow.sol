// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;
import "./Accessible.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

/// @title Simple escrow service
/// @author Anna Shramova, anna.nexus.2002@gmail.com
contract Escrow is Accessible {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  ///@notice ERC20 contract
  IERC20Upgradeable public token;
  ///@notice ERC721 contract
  IERC721Upgradeable public tokenNFT;

  enum State {
    None,
    AwaitingPayment,
    AwaitingDelivery,
    Complete,
    Cancel
  }

  struct Trade {
    address buyer;
    address seller;
    address mediator;
    uint256 amount;
    uint256 tokenId;
    State tradeState;
  }

  /// @notice Stores created trades
  Trade[] public trades;

  /// @notice Stores allowed mediators for transaction management
  mapping(address => bool) public allowedMediator;

  modifier onlyMediator(uint256 _tradeIndex) {
    require(
      msg.sender == trades[_tradeIndex].mediator,
      "Sender is not mediator"
    );
    _;
  }

  modifier onlySeller(uint256 _tradeIndex) {
    require(msg.sender == trades[_tradeIndex].seller, "Sender is not seller");
    _;
  }

  modifier onlyBuyer(uint256 _tradeIndex) {
    require(msg.sender == trades[_tradeIndex].buyer, "Sender is not buyer");
    _;
  }

  modifier awaitingPayment(uint256 _tradeIndex) {
    require(
      trades[_tradeIndex].tradeState == State.AwaitingPayment,
      "Wrong state for execution"
    );
    _;
  }

  modifier awaitingDelivery(uint256 _tradeIndex) {
    require(
      trades[_tradeIndex].tradeState == State.AwaitingDelivery,
      "Wrong state for execution"
    );
    _;
  }

  modifier noneState(uint256 _tradeIndex) {
    require(
      trades[_tradeIndex].tradeState == State.None,
      "Wrong state for execution"
    );
    _;
  }

  modifier notZeroAddress(
    address _seller,
    address _buyer,
    address _mediator
  ) {
    require(_seller != address(0), "Seller is zero address");
    require(_buyer != address(0), "Buyer is zero address");
    require(_mediator != address(0), "Mediator is zero address");
    _;
  }

  event StakedNFT(
    address _seller,
    uint256 indexed _tokenId,
    uint256 indexed _tradeIndex
  );

  event Staked(
    address _buyer,
    uint256 indexed _amount,
    uint256 indexed _tradeIndex
  );

  event Confirmed(
    address _mediator,
    uint256 indexed _amount,
    uint256 indexed _tradeIndex
  );

  event TradeCreated(
    address _mediator,
    address _buyer,
    address _seller,
    uint256 indexed _amount,
    uint256 indexed _tokenId,
    uint256 indexed _tradeIndex
  );

  event Unstaked(
    address _buyer,
    uint256 indexed _amount,
    uint256 indexed _tradeIndex
  );

  event UnstakedNFT(
    address _seller,
    uint256 indexed _tokenId,
    uint256 indexed _tradeIndex
  );

  event CanceledTrade(address _rejecter, uint256 indexed _tradeIndex);
  event AllowedMediator(address _mediator);

  /// @notice Contract initialization
  function initialize(
    address _owner,
    IERC20Upgradeable _token,
    IERC721Upgradeable _tokenNFT
  ) public initializer {
    token = _token;
    tokenNFT = _tokenNFT;

    super.initialize(_owner);
  }

  /// @notice Allows mediator for transaction management
  /// @param _mediator Mediator that needs to be allowed
  function allowMediator(address _mediator) external onlyOwner {
    allowedMediator[_mediator] = true;
    emit AllowedMediator(_mediator);
  }

  /// @notice Create trade
  /// @param _seller NFT owner
  /// @param _mediator Person in charge of cancellation or confirmation of the transaction
  /// @param _buyer ERC20 token owner
  /// @param _amount Amount of buyer's tokens
  /// @param _tokenId Seller's NFT Id
  function createTrade(
    address _seller,
    address _mediator,
    address _buyer,
    uint256 _amount,
    uint256 _tokenId
  ) external notZeroAddress(_seller, _buyer, _mediator) {
    require(
      msg.sender == _seller || msg.sender == _buyer,
      "Sender isn't seller or buyer"
    );
    require(allowedMediator[_mediator] == true, "Not allowed mediator");
    uint256 tradeIndex = trades.length;
    trades.push(
      Trade({
        buyer: _buyer,
        seller: _seller,
        mediator: _mediator,
        amount: _amount,
        tokenId: _tokenId,
        tradeState: State.None
      })
    );
    emit TradeCreated(
      _mediator,
      _buyer,
      _seller,
      _amount,
      _tokenId,
      tradeIndex
    );
  }

  /// @notice Make a contribution for NFT owner
  /// @param _tradeIndex Trade id in trades
  function stakeNFT(uint256 _tradeIndex)
    external
    onlySeller(_tradeIndex)
    noneState(_tradeIndex)
  {
    uint256 tokenId = trades[_tradeIndex].tokenId;
    tokenNFT.transferFrom(msg.sender, address(this), tokenId);
    trades[_tradeIndex].tradeState = State.AwaitingPayment;

    emit StakedNFT(msg.sender, tokenId, _tradeIndex);
  }

  /// @notice Make a contribution for ERC20 token owner
  /// @param _tradeIndex Trade id in trades
  function stake(uint256 _tradeIndex)
    external
    onlyBuyer(_tradeIndex)
    awaitingPayment(_tradeIndex)
  {
    uint256 amount = trades[_tradeIndex].amount;
    token.safeTransferFrom(msg.sender, address(this), amount);
    trades[_tradeIndex].tradeState = State.AwaitingDelivery;
    emit Staked(msg.sender, amount, _tradeIndex);
  }

  /// @notice Confirm exchange of NFT token for ERC20 token
  /// @param _tradeIndex Trade id in trades
  function confirmDelivery(uint256 _tradeIndex)
    external
    onlyMediator(_tradeIndex)
    awaitingDelivery(_tradeIndex)
  {
    token.safeTransfer(trades[_tradeIndex].seller, trades[_tradeIndex].amount);
    tokenNFT.safeTransferFrom(
      address(this),
      trades[_tradeIndex].buyer,
      trades[_tradeIndex].tokenId
    );
    trades[_tradeIndex].tradeState = State.Complete;
    emit Confirmed(msg.sender, trades[_tradeIndex].amount, _tradeIndex);
  }

  /// @notice Cancel trade and contribution for ERC20 owner
  /// @param _tradeIndex Trade id in trades
  function unstake(uint256 _tradeIndex)
    external
    onlyBuyer(_tradeIndex)
    awaitingDelivery(_tradeIndex)
  {
    uint256 amount = trades[_tradeIndex].amount;
    uint256 tokenId = trades[_tradeIndex].tokenId;
    address seller = trades[_tradeIndex].seller;

    token.safeTransfer(msg.sender, amount);
    tokenNFT.safeTransferFrom(address(this), seller, tokenId);
    cancelTrade(_tradeIndex);

    emit Unstaked(msg.sender, amount, _tradeIndex);
  }

  /// @notice Cancel trade and contribution for NFT owner
  /// @param _tradeIndex Trade id in trades
  function unstakeNFT(uint256 _tradeIndex)
    external
    onlySeller(_tradeIndex)
    awaitingPayment(_tradeIndex)
  {
    uint256 tokenId = trades[_tradeIndex].tokenId;
    tokenNFT.safeTransferFrom(address(this), msg.sender, tokenId);
    cancelTrade(_tradeIndex);

    emit UnstakedNFT(msg.sender, tokenId, _tradeIndex);
  }

  /// @notice Cancel exchange by mediator
  /// @param _tradeIndex Trade id in trades
  function cancelDeliveryByMediator(uint256 _tradeIndex)
    external
    onlyMediator(_tradeIndex)
    awaitingDelivery(_tradeIndex)
  {
    uint256 amount = trades[_tradeIndex].amount;
    uint256 tokenId = trades[_tradeIndex].tokenId;
    address seller = trades[_tradeIndex].seller;
    address buyer = trades[_tradeIndex].buyer;

    token.safeTransfer(buyer, amount);
    tokenNFT.safeTransferFrom(address(this), seller, tokenId);
    cancelTrade(_tradeIndex);
  }

  /// @notice Cancel trade
  /// @param _tradeIndex Trade id in trades
  function cancelTrade(uint256 _tradeIndex) internal {
    trades[_tradeIndex].tradeState = State.Cancel;
    emit CanceledTrade(msg.sender, _tradeIndex);
  }

  /// @notice Get current trade state
  /// @return State Current trade state
  /// @param _tradeIndex Trade id in trades
  function getTradeState(uint256 _tradeIndex) external view returns (State) {
    return trades[_tradeIndex].tradeState;
  }
}
