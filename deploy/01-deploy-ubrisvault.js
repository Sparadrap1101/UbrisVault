const { network, ethers } = require("hardhat");
const { verify } = require("../utils/verify.js");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const args = [];

  const ubrisvault = await deploy("UbrisVault", {
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
