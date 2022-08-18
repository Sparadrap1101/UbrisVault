const { assert, expect } = require("chai");
const { ethers } = require("hardhat");
const Erc20Token = require("/home/hhk/Desktop/UbrisVault/UbrisVault/artifacts/contracts/mocks/Erc20Token.sol/Erc20Token.json");
const { BigNumber } = require("ethers");

describe("UbrisVault Unit Tests", function () {
  let vault, owner, addr1, addr2, token, ownerBalance, amount;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    const Vault = await ethers.getContractFactory("UbrisVault");
    vault = await Vault.deploy();
    await vault.deployed();

    const Token = await ethers.getContractFactory("Erc20Token");
    token = await Token.deploy("LINKCHAIN token", "LINK", BigNumber.from(100_000).mul((1e18).toString()));
    await token.deployed();

    await token.connect(owner).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token.connect(addr1).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token.connect(addr2).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));

    ownerBalance = (await token.balanceOf(owner.address)).toString();
    amount = BigNumber.from(100).mul((1e18).toString()).toString();
  });

  describe("depositFunds() :", function () {
    it("Should reverts when you enter address(0)", async function () {
      await expect(vault.depositFunds("0x0000000000000000000000000000000000000000", 1)).to.be.revertedWith(
        "This token doesn't exist."
      );
    });

    it("Should transfer funds to the contract", async function () {
      assert.equal((await token.balanceOf(vault.address)).toString(), 0);
      await vault.depositFunds(token.address, amount);
      assert.equal((await token.balanceOf(vault.address)).toString(), amount);
    });

    it("Should increments funds counter of the user in the protocol", async function () {
      assert.equal((await vault.getUserBalance(owner.address, token.address)).toString(), 0);
      await vault.depositFunds(token.address, amount);
      assert.equal((await vault.getUserBalance(owner.address, token.address)).toString(), amount);
    });

    it("Should emits an event", async function () {
      await expect(vault.depositFunds(token.address, amount))
        .to.emit(vault, "UserEnterProtocol")
        .withArgs(owner.address, token.address, amount);
    });

    // await network.provider.send("evm_increaseTime", [interval.toNumber() + 1]);
    // await network.provider.send("evm_mine", []);
  });

  describe("withdrawFunds() :", function () {
    it("Should reverts when you enter address(0)", async function () {
      await expect(vault.withdrawFunds("0x0000000000000000000000000000000000000000", 1)).to.be.revertedWith(
        "This token doesn't exist."
      );
    });

    it("Should reverts if user haven't enough funds on the protocol", async function () {
      await expect(vault.withdrawFunds(token.address, amount)).to.be.revertedWith(
        "You can't withdraw more than your wallet funds."
      );
    });

    // Add "it should reverts if not enough funds on the protocol" later.

    it("Should transfer funds back to the user", async function () {
      await vault.depositFunds(token.address, amount);
      assert.equal((await token.balanceOf(owner.address)).toString(), ownerBalance - amount);

      await vault.withdrawFunds(token.address, amount);
      assert.equal((await token.balanceOf(owner.address)).toString(), ownerBalance);
    });

    it("Should not transfer funds of another user", async function () {
      await vault.depositFunds(token.address, amount);
      await expect(vault.connect(addr1).withdrawFunds(token.address, amount)).to.be.revertedWith(
        "You can't withdraw more than your wallet funds."
      );
    });

    it("Should decrements funds counter of the user in the protocol", async function () {
      await vault.depositFunds(token.address, amount);
      assert.equal((await vault.getUserBalance(owner.address, token.address)).toString(), amount);

      await vault.withdrawFunds(token.address, amount);
      assert.equal((await vault.getUserBalance(owner.address, token.address)).toString(), 0);
    });

    it("Should emits an event", async function () {
      await vault.depositFunds(token.address, amount);
      await expect(vault.withdrawFunds(token.address, amount))
        .to.emit(vault, "UserExitProtocol")
        .withArgs(owner.address, token.address, amount);
    });
  });
});
