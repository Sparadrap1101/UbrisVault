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
  const args = ["0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", "0x794a61358d6845594f94dc1db02a252b5b4814ad"];

  const aaveBasicStrategy = await deploy("AaveBasicStrategy", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: 6,
  });

  const developmentChains = ["hardhat", "localhost"];

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...");
    await verify(ubrisvault.address, args);
  }
  log("--------------------------------");
};

module.exports.tags = ["all", "ubrisvault"];
