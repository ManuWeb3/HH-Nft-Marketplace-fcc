const { ethers, network } = require("hardhat")

const TOKEN_ID = 0      // the one in the Moralis DB server

async function cancel() {
    const nftMarketplace = await ethers.getContract("NftMarketplace")
    const basicNft = await ethers.getContract("BasicNft")
    
    const TxCancel = await nftMarketplace.cancelListing(basicNft.address, TOKEN_ID)
    await TxCancel.wait(1)
    console.log("NFT Canceled!!")

    // pertains to Moralis
    if(network.config.chainId == "31337") {
        await moveBlocks(2, (sleepAmount = 1000))
    }
}

cancel()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error)
    process.exit(1)
})