const { assert, expect } = require("chai");
const { ethers } = require("hardhat");
const Erc20Token = require("/home/hhk/Desktop/UbrisVault/UbrisVault/artifacts/contracts/mocks/Erc20Token.sol/Erc20Token.json");
const { BigNumber } = require("ethers");

describe("\nUbrisVault Unit Tests\n", function () {
  let vault, strategy, token, token2, owner, addr1, addr2, ownerBalance, amount;

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

    const Token2 = await ethers.getContractFactory("Erc20Token");
    token2 = await Token2.deploy("DAI Token", "DAI", BigNumber.from(100_000).mul((1e18).toString()));
    await token2.deployed();

    await token2.connect(owner).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token2.connect(addr1).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));
    await token2.connect(addr2).approve(vault.address, BigNumber.from(100_000).mul((1e18).toString()));

    const Strategy = await ethers.getContractFactory("StrategyTest");
    strategy = await Strategy.deploy(token.address);
    await strategy.deployed();

    ownerBalance = (await token.balanceOf(owner.address)).toString();
    amount = BigNumber.from(100).mul((1e18).toString()).toString();
  });

  describe("\n-> depositFunds() :", function () {
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
  });

  describe("\n-> withdrawFunds() :", function () {
    it("Should reverts when you enter address(0)", async function () {
      await expect(vault.withdrawFunds("0x0000000000000000000000000000000000000000", 1)).to.be.revertedWith(
        "This token doesn't exist."
      );
    });

    it("Should reverts if user haven't enough funds on the protocol", async function () {
      await expect(vault.withdrawFunds(token.address, amount)).to.be.revertedWith(
        "You can't withdraw more than your wallet funds, check your strategies."
      );
    });

    it("Should transfer funds back to the user", async function () {
      await vault.depositFunds(token.address, amount);
      assert.equal((await token.balanceOf(owner.address)).toString(), ownerBalance - amount);

      await vault.withdrawFunds(token.address, amount);
      assert.equal((await token.balanceOf(owner.address)).toString(), ownerBalance);
    });

    it("Should not transfer funds of another user", async function () {
      await vault.depositFunds(token.address, amount);
      await expect(vault.connect(addr1).withdrawFunds(token.address, amount)).to.be.revertedWith(
        "You can't withdraw more than your wallet funds, check your strategies."
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

  describe("\n-> addStrategy() :", function () {
    it("Should reverts if the user is not the owner of the protocol", async function () {
      await expect(vault.connect(owner).addStrategy(strategy.address, "Hey")).to.not.be.reverted;
      await expect(vault.connect(addr1).addStrategy(strategy.address, "Hey")).to.be.reverted;
    });

    it("Should reverts when you enter address(0)", async function () {
      await expect(vault.addStrategy("0x0000000000000000000000000000000000000000", "Hey")).to.be.revertedWith(
        "This strategy doesn't exist."
      );
    });

    it("Should reverts if the strategy address is already whitelist", async function () {
      await vault.addStrategy(strategy.address, "Best Strategy");
      await expect(vault.addStrategy(strategy.address, "Best Strategy2")).to.be.revertedWith(
        "This strategy is already whitelist."
      );
    });

    it("Should add the good name to the strategy arguments", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      assert.equal(await vault.getStrategyName(strategy.address), name);
    });

    it("Should update the good state to the strategy arguments", async function () {
      assert.equal(await vault.getStrategyState(strategy.address), 0);
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      assert.equal(await vault.getStrategyState(strategy.address), 1);
    });

    it("Should add the strategy on the whitelist in its arguments", async function () {
      assert.equal(await vault.isStrategyWhitelist(strategy.address), false);
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      assert.equal(await vault.isStrategyWhitelist(strategy.address), true);
    });

    it("Should emits an event", async function () {
      const name = "Best Strategy";
      await expect(vault.addStrategy(strategy.address, name)).to.emit(vault, "NewStrategy").withArgs(strategy.address, name);
    });
  });

  describe("\n-> removeStrategy() :", function () {
    it("Should reverts if the user is not the owner of the protocol", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);

      await expect(vault.connect(owner).removeStrategy(strategy.address)).to.not.be.reverted;
      await expect(vault.connect(addr1).removeStrategy(strategy.address)).to.be.reverted;
    });

    it("Should reverts when you enter address(0)", async function () {
      await expect(vault.removeStrategy("0x0000000000000000000000000000000000000000")).to.be.revertedWith(
        "This strategy doesn't exist."
      );
    });

    it("Should be in whitelist to be removed", async function () {
      await expect(vault.removeStrategy(strategy.address)).to.be.revertedWith("This strategy has already been removed.");
    });

    it("Should update the good state to the strategy arguments", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      assert.equal(await vault.getStrategyState(strategy.address), 1);
      await vault.removeStrategy(strategy.address);
      assert.equal(await vault.getStrategyState(strategy.address), 0);
    });

    it("Should removed the strategy of the whitelist in its arguments", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      assert.equal(await vault.isStrategyWhitelist(strategy.address), true);
      await vault.removeStrategy(strategy.address);
      assert.equal(await vault.isStrategyWhitelist(strategy.address), false);
    });

    it("Should emits an event", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await expect(vault.removeStrategy(strategy.address))
        .to.emit(vault, "StrategyRemoved")
        .withArgs(strategy.address, name);
    });
  });

  describe("\n-> pauseStrategy() :", function () {
    it("Should reverts if the user is not the owner of the protocol", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);

      await expect(vault.connect(owner).pauseStrategy(strategy.address)).to.not.be.reverted;
      await expect(vault.connect(addr1).pauseStrategy(strategy.address)).to.be.reverted;
    });

    it("Should reverts when you enter address(0)", async function () {
      await expect(vault.pauseStrategy("0x0000000000000000000000000000000000000000")).to.be.revertedWith(
        "This strategy doesn't exist."
      );
    });

    it("Should reverts if the strategy is not whitelist", async function () {
      await expect(vault.pauseStrategy(strategy.address)).to.be.revertedWith("This strategy is not whitelist.");
    });

    it("Should reverts if the state of the strategy is already CLOSE", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.pauseStrategy(strategy.address);
      await expect(vault.pauseStrategy(strategy.address)).to.be.revertedWith("This strategy is already in pause.");
    });

    it("Should update the state of the strategy to CLOSE", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      assert.equal(await vault.getStrategyState(strategy.address), 1);
      await vault.pauseStrategy(strategy.address);
      assert.equal(await vault.getStrategyState(strategy.address), 0);
    });

    it("Should emits an event", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await expect(vault.pauseStrategy(strategy.address)).to.emit(vault, "StrategyPaused").withArgs(strategy.address, name);
    });
  });

  describe("\n-> resumeStrategy() :", function () {
    it("Should reverts if the user is not the owner of the protocol", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.pauseStrategy(strategy.address);

      await expect(vault.connect(owner).resumeStrategy(strategy.address)).to.not.be.reverted;
      await expect(vault.connect(addr1).resumeStrategy(strategy.address)).to.be.reverted;
    });

    it("Should reverts when you enter address(0)", async function () {
      await expect(vault.resumeStrategy("0x0000000000000000000000000000000000000000")).to.be.revertedWith(
        "This strategy doesn't exist."
      );
    });

    it("Should reverts if the strategy is not whitelist", async function () {
      await expect(vault.resumeStrategy(strategy.address)).to.be.revertedWith("This strategy is not whitelist.");
    });

    it("Should reverts if the state of the strategy is already OPEN", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await expect(vault.resumeStrategy(strategy.address)).to.be.revertedWith("This strategy is already active.");
    });

    it("Should update the state of the strategy to OPEN", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.pauseStrategy(strategy.address);

      assert.equal(await vault.getStrategyState(strategy.address), 0);
      await vault.resumeStrategy(strategy.address);
      assert.equal(await vault.getStrategyState(strategy.address), 1);
    });

    it("Should emits an event", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.pauseStrategy(strategy.address);

      await expect(vault.resumeStrategy(strategy.address))
        .to.emit(vault, "StrategyResumed")
        .withArgs(strategy.address, name);
    });
  });

  describe("\n-> enterStrategy() :", function () {
    it("Should reverts when you enter address(0) for the strategy", async function () {
      await expect(
        vault.enterStrategy("0x0000000000000000000000000000000000000000", token.address, amount)
      ).to.be.revertedWith("This strategy doesn't exist.");
    });

    it("Should reverts when you enter address(0) for the token", async function () {
      await expect(
        vault.enterStrategy(strategy.address, "0x0000000000000000000000000000000000000000", amount)
      ).to.be.revertedWith("This token doesn't exist.");
    });

    it("Should reverts if the strategy is not whitelist", async function () {
      await expect(vault.enterStrategy(strategy.address, token.address, amount)).to.be.revertedWith(
        "This strategy is not on whitelist."
      );
    });

    it("Should reverts if the state of the strategy is CLOSE", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.pauseStrategy(strategy.address);

      await expect(vault.enterStrategy(strategy.address, token.address, amount)).to.be.revertedWith(
        "This strategy is not open."
      );
    });

    it("Should reverts if the token is not accepted in this strategy", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);

      await expect(vault.enterStrategy(strategy.address, token2.address, amount)).to.be.revertedWith(
        "This token is not accepted in this strategy."
      );
    });

    it("Should reverts if user haven't enough funds on the protocol", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);

      await expect(vault.enterStrategy(strategy.address, token.address, amount)).to.be.revertedWith(
        "You don't have enough funds to enter this strategy."
      );
    });

    it("Should transfer user funds to the strategy", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.depositFunds(token.address, amount);

      assert.equal((await token.balanceOf(vault.address)).toString(), amount);
      assert.equal((await token.balanceOf(strategy.address)).toString(), 0);
      await vault.enterStrategy(strategy.address, token.address, amount);
      assert.equal((await token.balanceOf(vault.address)).toString(), 0);
      assert.equal((await token.balanceOf(strategy.address)).toString(), amount);
    });

    it("Should decrements funds counter of the user in the protocol", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.depositFunds(token.address, amount);

      assert.equal((await vault.getUserBalance(owner.address, token.address)).toString(), amount);
      await vault.enterStrategy(strategy.address, token.address, amount);
      assert.equal((await vault.getUserBalance(owner.address, token.address)).toString(), 0);
    });

    it("Should emits an event", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.depositFunds(token.address, amount);

      await expect(vault.enterStrategy(strategy.address, token.address, amount))
        .to.emit(vault, "UserEnterStrategy")
        .withArgs(strategy.address, name, owner.address, amount);
    });
  });

  describe("\n-> exitStrategy() :", function () {
    it("Should reverts when you enter address(0) for the strategy", async function () {
      await expect(vault.exitStrategy("0x0000000000000000000000000000000000000000", amount)).to.be.revertedWith(
        "This strategy doesn't exist."
      );
    });

    it("Should reverts if user haven't enough funds on the protocol", async function () {
      await expect(vault.exitStrategy(strategy.address, amount)).to.be.revertedWith(
        "You don't have enough funds to withdraw."
      );
    });

    it("Should transfer user funds back to the protocol", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.depositFunds(token.address, amount);
      await vault.enterStrategy(strategy.address, token.address, amount);

      assert.equal((await token.balanceOf(vault.address)).toString(), 0);
      assert.equal((await token.balanceOf(strategy.address)).toString(), amount);
      await vault.exitStrategy(strategy.address, amount);
      assert.equal((await token.balanceOf(vault.address)).toString(), amount);
      assert.equal((await token.balanceOf(strategy.address)).toString(), 0);
    });

    it("Should increments funds counter of the user in the protocol", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.depositFunds(token.address, amount);
      await vault.enterStrategy(strategy.address, token.address, amount);

      assert.equal((await vault.getUserBalance(owner.address, token.address)).toString(), 0);
      await vault.exitStrategy(strategy.address, amount);
      assert.equal((await vault.getUserBalance(owner.address, token.address)).toString(), amount);
    });

    it("Should emits an event", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.depositFunds(token.address, amount);
      await vault.enterStrategy(strategy.address, token.address, amount);

      await expect(vault.exitStrategy(strategy.address, amount))
        .to.emit(vault, "UserExitStrategy")
        .withArgs(strategy.address, name, owner.address, amount);
    });
  });

  describe("\n-> recoltYield() :", function () {
    it("Should reverts if the user is not the owner of the protocol", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);

      await expect(vault.connect(owner).recoltYield(strategy.address)).to.not.be.reverted;
      await expect(vault.connect(addr1).recoltYield(strategy.address)).to.be.reverted;
    });

    it("Should reverts when you enter address(0)", async function () {
      await expect(vault.recoltYield("0x0000000000000000000000000000000000000000")).to.be.revertedWith(
        "This strategy doesn't exist."
      );
    });

    it("Should reverts if the strategy is not whitelist", async function () {
      await expect(vault.recoltYield(strategy.address)).to.be.revertedWith("This strategy is not on whitelist.");
    });

    it("Should reverts if the state of the strategy is CLOSE", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);
      await vault.pauseStrategy(strategy.address);

      await expect(vault.recoltYield(strategy.address)).to.be.revertedWith("This strategy is not open.");
    });

    it("/TEMPORARY\\ Should recolt the yield on the strategy", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);

      assert.equal(await strategy.strategyTest(), "Not called yet.");
      await vault.recoltYield(strategy.address);
      assert.equal(await strategy.strategyTest(), "Recolted.");
    });

    it("Should emits an event", async function () {
      const name = "Best Strategy";
      await vault.addStrategy(strategy.address, name);

      await expect(vault.recoltYield(strategy.address)).to.emit(vault, "YieldRecolted").withArgs(strategy.address, name);
    });
  });
});
