const { ethers, run, network } = require("hardhat");

async function main() {
  console.log("Starting...");
  const accounts = await ethers.getSigners();
  const contractAddress = "0x46494D43a18da104CA41c5816FD05CDeD04eAfB4";
  const assetAddress = "0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43";
  const assetAddress2 = "0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43";
  const myContract = await hre.ethers.getContractAt("AaveBasicStrategy", contractAddress);
  const myToken = await hre.ethers.getContractAt("ERC20", assetAddress);
  const myToken2 = await hre.ethers.getContractAt("ERC20", assetAddress2);
  const amount = 1000;

  let userBalance = await myToken.balanceOf(contractAddress);
  console.log(`WETH contract balance: ${userBalance}`);
  userBalance = await myContract.getTotalStrategyBalance();
  console.log(`WETH contract balance by contract function: ${userBalance}`);
  let userBalance2 = await myToken2.balanceOf(contractAddress);
  console.log(`\nWMATIC contract balance: ${userBalance2}`);
  userBalance = await myToken.balanceOf(accounts[0].address);
  console.log(`\nWETH user balance: ${userBalance}`);
  userBalance2 = await myContract.getUserBalance(accounts[0].address);
  console.log(`WETH user balance by contract function: ${userBalance2}`);
  userBalance = await myContract.getStrategyATokenBalance();
  console.log(`\naToken contract balance by contract function: ${userBalance}`);
  userBalance = await myContract.getStrategyDebtTokenBalance();
  console.log(`debtToken contract balance by contract function: ${userBalance}`);
  userBalance = await myContract.getPureStrategyBalanceOnAave();
  console.log(`Pure contract balance on Aave by contract function: ${userBalance}`);
  [userBalance, ,] = await myContract.getHealthFactor(0);
  console.log(`\nHealthFactor contract by contract function: ${userBalance}`);

  const hoho = await myToken.approve(contractAddress, amount);
  await hoho.wait(1);
  const hihi = await myContract.enterStrategy(assetAddress, accounts[0].address, amount);
  await hihi.wait(1);

  userBalance = await myToken.balanceOf(contractAddress);
  console.log(`\n\nWETH contract balance: ${userBalance}`);
  userBalance = await myContract.getTotalStrategyBalance();
  console.log(`WETH contract balance by contract function: ${userBalance}`);
  userBalance2 = await myToken2.balanceOf(contractAddress);
  console.log(`\nWMATIC contract balance: ${userBalance2}`);
  userBalance = await myToken.balanceOf(accounts[0].address);
  console.log(`\nWETH user balance: ${userBalance}`);
  userBalance2 = await myContract.getUserBalance(accounts[0].address);
  console.log(`WETH user balance by contract function: ${userBalance2}`);
  userBalance = await myContract.getStrategyATokenBalance();
  console.log(`\naToken contract balance by contract function: ${userBalance}`);
  userBalance = await myContract.getStrategyDebtTokenBalance();
  console.log(`debtToken contract balance by contract function: ${userBalance}`);
  userBalance = await myContract.getPureStrategyBalanceOnAave();
  console.log(`Pure contract balance on Aave by contract function: ${userBalance}`);
  [userBalance, ,] = await myContract.getHealthFactor(0);
  console.log(`\nHealthFactor contract by contract function: ${userBalance}`);

  /*
  let userBalance2 = await myToken2.balanceOf(contractAddress);
  console.log(`\nWMATIC contract balance: ${userBalance2}`);
  let userBalance = await myToken.balanceOf(accounts[0].address);
  console.log(`\nWETH user balance: ${userBalance}`);
  userBalance2 = await myContract.getUserBalance(accounts[0].address);
  console.log(`WETH user balance by contract function: ${userBalance2}`);
  userBalance = await myContract.getStrategyATokenBalance();
  console.log(`\naToken contract balance by contract function: ${userBalance}`);
  userBalance = await myContract.getStrategyDebtTokenBalance();
  console.log(`debtToken contract balance by contract function: ${userBalance}`);
  userBalance = await myContract.getPureStrategyBalanceOnAave();
  console.log(`Pure contract balance on Aave by contract function: ${userBalance}`);
  [userBalance, ,] = await myContract.getHealthFactor(0);
  console.log(`\nHealthFactor contract by contract function: ${userBalance}`);

  console.log("a");
  const humhum = await myContract._swapOnUniswap(assetAddress, assetAddress2, amount, 3000, true);
  console.log("b");
  await humhum.wait(1);
  console.log("c");

  userBalance = await myToken.balanceOf(contractAddress);
  console.log(`WETH contract balance: ${userBalance}`);
  userBalance2 = await myToken2.balanceOf(contractAddress);
  console.log(`WMATIC contract balance: ${userBalance2}`);*/
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
