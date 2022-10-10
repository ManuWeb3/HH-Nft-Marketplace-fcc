const {network} = require("hardhat")
const {developmentChains} = require("../helper-hardhat-config.js")
const {verify} = require("../utils/verify")
// 'networkConfig' and chainId of helper.js not really needed this time...
//  as there are no args to be pulled off it into our NFT-MP deploy script.

module.exports = async function ({getNamedAccounts, deployments}) {     // get auto-pulled from hre, hence, all-time available
    const {deploy, log} = deployments
    const {deployer} = await getNamedAccounts()

    // const chainId = network.config.chainId
    // args = [] -- optional
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
        console.log("Verifying on Testnet.Etherscan...")
        //args: []
        await verify(nftMarketplace.address)
        //  it takes address and args of the S/C as parameters
        console.log("-----------------")
    }
}

module.exports.tags = ["all", "nftMarketplace"]