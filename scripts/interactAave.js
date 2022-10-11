const { ethers, run, network } = require("hardhat");

async function main() {
  console.log("Starting...");
  const accounts = await ethers.getSigners();
  const contractAddress = "0x2c40566a76F8261f67452bCd3F15e832E23eB318";
  const assetAddress = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa";
  const assetAddress2 = "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889";
  const myContract = await hre.ethers.getContractAt("AaveBasicStrategy", contractAddress);
  const myToken = await hre.ethers.getContractAt("ERC20", assetAddress);
  const myToken2 = await hre.ethers.getContractAt("ERC20", assetAddress2);
  const amount = 1000000000000000;

  /*
  const hoho = await myToken.approve(contractAddress, amount);
  await hoho.wait(1);

  const hihi = await myContract.enterStrategy(assetAddress, accounts[0].address, amount);
  await hihi.wait(1);

  const check = await myContract.strategyTest();
  console.log(check);

  const haha = await myContract.test(assetAddress, amount);
  await haha.wait(1);

  const hehe = await myContract.test2(assetAddress, amount);
  await hehe.wait(1);

  let contractBalance = await myToken.balanceOf(myContract.address);
  let userDepositBalance = await myContract.getUserBalance(accounts[0].address);
  let userBalance = await myToken.balanceOf(accounts[0].address);
  console.log(`User balance: ${userBalance}`);
  console.log(`User balance deposited on contract: ${userDepositBalance}`);
  console.log(`Contract balance: ${contractBalance}`);

  const huhu = await myContract.exitStrategy(accounts[0].address, amount);
  await huhu.wait(1);

  contractBalance = await myToken.balanceOf(myContract.address);
  userDepositBalance = await myContract.getUserBalance(accounts[0].address);
  userBalance = await myToken.balanceOf(accounts[0].address);
  console.log(`User balance: ${userBalance}`);
  console.log(`User balance deposited on contract: ${userDepositBalance}`);
  console.log(`Contract balance: ${contractBalance}`);
  */

  // const hihi = await myToken.transfer(contractAddress, amount);
  // await hihi.wait(1);

  const hoho = await myToken.approve(contractAddress, amount);
  await hoho.wait(1);

  let userBalance = await myToken.balanceOf(contractAddress);
  console.log(`WETH balance: ${userBalance}`);
  let userBalance2 = await myToken2.balanceOf(contractAddress);
  console.log(`WMATIC balance: ${userBalance2}`);

  const hihi = await myContract.enterStrategy(assetAddress, accounts[0].address, amount);
  await hihi.wait(1);

  userBalance = await myToken.balanceOf(contractAddress);
  console.log(`WETH balance: ${userBalance}`);
  userBalance2 = await myToken2.balanceOf(contractAddress);
  console.log(`WMATIC balance: ${userBalance2}`);

  console.log("a");
  const humhum = await myContract.test(amount);
  console.log("b");
  await humhum.wait(1);
  console.log("c");

  userBalance = await myToken.balanceOf(contractAddress);
  console.log(`WETH balance: ${userBalance}`);
  userBalance2 = await myToken2.balanceOf(contractAddress);
  console.log(`WMATIC balance: ${userBalance2}`);

  const test = await myContract.strategyTest();
  console.log(test);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
