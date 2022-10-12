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

  const USDC_POLYGON = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
  const DAI_POLYGON = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";
  const WETH_MUMBAI = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa";
  const WMATIC_MUMBAI = "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889";
  const AAVE_POLYGON = "0x794a61358d6845594f94dc1db02a252b5b4814ad";
  const PARASWAP_POLYGON = "0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57";
  const UNISWAP_ALL = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

  const args = [USDC_POLYGON, DAI_POLYGON, AAVE_POLYGON, UNISWAP_ALL];

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
