const { assert, expect } = require("chai");
const { ethers } = require("hardhat");
// Pas moyen de mettre un chemin relatif ?
const Erc20Token = require("/Users/alexiscerio/Desktop/Dossier Alexis/Code/UbrisVault/artifacts/contracts/mocks/Erc20Token.sol/Erc20Token.json");
const { BigNumber } = require("ethers");

describe("\nAaveBasicStrategy Unit Tests\n", function () {
  let strategy, token, token2, owner, addr1, addr2, ownerBalance, amount;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    const Strategy = await ethers.getContractFactory("AaveBasicStrategy");
    strategy = await Strategy.deploy();
    await strategy.deployed();

    const Token = await ethers.getContractFactory("Erc20Token");
    token = await Token.deploy("Ethereum token", "ETH", BigNumber.from(100_000).mul((1e18).toString()));
    await token.deployed();

    await token.connect(owner).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token.connect(addr1).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token.connect(addr2).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));

    const Token2 = await ethers.getContractFactory("Erc20Token");
    token2 = await Token2.deploy("USDC Token", "USDC", BigNumber.from(100_000).mul((1e18).toString()));
    await token2.deployed();

    await token2.connect(owner).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token2.connect(addr1).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token2.connect(addr2).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));

    ownerBalance = (await token.balanceOf(owner.address)).toString();
    amount = BigNumber.from(100).mul((1e18).toString()).toString();
  });
});
