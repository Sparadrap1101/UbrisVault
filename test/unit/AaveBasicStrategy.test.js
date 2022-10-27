const { assert, expect } = require("chai");
const { ethers } = require("hardhat");
// Pas moyen de mettre un chemin relatif ?
const Erc20Token = require("/Users/alexiscerio/Desktop/Dossier Alexis/Code/UbrisVault/artifacts/contracts/mocks/Erc20Token.sol/Erc20Token.json");
const { BigNumber } = require("ethers");

describe("\nAaveBasicStrategy Unit Tests\n", function () {
  let strategy,
    token,
    token2,
    aToken,
    vToken,
    owner,
    addr1,
    addr2,
    ownerBalance,
    amount,
    aave,
    uniswap,
    chainlinkA,
    chainlinkB;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Erc20Token");
    token = await Token.deploy("Ethereum token", "ETH", BigNumber.from(100_000).mul((1e18).toString()));
    await token.deployed();

    const Token2 = await ethers.getContractFactory("Erc20Token");
    token2 = await Token2.deploy("USDC Token", "USDC", BigNumber.from(100_000).mul((1e18).toString()));
    await token2.deployed();

    const AToken = await ethers.getContractFactory("Erc20Token");
    aToken = await AToken.deploy("Aave Supply Token", "aToken", 0);
    await aToken.deployed();

    const VToken = await ethers.getContractFactory("Erc20Token");
    vToken = await VToken.deploy("Aave Debt Token", "vToken", 0);
    await vToken.deployed();

    const Aave = await ethers.getContractFactory("AaveMock");
    aave = await Aave.deploy(token.address, token2.address, aToken.address, vToken.address);
    await aave.deployed();

    const Uniswap = await ethers.getContractFactory("UniswapMock");
    uniswap = await Uniswap.deploy(token.address, token2.address, 2);
    await uniswap.deployed();

    const ChainlinkA = await ethers.getContractFactory("ChainlinkMock");
    chainlinkA = await ChainlinkA.deploy(token.address, 1500);
    await chainlinkA.deployed();

    const ChainlinkB = await ethers.getContractFactory("ChainlinkMock");
    chainlinkB = await ChainlinkB.deploy(token.address, 1);
    await chainlinkB.deployed();

    const Strategy = await ethers.getContractFactory("InternalAaveBasicStrategy");
    strategy = await Strategy.deploy(
      token.address,
      token2.address,
      aave.address,
      aave.address,
      uniswap.address,
      //uniswap.address,
      3000,
      chainlinkA.address,
      chainlinkB.address
    );
    await strategy.deployed();

    await token.connect(owner).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token.connect(addr1).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token.connect(addr2).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));

    await token2.connect(owner).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token2.connect(addr1).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token2.connect(addr2).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));

    ownerBalance = (await token.balanceOf(owner.address)).toString();
    amount = BigNumber.from(100).mul((1e18).toString()).toString();
  });

  describe("\n-> enterStrategy() :", function () {
    it("Should reverts when you enter address(0)", async function () {
      expect((await strategy.chainlinkPriceFeed(true)).toString()).to.equal("1500");
    });
  });

  describe("\n-> enterStrategy() :", function () {
    it("Should reverts when you enter address(0)", async function () {
      await expect(
        strategy.enterStrategy("0x0000000000000000000000000000000000000000", owner.address, amount)
      ).to.be.revertedWith("WrongTokenStrategy");
    });
  });
});
