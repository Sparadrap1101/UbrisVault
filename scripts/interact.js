const { ethers, run, network } = require("hardhat");

async function main() {
  console.log("Starting...");
  const accounts = await ethers.getSigners();
  const contractAddress = "0x8E66dc0d9BD29d7c55e546B2e35fAB765b8De0E0";
  const myContract = await hre.ethers.getContractAt("UbrisVault", contractAddress);

  const interact = await myContract.testInteract(5);

  console.log(`Current value is: ${interact}`);

  const contractTokenAddress = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709";
  const amount = ethers.utils.parseEther("1");
  const myToken = await hre.ethers.getContractAt("ERC20", contractTokenAddress);

  let contractBalance = await myToken.balanceOf(myContract.address);
  let userDepositBalance = await myContract.getUserBalance(accounts[0].address, contractTokenAddress);
  let userBalance = await myToken.balanceOf(accounts[0].address);
  console.log(`User balance: ${userBalance}`);
  console.log(`User balance deposited on contract: ${userDepositBalance}`);
  console.log(`Contract balance: ${contractBalance}`);

  console.log("Approve & Deposit funds...");
  const hoho = await myToken.approve(contractAddress, amount);
  // Obligé d'attendre un bloc sinon l'approve peut ne pas être pris en compte
  const transactionReceipt3 = await hoho.wait(1);

  const allowance = await myToken.allowance(accounts[0].address, myContract.address);
  console.log(`Allowance: ${allowance}`);
  const hihi = await myContract.depositFunds(contractTokenAddress, amount);
  const transactionReceipt = await hihi.wait(1);

  contractBalance = await myContract.getTokenBalance(contractTokenAddress);
  userDepositBalance = await myContract.getUserBalance(accounts[0].address, contractTokenAddress);
  userBalance = await myToken.balanceOf(accounts[0].address);
  console.log(`User balance: ${userBalance}`);
  console.log(`User balance deposited on contract: ${userDepositBalance}`);
  console.log(`Contract balance: ${contractBalance}`);

  console.log("Withdrawing...");
  const hehe = await myContract.withdrawFunds(contractTokenAddress, amount);
  const transactionReceipt2 = await hehe.wait(1);

  contractBalance = await myContract.getTokenBalance(contractTokenAddress);
  userDepositBalance = await myContract.getUserBalance(accounts[0].address, contractTokenAddress);
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
