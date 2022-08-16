const { assert, expect } = require("chai");
const { network, getNamedAccounts, deployments, ethers } = require("hardhat");

describe("UbrisVault Unit Tests", function () {
  let vault, deployer, owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    const Vault = await ethers.getContractFactory("UbrisVault");
    vault = await Vault.deploy();
  });

  describe("depositFunds", function () {
    it("Reverts when you enter address(0)", async function () {
      await expect(vault.depositFunds("0x0000000000000000000000000000000000000000", 1)).to.be.revertedWith(
        "This token doesn't exist."
      );
    });

    /*
    it("Reverts when you don't pay enough", async function () {
      await expect(vault.depositFunds()).to.be.revertedWith("Lottery__NotEnoughETHEntered");
    });

    it("Records players when they enter", async function () {
      await vault.enterLottery({ value: lotteryEntranceFee });
      const playerFromContract = await lottery.getPlayer(0);
      assert.equal(playerFromContract, deployer);
    });

    it("Emits event on enter", async function () {
      await expect(vault.enterLottery({ value: lotteryEntranceFee })).to.emit(lottery, "LotteryEnter");
    });

    it("Doesn't allow entrance when lottery is 'Calculating'", async function () {
      // The only way to get lotteryState in `Calculating` mode is to call `performUpkeep` function.
      await lottery.enterLottery({ value: lotteryEntranceFee });
      // We increase time of our local blockchain in order to be able to call `performUpkeep` without
      // waiting for our interval time. Then we mine 1 block, check HardHat docs for more.
      await network.provider.send("evm_increaseTime", [interval.toNumber() + 1]);
      await network.provider.send("evm_mine", []);
      // We pretend to be a Chainlink Keeper to activate `performUpkeep` function and change lotteryState.
      await lottery.performUpkeep([]);
      // Now lotteryState has changed to `Calculating` so we can perform our test.
      await expect(lottery.enterLottery({ value: lotteryEntranceFee })).to.be.revertedWith("Lottery__NotOpen");
    });
    */
  });
});
