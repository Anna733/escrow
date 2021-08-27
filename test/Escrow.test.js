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
    AwaitingNFT: new BN(0),
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
      await escrow.stakeERC20(tradeIndex, { from: buyer });
      await expectRevert(
        escrow.confirmDelivery(tradeIndex),
        "Sender must be mediator"
      );
    });
    it(`only seller test`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await expectRevert(escrow.stakeNFT(tradeIndex), "Sender must be seller");
    });
    it(`only buyer test`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await escrow.stakeNFT(tradeIndex, {
        from: seller,
      });
      await expectRevert(escrow.stakeERC20(tradeIndex), "Sender must be buyer");
    });
    it(`awaiting payment test`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await escrow.stakeNFT(tradeIndex, {
        from: seller,
      });
      await escrow.stakeERC20(tradeIndex, { from: buyer });
      await expectRevert(
        escrow.stakeERC20(tradeIndex, { from: buyer }),
        "State must be AwaitingPayment"
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
      await escrow.stakeERC20(tradeIndex, { from: buyer });
      await escrow.confirmDelivery(tradeIndex, { from: mediator });
      await expectRevert(
        escrow.confirmDelivery(tradeIndex, { from: mediator }),
        "State must be AwaitingDelivery"
      );
    });
    it(`awaiting NFT test`, async () => {
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
        "State must be AwaitingNFT"
      );
    });
    it(`participants non zero address test`, async () => {
      await expectRevert(
        escrow.createTrade(
          constants.ZERO_ADDRESS,
          mediator,
          buyer,
          amount,
          tokenId
        ),
        "Seller must be non-zero address"
      );
      await expectRevert(
        escrow.createTrade(
          seller,
          constants.ZERO_ADDRESS,
          buyer,
          amount,
          tokenId
        ),
        "Mediator must be non-zero address"
      );
      await expectRevert(
        escrow.createTrade(
          seller,
          mediator,
          constants.ZERO_ADDRESS,
          amount,
          tokenId
        ),
        "Buyer must be non-zero address"
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
      tradeResult.tradeState.should.bignumber.equal(State.AwaitingNFT);
    });
    it(`shouldn't create trade by third party`, async () => {
      await expectRevert(
        escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
          from: thirdParty,
        }),
        "Sender must be seller or buyer"
      );
    });
    it(`shouldn't create trade with not allowed mediator`, async () => {
      await expectRevert(
        escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
          from: buyer,
        }),
        "Mediator must be allowed"
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
  it(`Stake ERC20 test`, async () => {
    await escrow.allowMediator(mediator);
    await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
      from: seller,
    });
    await escrow.stakeNFT(tradeIndex, { from: seller });
    const result = await escrow.stakeERC20(tradeIndex, { from: buyer });
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
    await escrow.stakeERC20(tradeIndex, { from: buyer });
    const result = await escrow.confirmDelivery(tradeIndex, { from: mediator });
    expectEvent(result, "Confirmed", {
      _mediator: mediator,
      _amount: amount,
      _tokenId: tokenId,
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
  describe(`Unstake ERC20 test test`, () => {
    it(`Should be able to unstake ERC20 by buyer`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await escrow.stakeNFT(tradeIndex, { from: seller });
      await escrow.stakeERC20(tradeIndex, { from: buyer });
      const result = await escrow.unstakeERC20(tradeIndex, { from: buyer });

      expectEvent(result, "UnstakedERC20", {
        _rejecter: buyer,
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
    it(`Should be able to unstake ERC20 by seller`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await escrow.stakeNFT(tradeIndex, { from: seller });
      await escrow.stakeERC20(tradeIndex, { from: buyer });
      const result = await escrow.unstakeERC20(tradeIndex, { from: seller });

      expectEvent(result, "UnstakedERC20", {
        _rejecter: seller,
        _amount: amount,
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
    it(`Shouldn't be able to unstake ERC20 by third party`, async () => {
      await escrow.allowMediator(mediator);
      await escrow.createTrade(seller, mediator, buyer, amount, tokenId, {
        from: seller,
      });
      await escrow.stakeNFT(tradeIndex, { from: seller });
      await escrow.stakeERC20(tradeIndex, { from: buyer });
      await expectRevert(
        escrow.unstakeERC20(tradeIndex, { from: thirdParty }),
        "Sender must be seller or buyer"
      );
    });
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
    await escrow.stakeERC20(tradeIndex, { from: buyer });
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
