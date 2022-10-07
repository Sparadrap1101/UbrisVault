const { ethers, run, network } = require("hardhat");

async function main() {
  console.log("Starting...");
  const accounts = await ethers.getSigners();
  const contractAddress = "0x7606c839B24b5A894b9602F3a506f69E2BE3A347";
  const assetAddress = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
  const myContract = await hre.ethers.getContractAt("AaveBasicStrategy", contractAddress);
  const myToken = await hre.ethers.getContractAt("ERC20", assetAddress);
  const amount = 100;

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
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
