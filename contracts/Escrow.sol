// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;
import "./Accessible.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

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
    bool existence;
  }

  Trade[] public trades;

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

  modifier tradeExist(uint256 _tradeIndex) {
    require(trades[_tradeIndex].existence, "Trade doesn't exist");
    _;
  }

  modifier awaitingPayment(uint256 _tradeIndex) {
    require(
      trades[_tradeIndex].tradeState == State.AwaitingPayment,
      "Wrong state for execution "
    );
    _;
  }
  modifier awaitingDelivery(uint256 _tradeIndex) {
    require(
      trades[_tradeIndex].tradeState == State.AwaitingDelivery,
      "Wrong state for execution "
    );
    _;
  }
  modifier notZeroAddress(
    address _seller,
    address _buyer,
    address _mediator
  ) {
    require(_seller == address(0), "Seller is zero address");
    require(_buyer == address(0), "Buyer is zero address");
    require(_mediator == address(0), "Mediator is zero address");
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

  event CancelDelivery(
    address _mediator,
    address _buyer,
    address _seller,
    uint256 indexed _amount,
    uint256 indexed _tokenId,
    uint256 indexed _tradeIndex
  );
  event CancelTrade(address rejecter, uint256 indexed _tradeIndex);

  function initialize(
    address _owner,
    IERC20Upgradeable _token,
    IERC721Upgradeable _tokenNFT
  ) public initializer {
    token = _token;
    tokenNFT = _tokenNFT;

    super.initialize(_owner);
  }

  function createTrade(
    address _seller,
    address _mediator,
    address _buyer,
    uint256 _amount,
    uint256 _tokenId
  ) external notZeroAddress(_seller, _buyer, _mediator) {
    require(
      msg.sender == _seller || msg.sender == _buyer,
      "You must be seller or buyer"
    );
    uint256 tradeIndex = trades.length;
    require(!trades[tradeIndex].existence, "Trade already exists");
    trades.push(
      Trade({
        buyer: _buyer,
        seller: _seller,
        mediator: _mediator,
        amount: _amount,
        tokenId: _tokenId,
        tradeState: State.None,
        existence: true
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

  function stakeNFT(uint256 _tradeIndex)
    external
    tradeExist(_tradeIndex)
    onlySeller(_tradeIndex)
  {
    require(
      trades[_tradeIndex].tradeState == State.None,
      "Wrong status for staking NFT"
    );

    uint256 tokenId = trades[_tradeIndex].tokenId;
    tokenNFT.safeTransferFrom(msg.sender, address(this), tokenId);
    trades[_tradeIndex].tradeState = State.AwaitingPayment;

    emit StakedNFT(msg.sender, tokenId, _tradeIndex);
  }

  function stake(uint256 _tradeIndex)
    external
    tradeExist(_tradeIndex)
    onlyBuyer(_tradeIndex)
    awaitingPayment(_tradeIndex)
  {
    uint256 amount = trades[_tradeIndex].amount;
    token.safeTransferFrom(msg.sender, address(this), amount);
    trades[_tradeIndex].tradeState = State.AwaitingDelivery;
    emit Staked(msg.sender, amount, _tradeIndex);
  }

  function confirmDelivery(uint256 _tradeIndex)
    external
    tradeExist(_tradeIndex)
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

  function unstake(uint256 _tradeIndex)
    external
    tradeExist(_tradeIndex)
    onlyBuyer(_tradeIndex)
    awaitingDelivery(_tradeIndex)
  {
    uint256 amount = trades[_tradeIndex].amount;
    uint256 tokenId = trades[_tradeIndex].tokenId;
    address seller = trades[_tradeIndex].seller;

    token.safeTransfer(msg.sender, amount);
    tokenNFT.safeTransferFrom(address(this), seller, tokenId);
    cancelTrade(_tradeIndex);
    trades[_tradeIndex].tradeState = State.Cancel;

    emit CancelTrade(msg.sender, _tradeIndex);
    emit Unstaked(msg.sender, amount, _tradeIndex);
  }

  function unstakeNFT(uint256 _tradeIndex)
    external
    tradeExist(_tradeIndex)
    onlySeller(_tradeIndex)
    awaitingPayment(_tradeIndex)
  {
    uint256 tokenId = trades[_tradeIndex].tokenId;
    tokenNFT.safeTransferFrom(address(this), msg.sender, tokenId);
    cancelTrade(_tradeIndex);
    trades[_tradeIndex].tradeState = State.Cancel;

    emit CancelTrade(msg.sender, _tradeIndex);
    emit UnstakedNFT(msg.sender, tokenId, _tradeIndex);
  }

  function cancelDeliveryByMediator(uint256 _tradeIndex)
    external
    tradeExist(_tradeIndex)
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
    trades[_tradeIndex].tradeState = State.Cancel;

    emit CancelDelivery(
      msg.sender,
      buyer,
      seller,
      amount,
      tokenId,
      _tradeIndex
    );
  }

  function cancelTrade(uint256 _tradeIndex) internal tradeExist(_tradeIndex) {
    delete trades[_tradeIndex];
  }

  function getTradeState(uint256 _tradeIndex) external view returns (State) {
    return trades[_tradeIndex].tradeState;
  }
}
