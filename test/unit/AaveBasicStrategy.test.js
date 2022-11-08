const { assert, expect } = require("chai");
const { ethers } = require("hardhat");
// Pas moyen de mettre un chemin relatif ?
const Erc20Token = require("/Users/alexiscerio/Desktop/Dossier Alexis/Code/UbrisVault/artifacts/contracts/mocks/Erc20Token.sol/Erc20Token.json");
const { BigNumber } = require("ethers");

describe("\nAaveBasicStrategy Unit Tests\n", function () {
  let strategy,
    tokenA,
    tokenB,
    aToken,
    vToken,
    owner,
    addr1,
    addr2,
    amount,
    amountToBorrow,
    aave,
    uniswap,
    chainlinkA,
    chainlinkB,
    priceA,
    priceB,
    ratioSwap,
    initialBalance;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const TokenA = await ethers.getContractFactory("Erc20Token");
    tokenA = await TokenA.deploy("Ethereum token", "ETH", BigNumber.from(100_000).mul((1e18).toString()));
    await tokenA.deployed();

    const TokenB = await ethers.getContractFactory("Erc20Token");
    tokenB = await TokenB.deploy("USDC Token", "USDC", BigNumber.from(100_000).mul((1e18).toString()));
    await tokenB.deployed();

    const AToken = await ethers.getContractFactory("Erc20Token");
    aToken = await AToken.deploy("Aave Supply Token", "aToken", 0);
    await aToken.deployed();

    const VToken = await ethers.getContractFactory("Erc20Token");
    vToken = await VToken.deploy("Aave Debt Token", "vToken", 0);
    await vToken.deployed();

    const ChainlinkA = await ethers.getContractFactory("ChainlinkMock");
    chainlinkA = await ChainlinkA.deploy(tokenA.address, 1500);
    await chainlinkA.deployed();

    const ChainlinkB = await ethers.getContractFactory("ChainlinkMock");
    chainlinkB = await ChainlinkB.deploy(tokenB.address, 1);
    await chainlinkB.deployed();

    [, priceA, , ,] = await chainlinkA.latestRoundData();
    [, priceB, , ,] = await chainlinkB.latestRoundData();
    ratioSwap = priceA / priceB;

    const Aave = await ethers.getContractFactory("AaveMock");
    aave = await Aave.deploy(tokenA.address, tokenB.address, aToken.address, vToken.address, ratioSwap);
    await aave.deployed();

    const Uniswap = await ethers.getContractFactory("UniswapMock");
    uniswap = await Uniswap.deploy(tokenA.address, tokenB.address, ratioSwap);
    await uniswap.deployed();

    const Strategy = await ethers.getContractFactory("InternalAaveBasicStrategy");
    strategy = await Strategy.deploy(
      tokenA.address,
      tokenB.address,
      aave.address,
      aave.address,
      uniswap.address,
      //uniswap.address,
      3000,
      chainlinkA.address,
      chainlinkB.address
    );
    await strategy.deployed();

    await tokenA.connect(owner).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));
    await tokenA.connect(addr1).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));
    await tokenA.connect(addr2).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));

    await tokenB.connect(owner).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));
    await tokenB.connect(addr1).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));
    await tokenB.connect(addr2).approve(strategy.address, BigNumber.from(100_000).mul((1e18).toString()));

    amount = 1000;
    amountToBorrow = amount * ratioSwap;
  });

  describe("\n\nTest Internal functions :\n", function () {
    beforeEach(async function () {
      await tokenA.connect(owner).transfer(strategy.address, amount * 10);
    });

    describe("\n-> _chainlinkPriceFeed() :", function () {
      it("Should return price value.", async function () {
        let [, priceA, , ,] = await chainlinkA.latestRoundData();
        let [, priceB, , ,] = await chainlinkB.latestRoundData();
        let result = priceA / priceB;

        expect(await strategy.chainlinkPriceFeed(true)).to.equal(result);
      });
    });

    describe("\n-> _supplyOnAavePool() :", function () {
      it("Should decrease tokenA balance.", async function () {
        initialBalance = await tokenA.balanceOf(strategy.address);
        await strategy.supplyOnAavePool(tokenA.address, amount);

        expect(await tokenA.balanceOf(strategy.address)).to.equal(initialBalance - amount);
      });

      it("Should increase aToken balance.", async function () {
        initialBalance = await aToken.balanceOf(strategy.address);
        await strategy.supplyOnAavePool(tokenA.address, amount);

        expect(await aToken.balanceOf(strategy.address)).to.equal(initialBalance + amount);
      });

      it("Should increase supplyAmounts[] balance.", async function () {
        initialBalance = await aave.supplyAmounts(strategy.address);
        await strategy.supplyOnAavePool(tokenA.address, amount);

        expect(await aave.supplyAmounts(strategy.address)).to.equal(parseInt(initialBalance) + parseInt(amount));
      });
    });

    describe("\n-> _withdrawFromAavePool() :", function () {
      it("Should decrease aToken balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        initialBalance = await aToken.balanceOf(strategy.address);
        await strategy.withdrawFromAavePool(tokenA.address, amount);

        expect(await aToken.balanceOf(strategy.address)).to.equal(initialBalance - amount);
      });

      it("Should increase tokenA balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        initialBalance = await tokenA.balanceOf(strategy.address);
        await strategy.withdrawFromAavePool(tokenA.address, amount);

        expect(await tokenA.balanceOf(strategy.address)).to.equal(parseInt(initialBalance) + amount);
      });

      it("Should decrease supplyAmounts[] balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        initialBalance = await aave.supplyAmounts(strategy.address);
        await strategy.withdrawFromAavePool(tokenA.address, amount);

        expect(await aave.supplyAmounts(strategy.address)).to.equal(initialBalance - amount);
      });
    });

    describe("\n-> _borrowOnAave() :", function () {
      it("Should increase vToken balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        initialBalance = await vToken.balanceOf(strategy.address);
        await strategy.borrowOnAave(tokenB.address, amountToBorrow, 2);

        expect(await vToken.balanceOf(strategy.address)).to.equal(initialBalance + amountToBorrow);
      });

      it("Should increase borrowAmounts[] balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        initialBalance = await aave.borrowAmounts(strategy.address);
        await strategy.borrowOnAave(tokenB.address, amountToBorrow, 2);

        expect(await aave.borrowAmounts(strategy.address)).to.equal(initialBalance + amountToBorrow);
      });

      it("Should increase tokenB balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        initialBalance = await tokenB.balanceOf(strategy.address);
        await strategy.borrowOnAave(tokenB.address, amountToBorrow, 2);

        expect(await tokenB.balanceOf(strategy.address)).to.equal(initialBalance + amountToBorrow);
      });
    });

    describe("\n-> _repayOnAave() :", function () {
      it("Should decrease vToken balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        await strategy.borrowOnAave(tokenB.address, amountToBorrow, 2);
        initialBalance = await vToken.balanceOf(strategy.address);
        await strategy.repayOnAave(tokenB.address, amountToBorrow, 2);

        expect(await vToken.balanceOf(strategy.address)).to.equal(initialBalance - amountToBorrow);
      });

      it("Should decrease borrowAmounts[] balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        await strategy.borrowOnAave(tokenB.address, amountToBorrow, 2);
        initialBalance = await aave.borrowAmounts(strategy.address);
        await strategy.repayOnAave(tokenB.address, amountToBorrow, 2);

        expect(await aave.borrowAmounts(strategy.address)).to.equal(initialBalance - amountToBorrow);
      });

      it("Should decrease tokenB balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        await strategy.borrowOnAave(tokenB.address, amountToBorrow, 2);
        initialBalance = await tokenB.balanceOf(strategy.address);
        await strategy.repayOnAave(tokenB.address, amountToBorrow, 2);

        expect(await tokenB.balanceOf(strategy.address)).to.equal(initialBalance - amountToBorrow);
      });
    });

    describe("\n-> _repayWithATokenOnAave() :", function () {
      it("Should decrease vToken balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        await strategy.borrowOnAave(tokenB.address, amountToBorrow, 2);
        initialBalance = await vToken.balanceOf(strategy.address);
        await strategy.repayWithATokenOnAave(tokenB.address, amount, 2);

        expect(await vToken.balanceOf(strategy.address)).to.equal(initialBalance - amountToBorrow);
      });

      it("Should decrease borrowAmounts[] balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        await strategy.borrowOnAave(tokenB.address, amountToBorrow, 2);
        initialBalance = await aave.borrowAmounts(strategy.address);
        await strategy.repayWithATokenOnAave(tokenB.address, amount, 2);

        expect(await aave.borrowAmounts(strategy.address)).to.equal(initialBalance - amountToBorrow);
      });

      it("Should decrease aToken balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        await strategy.borrowOnAave(tokenB.address, amountToBorrow, 2);
        initialBalance = await aToken.balanceOf(strategy.address);
        await strategy.repayWithATokenOnAave(tokenB.address, amount, 2);

        expect(await aToken.balanceOf(strategy.address)).to.equal(initialBalance - amount);
      });

      it("Should decrease supplyAmounts[] balance.", async function () {
        await strategy.supplyOnAavePool(tokenA.address, amount);
        await strategy.borrowOnAave(tokenB.address, amountToBorrow, 2);
        initialBalance = await aave.supplyAmounts(strategy.address);
        await strategy.repayWithATokenOnAave(tokenB.address, amount, 2);

        expect(await aave.supplyAmounts(strategy.address)).to.equal(initialBalance - amount);
      });
    });

    describe("\n-> _swapOnUniswap() :", function () {
      it("Should decrease tokenA balance.", async function () {
        initialBalance = await tokenA.balanceOf(strategy.address);
        await strategy.swapOnUniswap(tokenA.address, tokenB.address, amount, true);

        expect(await tokenA.balanceOf(strategy.address)).to.equal(initialBalance - amount);
      });

      it("Should increase tokenB balance.", async function () {
        initialBalance = await tokenB.balanceOf(strategy.address);
        await strategy.swapOnUniswap(tokenA.address, tokenB.address, amount, true);

        expect(await tokenB.balanceOf(strategy.address)).to.equal(initialBalance + amountToBorrow);
      });
    });

    describe("\n-> _strategy() :", function () {
      it("Should have increase aToken balance by : amount + (3/4 * amount), with leverage.", async function () {
        initialBalance = await aToken.balanceOf(strategy.address);
        await strategy.strategy(amount);

        expect(await aToken.balanceOf(strategy.address)).to.equal(initialBalance + (amount * 7) / 4);
      });

      it("Should have increase vToken balance.", async function () {
        initialBalance = await vToken.balanceOf(strategy.address);
        await strategy.strategy(amount);

        expect(await vToken.balanceOf(strategy.address)).to.equal(initialBalance + ((amount * 3) / 4) * ratioSwap);
      });

      it("Should have decrease tokenA balance.", async function () {
        initialBalance = await tokenA.balanceOf(strategy.address);
        await strategy.strategy(amount);

        expect(await tokenA.balanceOf(strategy.address)).to.equal(initialBalance - amount);
      });
    });

    describe("\n-> _strategyGasLess() :", function () {
      it("Should have increase aToken balance by : amount + (3/4 * amount), with leverage.", async function () {
        initialBalance = await aToken.balanceOf(strategy.address);
        await strategy.strategyGasLess(amount);

        expect(await aToken.balanceOf(strategy.address)).to.equal(initialBalance + (amount * 7) / 4);
      });

      it("Should have increase vToken balance.", async function () {
        initialBalance = await vToken.balanceOf(strategy.address);
        await strategy.strategyGasLess(amount);

        expect(await vToken.balanceOf(strategy.address)).to.equal(initialBalance + (amount * 3) / 4);
      });

      it("Should have decrease tokenA balance.", async function () {
        initialBalance = await tokenA.balanceOf(strategy.address);
        await strategy.strategyGasLess(amount);

        expect(await tokenA.balanceOf(strategy.address)).to.equal(initialBalance - amount);
      });
    });

    describe("\n-> _exitAave() :", function () {
      it("Should have decrease aToken balance by : amount * 2, with leverage.", async function () {
        await strategy.strategy(amount * 4);
        initialBalance = await aToken.balanceOf(strategy.address);
        await strategy.exitAave(amount);

        expect(await aToken.balanceOf(strategy.address)).to.equal(initialBalance - amount * 2);
      });

      it("Should have decrease vToken balance.", async function () {
        await strategy.strategy(amount * 4);
        initialBalance = await vToken.balanceOf(strategy.address);
        await strategy.exitAave(amount);

        expect(await vToken.balanceOf(strategy.address)).to.equal(initialBalance - amount * ratioSwap);
      });

      it("Should have increase tokenA balance.", async function () {
        await strategy.strategy(amount * 4);
        initialBalance = await tokenA.balanceOf(strategy.address);
        await strategy.exitAave(amount);

        expect(await tokenA.balanceOf(strategy.address)).to.equal(parseInt(initialBalance) + amount);
      });
    });

    describe("\n-> _exitAaveGasLess() :", function () {
      it("Should have decrease aToken balance by : amount * 2, with leverage.", async function () {
        await strategy.strategy(amount * 4);
        initialBalance = await aToken.balanceOf(strategy.address);
        await strategy.exitAaveGasLess(amount);

        expect(await aToken.balanceOf(strategy.address)).to.equal(initialBalance - amount * 2);
      });

      it("Should have decrease vToken balance.", async function () {
        await strategy.strategy(amount * 4);
        initialBalance = await vToken.balanceOf(strategy.address);
        await strategy.exitAaveGasLess(amount);

        expect(await vToken.balanceOf(strategy.address)).to.equal(initialBalance - amount * ratioSwap);
      });

      it("Should have increase tokenA balance.", async function () {
        await strategy.strategy(amount * 4);
        initialBalance = await tokenA.balanceOf(strategy.address);
        await strategy.exitAaveGasLess(amount);

        expect(await tokenA.balanceOf(strategy.address)).to.equal(parseInt(initialBalance) + amount);
      });
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
