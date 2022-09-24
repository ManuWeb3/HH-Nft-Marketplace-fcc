const { ethers, network } = require("hardhat")

const TOKEN_ID = 2          // or freshly minted TokenId that shows up on Moralis

async function buyListing() {

    const nftMarketplace = await ethers.getContract("NftMarketplace")        
    const basicNft = await ethers.getContract("BasicNft")
    // getting the 'price' of the listing to be bought
    const listing = await nftMarketplace.getListing(basicNft.address, TOKEN_ID)
    const price = listing.price.toString()
    // Buy Item - syntax to send ETH - payable f()
    const TxBuy = await nftMarketplace.buyItem(basicNft.address, TOKEN_ID, {value: price})
    await TxBuy.wait(1)
    console.log("Item Bought!!")
    // pertains to Moralis
    if(network.config.chainId == "31337") {
        await moveBlocks(2, (sleepAmount = 1000))
    }
}

buyListing()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error)
    process.exit(1)
})