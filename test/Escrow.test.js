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

contract("MultiSigWalletByRelay", async (accounts) => {
  const [owner, buyer, seller, mediator, thirdParty] = accounts;

  let erc20;
  let erc721;
  let escrow;

  beforeEach(async () => {
    escrow = await Escrow.new();
    erc20 = await ERC20.new();
    erc721 = await ERC721.new();
  });
  describe(`test`, () => {
    it(``, async () => {});
  });
});
