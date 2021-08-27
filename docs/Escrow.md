# Escrow
*Simple escrow service*


## Table of contents:
- [Variables](#variables)
- [Functions:](#functions)
  - [`initialize(address _owner, contract IERC20Upgradeable _token, contract IERC721Upgradeable _tokenNFT)` (public) ](#escrow-initialize-address-contract-ierc20upgradeable-contract-ierc721upgradeable-)
  - [`allowMediator(address _mediator)` (external) ](#escrow-allowmediator-address-)
  - [`createTrade(address _seller, address _mediator, address _buyer, uint256 _amount, uint256 _tokenId)` (external) ](#escrow-createtrade-address-address-address-uint256-uint256-)
  - [`stakeNFT(uint256 _tradeIndex)` (external) ](#escrow-stakenft-uint256-)
  - [`stakeERC20(uint256 _tradeIndex)` (external) ](#escrow-stakeerc20-uint256-)
  - [`confirmDelivery(uint256 _tradeIndex)` (external) ](#escrow-confirmdelivery-uint256-)
  - [`unstakeERC20(uint256 _tradeIndex)` (external) ](#escrow-unstakeerc20-uint256-)
  - [`unstakeNFT(uint256 _tradeIndex)` (external) ](#escrow-unstakenft-uint256-)
  - [`cancelDeliveryByMediator(uint256 _tradeIndex)` (external) ](#escrow-canceldeliverybymediator-uint256-)
  - [`getTradeState(uint256 _tradeIndex) → enum Escrow.State` (external) ](#escrow-gettradestate-uint256-)
- [Events:](#events)

## Variables <a name="variables"></a>
- `contract IERC20Upgradeable token`
- `contract IERC721Upgradeable tokenNFT`
- `struct Escrow.Trade[] trades`
- `mapping(address => bool) allowedMediator`

## Functions <a name="functions"></a>

### `initialize(address _owner, contract IERC20Upgradeable _token, contract IERC721Upgradeable _tokenNFT)` (public) <a name="escrow-initialize-address-contract-ierc20upgradeable-contract-ierc721upgradeable-"></a>

*Description*: Contract initialization

### `allowMediator(address _mediator)` (external) <a name="escrow-allowmediator-address-"></a>

*Description*: Allows mediator for transaction management


#### Params
 - `_mediator`: Mediator that needs to be allowed

### `createTrade(address _seller, address _mediator, address _buyer, uint256 _amount, uint256 _tokenId)` (external) <a name="escrow-createtrade-address-address-address-uint256-uint256-"></a>

*Description*: Create trade for exchange NFT to ERC20 token


#### Params
 - `_seller`: NFT owner

 - `_mediator`: Person in charge of cancellation or confirmation of the transaction

 - `_buyer`: ERC20 token owner

 - `_amount`: Amount of buyer's tokens

 - `_tokenId`: Seller's NFT Id

### `stakeNFT(uint256 _tradeIndex)` (external) <a name="escrow-stakenft-uint256-"></a>

*Description*: Make a contribution of NFT by seller/NFT owner


#### Params
 - `_tradeIndex`: Trade id/trade index in trades array

### `stakeERC20(uint256 _tradeIndex)` (external) <a name="escrow-stakeerc20-uint256-"></a>

*Description*: Make a contribution of ERC20 by buyer/ERC20 token owner


#### Params
 - `_tradeIndex`: Trade id/trade index in trades array

### `confirmDelivery(uint256 _tradeIndex)` (external) <a name="escrow-confirmdelivery-uint256-"></a>

*Description*: Confirm exchange of NFT token for ERC20 token


#### Params
 - `_tradeIndex`: Trade id/trade index in trades array

### `unstakeERC20(uint256 _tradeIndex)` (external) <a name="escrow-unstakeerc20-uint256-"></a>

*Description*: Cancel trade and return tokens to owners


#### Params
 - `_tradeIndex`: Trade id/trade index in trades array

### `unstakeNFT(uint256 _tradeIndex)` (external) <a name="escrow-unstakenft-uint256-"></a>

*Description*: Cancel trade and return NFT to owner


#### Params
 - `_tradeIndex`: Trade id/trade index in trades array

### `cancelDeliveryByMediator(uint256 _tradeIndex)` (external) <a name="escrow-canceldeliverybymediator-uint256-"></a>

*Description*: Cancel exchange by mediator


#### Params
 - `_tradeIndex`: Trade id/trade index in trades array

### `cancelTrade(uint256 _tradeIndex)` (internal) <a name="escrow-canceltrade-uint256-"></a>

*Description*: Cancel trade


#### Params
 - `_tradeIndex`: Trade id/trade index in trades array

### `getTradeState(uint256 _tradeIndex) → enum Escrow.State` (external) <a name="escrow-gettradestate-uint256-"></a>

*Description*: Get current trade state


#### Params
 - `_tradeIndex`: Trade id/trade index in trades array
#### Returns
 - State Current trade state

## Events <a name="events"></a>
### event `StakedNFT(address _seller, uint256 _tokenId, uint256 _tradeIndex)` <a name="escrow-stakednft-address-uint256-uint256-"></a>


### event `Staked(address _buyer, uint256 _amount, uint256 _tradeIndex)` <a name="escrow-staked-address-uint256-uint256-"></a>


### event `Confirmed(address _mediator, uint256 _amount, uint256 _tokenId, uint256 _tradeIndex)` <a name="escrow-confirmed-address-uint256-uint256-uint256-"></a>


### event `TradeCreated(address _mediator, address _buyer, address _seller, uint256 _amount, uint256 _tokenId, uint256 _tradeIndex)` <a name="escrow-tradecreated-address-address-address-uint256-uint256-uint256-"></a>


### event `UnstakedERC20(address _rejecter, uint256 _amount, uint256 _tradeIndex)` <a name="escrow-unstakederc20-address-uint256-uint256-"></a>


### event `UnstakedNFT(address _seller, uint256 _tokenId, uint256 _tradeIndex)` <a name="escrow-unstakednft-address-uint256-uint256-"></a>


### event `CanceledTrade(address _rejecter, uint256 _tradeIndex)` <a name="escrow-canceledtrade-address-uint256-"></a>


### event `AllowedMediator(address _mediator)` <a name="escrow-allowedmediator-address-"></a>


