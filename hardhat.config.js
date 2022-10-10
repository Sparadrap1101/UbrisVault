require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy");
require("solidity-coverage");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("dotenv").config();

const RINKEBY_RPC_URL = process.env.RINKEBY_RPC_URL || "https://eth-rinkeby.alchemyapi";
const MUMBAI_RPC_URL = process.env.MUMBAI_RPC_URL || "https://eth-mumbai.alchemyapi";
const POLYGON_RPC_URL = process.env.POLYGON_RPC_URL || "https://eth-polygon.alchemyapi";
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "Your etherscan API key";
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || "Your polygonscan API key";
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "key";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
      blockConfirmations: 1,
    },
    rinkeby: {
      chainId: 4,
      blockConfirmations: 6,
      url: RINKEBY_RPC_URL,
      accounts: [PRIVATE_KEY],
    },
    mumbai: {
      chainId: 80001,
      blockConfirmations: 6,
      url: MUMBAI_RPC_URL,
      accounts: [PRIVATE_KEY],
    },
    polygon: {
      chainId: 137,
      blockConfirmations: 6,
      url: POLYGON_RPC_URL,
      accounts: [PRIVATE_KEY],
    },
  },

  etherscan: {
    apiKey: {
      polygon: POLYGONSCAN_API_KEY,
    },
  },

  gasReporter: {
    enabled: true,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
  },

  solidity: "0.8.7",

  namedAccounts: {
    deployer: {
      default: 0,
    },
    player: {
      default: 1,
    },
  },
};
