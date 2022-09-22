// const { ethers } = require("hardhat")

const networkConfig = {
    4: {
        name: "rinkeby",
    },
    31337: {
        name: "hardhat",        
    },
    5: {
        name: "goerli",
    },
}

const developmentChains = ["hardhat", "localhost"]

module.exports = {
    networkConfig, 
    developmentChains,
}