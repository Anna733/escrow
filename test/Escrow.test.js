const {
  constants,
  expectEvent,
  expectRevert,
  balance,
  time,
  ether,
} = require("@openzeppelin/test-helpers");
const duration = time.duration;
const BN = web3.utils.BN;
const chai = require("chai");
chai.use(require("chai-bn")(BN));
const should = require("chai").should();
const assert = require("assert").strict;
const { ethers } = require("ethers");

const Escrow = artifacts.require("Escrow");
const ERC20 = artifacts.require("ERC20Stub");
const ERC721 = artifacts.require("ERC721Stub");

contract.only("Escrow", async (accounts) => {
  const [owner, buyer, seller, mediator, thirdParty] = accounts;

  let erc20;
  let erc721;
  let escrow;
  const tokenId = new BN(1);
  const amount = new BN(10);
  const tradeIndex = new BN(0);

  let State = {
    None: new BN(0),
    AwaitingPayment: new BN(1),
    AwaitingDelivery: new BN(2),
    Complete: new BN(3),
    Cancel: new BN(4),
  };

  beforeEach(async () => {
    erc20 = await ERC20.new();
    erc721 = await ERC721.new();
    escrow = await Escrow.new();
    await erc20.initialize();
    await erc721.initialize();
    await escrow.initialize(owner, erc20.address, erc721.address);

    await erc721.mint(seller, tokenId);
    await erc721.approve(escrow.address, tokenId, { from: seller });

    await erc20.mint(buyer, amount);
    await erc20.approve(escrow.address, amount, { from: buyer });
  });
  describe(`Modifiers test`, () => {
    it(`only mediator test`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await escrow.stakeNFT(tradeIndex, {
        from: seller,
      });
      await escrow.stake(tradeIndex, { from: buyer });
      await expectRevert(
        escrow.confirmDelivery(tradeIndex),
        "Sender is not mediator"
      );
    });
    it(`only seller test`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await expectRevert(escrow.stakeNFT(tradeIndex), "Sender is not seller");
    });
    it(`only buyer test`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await escrow.stakeNFT(tradeIndex, {
        from: seller,
      });
      await escrow.stake(tradeIndex, { from: buyer });
      await expectRevert(escrow.stake(tradeIndex), "Sender is not buyer");
    });
    it(`awaiting payment test`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await escrow.stakeNFT(tradeIndex, {
        from: seller,
      });
      await escrow.stake(tradeIndex, { from: buyer });
      await expectRevert(
        escrow.stake(tradeIndex, { from: buyer }),
        "Wrong state for execution"
      );
    });
    it(`awaiting delivery test`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await escrow.stakeNFT(tradeIndex, {
        from: seller,
      });
      await escrow.stake(tradeIndex, { from: buyer });
      await escrow.confirmDelivery(tradeIndex, { from: mediator });
      await expectRevert(
        escrow.confirmDelivery(tradeIndex, { from: mediator }),
        "Wrong state for execution"
      );
    });
    it(`none state test`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await escrow.stakeNFT(tradeIndex, {
        from: seller,
      });
      await expectRevert(
        escrow.stakeNFT(tradeIndex, {
          from: seller,
        }),
        "Wrong state for execution"
      );
    });
    it(`not zero address test`, async () => {
      await expectRevert(
        escrow.createTrade(
          constants.ZERO_ADDRESS,
          mediator,
          buyer,
          amount,
          tokenId
        ),
        "Seller is zero address"
      );
      await expectRevert(
        escrow.createTrade(
          seller,
          constants.ZERO_ADDRESS,
          buyer,
          amount,
          tokenId
        ),
        "Mediator is zero address"
      );
      await expectRevert(
        escrow.createTrade(
          seller,
          mediator,
          constants.ZERO_ADDRESS,
          amount,
          tokenId
        ),
        "Buyer is zero address"
      );
    });
  });
  describe(`Create trade test`, () => {
    it(`should create trade by seller or buyer`, async () => {
      const allowResult = await escrow.allowMediator(mediator);
      expectEvent(allowResult, "AllowedMediator", {
        _mediator: mediator,
      });

      const result = await escrow.createTrade(
        seller,
        mediator,
        buyer,
        amount,
        tokenId,
        { from: seller }
      );
      expectEvent(result, "TradeCreated", {
        _mediator: mediator,
        _buyer: buyer,
        _seller: seller,
        _amount: amount,
        _tokenId: tokenId,
        _tradeIndex: tradeIndex,
      });
      const tradeResult = await escrow.trades(tradeIndex);
      tradeResult.buyer.should.equal(buyer);
      tradeResult.seller.should.equal(seller);
      tradeResult.mediator.should.equal(mediator);
      tradeResult.amount.should.bignumber.equal(amount);
      tradeResult.tokenId.should.bignumber.equal(tokenId);
      tradeResult.tradeState.should.bignumber.equal(State.None);
    });
    it(`shouldn't create trade by third party`, async () => {
      await expectRevert(
        escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
          from: thirdParty,
        }),
        "Sender isn't seller or buyer"
      );
    });
    it(`shouldn't create trade with not allowed mediator`, async () => {
      await expectRevert(
        escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
          from: buyer,
        }),
        "Not allowed mediator"
      );
    });
  });
  it(`Stake NFT test`, async () => {
    await escrow.allowMediator(mediator);
    await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
      from: seller,
    });
    const result = await escrow.stakeNFT(tradeIndex, { from: seller });
    expectEvent(result, "StakedNFT", {
      _seller: seller,
      _tokenId: tokenId,
      _tradeIndex: tradeIndex,
    });
    const tradeResult = await escrow.trades(tradeIndex);
    tradeResult.tradeState.should.bignumber.equal(State.AwaitingPayment);

    const sellerBalance = await erc721.balanceOf(seller);
    sellerBalance.should.bignumber.equal(new BN(0));
    const contractBalance = await erc721.balanceOf(escrow.address);
    contractBalance.should.bignumber.equal(tokenId);
  });
  it(`Stake test`, async () => {
    await escrow.allowMediator(mediator);
    await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
      from: seller,
    });
    await escrow.stakeNFT(tradeIndex, { from: seller });
    const result = await escrow.stake(tradeIndex, { from: buyer });
    expectEvent(result, "Staked", {
      _buyer: buyer,
      _amount: amount,
      _tradeIndex: tradeIndex,
    });
    const tradeResult = await escrow.trades(tradeIndex);
    tradeResult.tradeState.should.bignumber.equal(State.AwaitingDelivery);

    const buyerBalance = await erc20.balanceOf(buyer);
    buyerBalance.should.bignumber.equal(new BN(0));
    const contractBalance = await erc20.balanceOf(escrow.address);
    contractBalance.should.bignumber.equal(amount);
  });
  it(`Confirm delivery test`, async () => {
    await escrow.allowMediator(mediator);
    await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
      from: seller,
    });
    await escrow.stakeNFT(tradeIndex, { from: seller });
    await escrow.stake(tradeIndex, { from: buyer });
    const result = await escrow.confirmDelivery(tradeIndex, { from: mediator });
    expectEvent(result, "Confirmed", {
      _mediator: mediator,
      _amount: amount,
      _tradeIndex: tradeIndex,
    });
    const tradeResult = await escrow.trades(tradeIndex);
    tradeResult.tradeState.should.bignumber.equal(State.Complete);

    const sellerBalance = await erc20.balanceOf(seller);
    sellerBalance.should.bignumber.equal(amount);
    const buyerBalance = await erc721.balanceOf(buyer);
    buyerBalance.should.bignumber.equal(tokenId);
    const contractBalance = await erc20.balanceOf(escrow.address);
    contractBalance.should.bignumber.equal(new BN(0));
  });
  it(`Unstake test`, async () => {
    await escrow.allowMediator(mediator);
    await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
      from: seller,
    });
    await escrow.stakeNFT(tradeIndex, { from: seller });
    await escrow.stake(tradeIndex, { from: buyer });
    const result = await escrow.unstake(tradeIndex, { from: buyer });

    expectEvent(result, "Unstaked", {
      _buyer: buyer,
      _amount: amount,
      _tradeIndex: tradeIndex,
    });

    expectEvent(result, "CanceledTrade", {
      _rejecter: buyer,
      _tradeIndex: tradeIndex,
    });
    const tradeResult = await escrow.trades(tradeIndex);
    tradeResult.tradeState.should.bignumber.equal(State.Cancel);

    const buyerBalance = await erc20.balanceOf(buyer);
    buyerBalance.should.bignumber.equal(amount);
    const sellerBalance = await erc721.balanceOf(seller);
    sellerBalance.should.bignumber.equal(tokenId);

    const contractTokenBalance = await erc20.balanceOf(escrow.address);
    contractTokenBalance.should.bignumber.equal(new BN(0));
    const contractNFTBalance = await erc721.balanceOf(escrow.address);
    contractNFTBalance.should.bignumber.equal(new BN(0));
  });
  it(`Unstake NFT test`, async () => {
    await escrow.allowMediator(mediator);
    await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
      from: seller,
    });
    await escrow.stakeNFT(tradeIndex, { from: seller });
    const result = await escrow.unstakeNFT(tradeIndex, { from: seller });

    expectEvent(result, "UnstakedNFT", {
      _seller: seller,
      _tokenId: tokenId,
      _tradeIndex: tradeIndex,
    });

    expectEvent(result, "CanceledTrade", {
      _rejecter: seller,
      _tradeIndex: tradeIndex,
    });
    const tradeResult = await escrow.trades(tradeIndex);
    tradeResult.tradeState.should.bignumber.equal(State.Cancel);

    const buyerBalance = await erc20.balanceOf(buyer);
    buyerBalance.should.bignumber.equal(amount);
    const sellerBalance = await erc721.balanceOf(seller);
    sellerBalance.should.bignumber.equal(tokenId);

    const contractTokenBalance = await erc20.balanceOf(escrow.address);
    contractTokenBalance.should.bignumber.equal(new BN(0));
    const contractNFTBalance = await erc721.balanceOf(escrow.address);
    contractNFTBalance.should.bignumber.equal(new BN(0));
  });
  it(`Cancel delivery by mediator test`, async () => {
    await escrow.allowMediator(mediator);
    await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
      from: seller,
    });
    await escrow.stakeNFT(tradeIndex, { from: seller });
    await escrow.stake(tradeIndex, { from: buyer });
    const result = await escrow.cancelDeliveryByMediator(tradeIndex, {
      from: mediator,
    });
    expectEvent(result, "CanceledTrade", {
      _rejecter: mediator,
      _tradeIndex: tradeIndex,
    });

    const buyerBalance = await erc20.balanceOf(buyer);
    buyerBalance.should.bignumber.equal(amount);
    const sellerBalance = await erc721.balanceOf(seller);
    sellerBalance.should.bignumber.equal(tokenId);

    const contractTokenBalance = await erc20.balanceOf(escrow.address);
    contractTokenBalance.should.bignumber.equal(new BN(0));
    const contractNFTBalance = await erc721.balanceOf(escrow.address);
    contractNFTBalance.should.bignumber.equal(new BN(0));

    const stateResult = await escrow.getTradeState(tradeIndex);
    stateResult.should.bignumber.equal(State.Cancel);
  });
});
