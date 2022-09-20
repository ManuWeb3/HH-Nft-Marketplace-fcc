const {network, ethers} = require("hardhat")
const {developmentChains, networkConfig} = require("../helper-hardhat-config.js")
const {verify} = require("../utils/verify")

module.exports = async function ({getNamedAccounts, deployments}) {     // get auto-pulled from hre, hence, all-time available
    const {deploy, log} = deployments
    const {deployer} = await getNamedAccounts()

    const chainId = network.config.chainId

    // deploy now
    console.log("------Deploying NftMarketplace.sol--------")
    const nftMarketplace = await deploy("NftMarketplace", {
        from: deployer,
        log: true,
        // args: args,
        waitConfirmations: network.config.blockConfirmations || 1, 
    })
    console.log("------NftMarketplace.sol deployed!!--------")

    // Now, verifying...
    // Verify on Etherscan, if it's Rinkeby
    if(!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying on Etherscan...")
        //args: []
        await verify(nftMarketplace.address)
        //  it takes address and args of the S/C as parameters
        log("-----------Verified---------------")
    }
}

module.exports.tags = ["all", "nftMarketplace"]