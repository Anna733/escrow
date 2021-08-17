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

  ///@notice ERC20 contract
  IERC20Upgradeable public token;
  ///@notice ERC721 contract
  IERC721Upgradeable public tokenNFT;

  // ///@dev stakeholder -> stake
  // mapping(address => uint256) internal stakes;

  // ///@dev stakeNFTholder -> tokenId
  // mapping(address => uint256) internal stakeNFT;

  enum State {
    None,
    AwaitingPayment,
    AwaitingDelivery,
    Complete
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
    require(trades[tradeIndex].existence, "Trade doesn't exist");
    _;
  }

  modifier awaitingPayment(uint256 _tradeIndex) {
    require(
      trades[tradeIndex].tradeState = State.AwaitingPayment,
      "Wrong state for execution "
    );
    _;
  }
  modifier awaitingDelivery(uint256 _tradeIndex) {
    require(
      trades[tradeIndex].tradeState = State.AwaitingDelivery,
      "Wrong state for execution "
    );
    _;
  }
  modifier notZeroAddress(
    address _seller,
    address _buyer,
    address _mediator
  ) {
    require(seller == address(0), "Seller is zero address");
    require(buyer == address(0), "Buyer is zero address");
    require(mediator == address(0), "Mediator is zero address");
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

  event RevokeConfirm(
    address _mediator,
    address _buyer,
    address _seller,
    uint256 indexed _amount,
    uint256 indexed _tokenId,
    uint256 indexed _tradeIndex
  );

  function initialize(
    address _owner,
    address _buyer,
    address _seller,
    address _mediator,
    IERC20Upgradeable _token,
    IERC721Upgradeable _tokenNFT
  ) public initializer notZeroAddress(_seller, _buyer, _mediator) {
    seller = _seller;
    buyer = _buyer;
    mediator = _mediator;

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
    uint256 tradeIndex = trades.length;
    require(!trades[tradeIndex].existance, "Trade already exists");
    trades.push(
      Trade({
        buyer: _buyer,
        seller: _seller,
        mediator: _mediator,
        amount: _amount,
        tokenId: _tokenId,
        tradeState: State.None,
        existance: true
      })
    );

    emit TradeCreated(
      _mediator,
      _buyer,
      _seller,
      _amount,
      _tokenId,
      _tradeIndex
    );
  }

  function stakeNFT(uint256 _tradeIndex)
    external
    tradeExist(_tradeIndex)
    onlySeller(_tradeIndex)
  {
    require(
      trades[tradeIndex].tradeState == State.None,
      "Wrong status for staking NFT"
    );

    tokenNFT.safeTransferFrom(
      msg.sender,
      address(this),
      trades[tradeIndex].tokenId
    );
    trades[tradeIndex].tradeState = State.AwaitingPayment;

    emit StakedNFT(_seller, _tokenId, _tradeIndex);
  }

  function stake(uint256 _tradeIndex)
    external
    tradeExist(_tradeIndex)
    onlyBuyer(_tradeIndex)
    awatingPayment(_tradeIndex)
  {
    token.safeTransferFrom(
      msg.sender,
      address(this),
      trades[tradeIndex].amount
    );
    trades[tradeIndex].tradeState = State.AwaitingDelivery;
    emit Staked(_buyer, _amount, _tradeIndex);
  }

  function confirmDelivery(uint256 _tradeIndex)
    external
    tradeExist(_tradeIndex)
    onlyMediator(_tradeIndex)
    awaitingDelivery(_tradeIndex)
  {
    token.safeTransferFrom(
      trades[_tradeIndex].buyer,
      trades[_tradeIndex].seller,
      trades[tradeIndex].amount
    );
    tokenNFT.safeTransferFrom(
      trades[_tradeIndex].seller,
      trades[_tradeIndex].buyer,
      trades[tradeIndex].tokenId
    );
    trades[tradeIndex].tradeState = State.Complete;
    emit Confirmed(_mediator, _amount, _tradeIndex);
  }

  function unstake(uint256 _tradeIndex)
    external
    onlyBuyer(_tradeIndex)
    tradeExist(_tradeIndex)
    awaitingDelivery(_tradeIndex)
  {
    uint256 amount = trades[_tradeIndex].amount;
    uint256 tokenId = trades[_tradeIndex].tokenId;
    address seller = trades[_tradeIndex].seller;

    stakes[msg.sender] = stakes[msg.sender].sub(amount);

    token.transfer(msg.sender, amount);
    tokenNFT.transfer(seller, tokenId);

    emit Unstaked(msg.sender, amount, _tradeIndex);
  }

  function unstakeNFT(uint256 _tradeIndex)
    external
    onlySeller(_tradeIndex)
    tradeExist(_tradeIndex)
    awaitingPayment(_tradeIndex)
  {
    uint256 tokenId = trades[_tradeIndex].tokenId;
    tokenNFT.transfer(msg.sender, tokenId);

    emit UnstakedNFT(msg.sender, tokenId, _tradeIndex);
  }

  function revokeDelivery(uint256 _tradeIndex)
    external
    onlyMediator(_tradeIndex)
    tradeExist(_tradeIndex)
    awaitingDelivery(_tradeIndex)
  {
    uint256 amount = trades[_tradeIndex].amount;
    uint256 tokenId = trades[_tradeIndex].tokenId;
    address seller = trades[_tradeIndex].seller;
    address buyer = trades[_tradeIndex].buyer;

    token.transfer(buyer, amount);
    tokenNFT.transfer(seller, tokenId);

    emit RevokeConfirm(msg.sender, buyer, seller, amount, tokenId, _tradeIndex);
  }

  function getTradeState(uint256 _tradeIndex) external view {
    return trades[_tradeIndex].tradeState;
  }
}
