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
    AwaitingNFT,
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
      "Sender must be mediator"
    );
    _;
  }

  modifier onlySeller(uint256 _tradeIndex) {
    require(msg.sender == trades[_tradeIndex].seller, "Sender must be seller");
    _;
  }

  modifier onlyBuyer(uint256 _tradeIndex) {
    require(msg.sender == trades[_tradeIndex].buyer, "Sender must be buyer");
    _;
  }

  modifier awaitingPayment(uint256 _tradeIndex) {
    require(
      trades[_tradeIndex].tradeState == State.AwaitingPayment,
      "State must be AwaitingPayment"
    );
    _;
  }
  modifier awaitingDelivery(uint256 _tradeIndex) {
    require(
      trades[_tradeIndex].tradeState == State.AwaitingDelivery,
      "State must be AwaitingDelivery"
    );
    _;
  }
  modifier awaitingNFT(uint256 _tradeIndex) {
    require(
      trades[_tradeIndex].tradeState == State.AwaitingNFT,
      "State must be AwaitingNFT"
    );
    _;
  }
  modifier participantsNonZeroAddress(
    address _seller,
    address _buyer,
    address _mediator
  ) {
    require(_seller != address(0), "Seller must be non-zero address");
    require(_buyer != address(0), "Buyer must be non-zero address");
    require(_mediator != address(0), "Mediator must be non-zero address");
    _;
  }

  event StakedNFT(
    address _seller,
    uint256 indexed _tokenId,
    uint256 indexed _tradeIndex
  );

  event Staked(address _buyer, uint256 _amount, uint256 indexed _tradeIndex);

  event Confirmed(
    address _mediator,
    uint256 _amount,
    uint256 indexed _tokenId,
    uint256 indexed _tradeIndex
  );

  event TradeCreated(
    address _mediator,
    address _buyer,
    address _seller,
    uint256 _amount,
    uint256 indexed _tokenId,
    uint256 indexed _tradeIndex
  );

  event UnstakedERC20(
    address _rejecter,
    uint256 _amount,
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

  /// @notice Create trade for exchange NFT to ERC20 token
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
  ) external participantsNonZeroAddress(_seller, _buyer, _mediator) {
    require(
      msg.sender == _seller || msg.sender == _buyer,
      "Sender must be seller or buyer"
    );
    require(allowedMediator[_mediator] == true, "Mediator must be allowed");
    uint256 tradeIndex = trades.length;
    trades.push(
      Trade({
        buyer: _buyer,
        seller: _seller,
        mediator: _mediator,
        amount: _amount,
        tokenId: _tokenId,
        tradeState: State.AwaitingNFT
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

  /// @notice Make a contribution of NFT by seller/NFT owner
  /// @param _tradeIndex Trade id/trade index in trades array
  function stakeNFT(uint256 _tradeIndex)
    external
    onlySeller(_tradeIndex)
    awaitingNFT(_tradeIndex)
  {
    Trade storage trade = trades[_tradeIndex];
    uint256 tokenId = trade.tokenId;
    tokenNFT.transferFrom(msg.sender, address(this), tokenId);
    trade.tradeState = State.AwaitingPayment;

    emit StakedNFT(msg.sender, tokenId, _tradeIndex);
  }

  /// @notice Make a contribution of ERC20 by buyer/ERC20 token owner
  /// @param _tradeIndex Trade id/trade index in trades array
  function stakeERC20(uint256 _tradeIndex)
    external
    onlyBuyer(_tradeIndex)
    awaitingPayment(_tradeIndex)
  {
    Trade storage trade = trades[_tradeIndex];
    uint256 amount = trade.amount;
    token.safeTransferFrom(msg.sender, address(this), amount);
    trade.tradeState = State.AwaitingDelivery;
    emit Staked(msg.sender, amount, _tradeIndex);
  }

  /// @notice Confirm exchange of NFT token for ERC20 token
  /// @param _tradeIndex Trade id/trade index in trades array
  function confirmDelivery(uint256 _tradeIndex)
    external
    onlyMediator(_tradeIndex)
    awaitingDelivery(_tradeIndex)
  {
    Trade storage trade = trades[_tradeIndex];
    token.safeTransfer(trade.seller, trade.amount);
    tokenNFT.safeTransferFrom(address(this), trade.buyer, trade.tokenId);
    trade.tradeState = State.Complete;
    emit Confirmed(msg.sender, trade.amount, trade.tokenId, _tradeIndex);
  }

  /// @notice Cancel trade and return tokens to owners
  /// @param _tradeIndex Trade id/trade index in trades array
  function unstakeERC20(uint256 _tradeIndex)
    external
    awaitingDelivery(_tradeIndex)
  {
    Trade storage trade = trades[_tradeIndex];
    require(
      msg.sender == trade.seller || msg.sender == trade.buyer,
      "Sender must be seller or buyer"
    );
    uint256 amount = trade.amount;
    uint256 tokenId = trade.tokenId;
    address seller = trade.seller;
    address buyer = trade.buyer;

    token.safeTransfer(buyer, amount);
    tokenNFT.safeTransferFrom(address(this), seller, tokenId);
    cancelTrade(_tradeIndex);

    emit UnstakedERC20(msg.sender, amount, _tradeIndex);
  }

  /// @notice Cancel trade and return NFT to owner
  /// @param _tradeIndex Trade id/trade index in trades array
  function unstakeNFT(uint256 _tradeIndex)
    external
    onlySeller(_tradeIndex)
    awaitingPayment(_tradeIndex)
  {
    Trade storage trade = trades[_tradeIndex];
    uint256 tokenId = trade.tokenId;
    tokenNFT.safeTransferFrom(address(this), msg.sender, tokenId);
    cancelTrade(_tradeIndex);

    emit UnstakedNFT(msg.sender, tokenId, _tradeIndex);
  }

  /// @notice Cancel exchange by mediator
  /// @param _tradeIndex Trade id/trade index in trades array
  function cancelDeliveryByMediator(uint256 _tradeIndex)
    external
    onlyMediator(_tradeIndex)
    awaitingDelivery(_tradeIndex)
  {
    Trade storage trade = trades[_tradeIndex];
    uint256 amount = trade.amount;
    uint256 tokenId = trade.tokenId;
    address seller = trade.seller;
    address buyer = trade.buyer;

    token.safeTransfer(buyer, amount);
    tokenNFT.safeTransferFrom(address(this), seller, tokenId);
    cancelTrade(_tradeIndex);
  }

  /// @notice Cancel trade
  /// @param _tradeIndex Trade id/trade index in trades array
  function cancelTrade(uint256 _tradeIndex) internal {
    trades[_tradeIndex].tradeState = State.Cancel;
    emit CanceledTrade(msg.sender, _tradeIndex);
  }

  /// @notice Get current trade state
  /// @return State Current trade state
  /// @param _tradeIndex Trade id/trade index in trades array
  function getTradeState(uint256 _tradeIndex) external view returns (State) {
    return trades[_tradeIndex].tradeState;
  }
}
