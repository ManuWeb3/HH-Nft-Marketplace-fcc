// SPDX-Licesne-Identifier: MIT
pragma solidity ^0.8.7;

// Not inherited, it's a marketplace, not an NFT
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

error NftMarketplace__PriceMustBeAboveZero();
error NftMarketplace__NotYetApprovedForMarketplace();
// error code with args, no indexing
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotOwner();
error NftMarketplace__NotListed();
error NftMarketplace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);

contract NftMarketplace {
// Types:
// item listed by the 'Lister' / seller on the MP.
struct Listing {
    uint256 price;
    address seller;
}

// Events:
event ItemListed(
    address indexed Seller, 
    address indexed NftAddress, 
    uint256 indexed tokenId, 
    uint256 price
);

// Mappings:
// Nft address => NFT tokenId => Listing (price + seller)
mapping(address => mapping(uint256 => Listing)) private s_listings;
// Seller => proceeds accrued out of sale of its NFTs
mapping(address => uint256) private s_proceeds;

// Modifiers:
modifier notListed (address nftAddress, uint256 tokenId, address owner) {
    Listing memory listing = s_listings[nftAddress][tokenId];
    if(listing.price > 0) {
        revert NftMarketplace__AlreadyListed(nftAddress, tokenId);
    }
    _;
}

modifier isOwner (address nftAddress, uint256 tokenId, address spender) {
    IERC721 nft = IERC721(nftAddress);
    address owner = nft.ownerOf(tokenId);
    if (spender != owner) {
        revert NftMarketplace__NotOwner();
    }
    _;
}

modifier isListed (address nftAddress, uint256 tokenId) {
    Listing memory listing = s_listings[nftAddress][tokenId];
    if(listing.price <= 0) {
        revert NftMarketplace__NotListed();
    }
    _;
}

/////////////////////
///Main functions///
////////////////////

/**
 * @notice method for listing the NFTs on Marketplace
 * @param nftAddress: The address of NFT
 * @param tokenId: The Token ID of NFT
 * @param price: The sale price of the NFT
 * @dev Technically, we could have the escrow contract for the NFTs...
 * but this way people can still hold their NFTs through mappings, etc.
 */

// 3 checks: 
// 1. not already listed, 2. lister is the owner of NFT, 3. price > 0 (already listed)
function listItem (address nftAddress, uint256 tokenId, uint256 price)
external  
notListed (nftAddress, tokenId, msg.sender) 
isOwner (nftAddress, tokenId, msg.sender)
{
    // ext., since other projects will invoke this f() from outside
    if(price <= 0) {
        revert NftMarketplace__PriceMustBeAboveZero();
    }
    // Listing is NFT transfer
    // 1. Transfer NFT to the Marketplace contract. So, MP will own the NFT. What about the buyer then?
    // 2. Owner / buyer owns the NFT and gives MP the approval to sell it. - by Artion
    // Hence, call getApproved() to give REVOCABLE approval to the MP for selling it
    IERC721 nft = IERC721(nftAddress);
    if(nft.getApproved(tokenId) != address(this)) {
        revert NftMarketplace__NotYetApprovedForMarketplace();
    }
    // to keep a record of all the NFTs, mapping to the 'Listing' is better than an array
    s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
    // msg.sender in this case is the Lister/Seller

    // event emitting is too imp.
    emit ItemListed(msg.sender, nftAddress, tokenId, price);
}

// NatSpec
// 1 checks:
// 1. IsItemListed on the MP
function buyItem(address nftAddress, uint256 tokenId)
isListed(nftAddress, tokenId)
external payable {
    Listing memory listedItem = s_listings[nftAddress][tokenId];
    // check the amount sent with the NFT's price
    if(msg.value < listedItem.price) {
        revert NftMarketplace__PriceNotMet(nftAddress, tokenId, listedItem.price);
    }
    // keeping a track of the seller (struct.member) => accrued proceeds, thru mapping
    s_proceeds[listedItem.seller] = s_proceeds[listedItem.seller] + msg.value;
    // delete the specific mapping instance after NFT is bought
    delete (s_listings[listedItem.seller][tokenId]);
    // transfer the NFT from Lister/Seller to the Buyer: safeTransferFrom()
    // IERC721 nft = IERC721(nftAddress);
    // address owner = nft.ownerOf(tokenId);
    // owner.safeTransferFrom(listedItem.seller, msg.sender, tokenId); --> syntactically wrong... 
    // has to be an object of Type: IERC721(address) --> correct syntax
    IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);
    

}
}

// A Decntralized NFT Marketplae
//     1. `listItem`  : List MFTs on Marketplace
//     2. `buyItem`   : Buy the listed NFTs
//     3. `cancelItem`: Cancel the Listed NFT
//     4. `updatePrice`: Update the price of listed NFT
//     5. `withdrawFunds`: withdraw the proceeds ffrom the sale of NFTs
