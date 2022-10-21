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

  const ETH_MOCK = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
  const USDC_GOERLI_AAVE = "0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43";
  const USDC_POLYGON = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
  const USDC_MUMBAI_AAVE = "0x9aa7fEc87CA69695Dd1f879567CcF49F3ba417E2";
  const DAI_POLYGON = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";
  const WETH_MUMBAI = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa";
  const WETH_MUMBAI_AAVE = "0xd575d4047f8c667E064a4ad433D04E25187F40BB";
  const WMATIC_MUMBAI = "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889";
  const AAVE_POLYGON = "0x794a61358d6845594f94dc1db02a252b5b4814ad";
  const AAVE_REWARDS_POLYGON = "0x929EC64c34a17401F460460D4B9390518E5B473e";
  const AAVE_MUMBAI = "0x6C9fB0D5bD9429eb9Cd96B85B81d872281771E6B";
  const AAVE_GOERLI = "0x368EedF3f56ad10b9bC57eed4Dac65B26Bb667f6";
  const AAVE_REWARDS_GOERLI = "0x0eC5F4cD22a4EEF3fdC63a31c5b6A2418D429193";
  const PARASWAP_POLYGON = "0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57";
  const UNISWAP_ALL = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
  const UNISWAP_QUOTER_ALL = "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6";
  const CHAINLINK_GOERLI_ETHUSD = "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e";

  const args = [
    USDC_GOERLI_AAVE,
    USDC_GOERLI_AAVE,
    AAVE_GOERLI,
    AAVE_REWARDS_GOERLI,
    UNISWAP_ALL,
    UNISWAP_QUOTER_ALL,
    3000,
    CHAINLINK_GOERLI_ETHUSD,
    CHAINLINK_GOERLI_ETHUSD,
  ];

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
