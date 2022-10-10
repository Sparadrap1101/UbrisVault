const { network, ethers } = require("hardhat");
const { verify } = require("../utils/verify.js");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  /*const args = [];

  const ubrisvault = await deploy("UbrisVault", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: 6,
  });*/

  const args = [
    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
    "0x794a61358d6845594f94dc1db02a252b5b4814ad",
    "0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57",
  ];
  // USDC, DAI, AAVE, PARASWAP

  const aaveBasicStrategy = await deploy("AaveBasicStrategy", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: 6,
  });

  const developmentChains = ["hardhat", "localhost"];

  if (!developmentChains.includes(network.name) && process.env.POLYGONSCAN_API_KEY) {
    log("Verifying...");
    await verify(aaveBasicStrategy.address, args);
  }
  log("--------------------------------");
};

module.exports.tags = ["all", "ubrisvault"];
