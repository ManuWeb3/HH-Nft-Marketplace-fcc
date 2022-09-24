const { ethers } = require("hardhat")

// no 'main', this time 'mintAndList'
async function mintAndList() {
    // both the contracts should already be deployed till this point
    const nftMarketplace = await ethers.getContract("NftMarketplace")       // mined in Block #1
    const basicNft = await ethers.getContract("BasicNft")                   // mined in Block #2
    
    const MintTx = await basicNft.mintNft()                                 // mined in B#3
    const MintTxReceipt = await MintTx.wait(1)          // we need the tokenId to list the NFT
    const tokenId = MintTxReceipt.events[1].args.tokenId
    // approve() before listItem()
    console.log("Approving NFT-Marketplace to access BasicNft...")
    const approvalTx = await basicNft.approve(nftMarketplace.address, tokenId)  // mined in B#4
    await approvalTx.wait(1)
    console.log("Approved!!")
    // now listItem()
    console.log("Listing BasicNft...")
    const PRICE = ethers.utils.parseEther("0.01")       // 0.01 Ether
    const listTx = await nftMarketplace.listItem(basicNft.address, tokenId, PRICE) // // mined in B#5
    await listTx.wait(1)   
    console.log("Listed!!") 
}

mintAndList()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error)
    process.exit(1)
})