// SPDX-Licesne-Identifier: MIT
pragma solidity ^0.8.7;

// Not inherited, it's a marketplace, not an NFT
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NftMarketplace__PriceMustBeAboveZero();
error NftMarketplace__NotYetApprovedForMarketplace();
// error code with args, no indexing
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NeitherOwnerNorApproved();
error NftMarketplace__NotListed();
error NftMarketplace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NftMarketplace__NoProceedsYet();
error NftMarketplace__Transactionfailed();

contract NftMarketplace is ReentrancyGuard {
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

event ItemBought(
    address indexed buyer,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 price
    );

event ItemCanceled(
    address indexed seller,
    address indexed nftAddress,
    uint256 indexed tokenId
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
// custom-defined due to nftAddress, tokenId
modifier isOwnerOrApproved (address nftAddress, uint256 tokenId, address spender) {
    IERC721 nft = IERC721(nftAddress);
    // return 'Owner'
    address owner = nft.ownerOf(tokenId);
    // check for owner AND approvedAddress
    if (spender != owner && spender!= nft.getApproved(tokenId)) {
        revert NftMarketplace__NeitherOwnerNorApproved();
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
isOwnerOrApproved (nftAddress, tokenId, msg.sender)
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
// 1 check:
// 1. IsItemListed on the MP

// 4 SECURITY MEASURES:
// 1. Reentrancy Guard (nonReentrant)
// 2. Pull over Push (updtaed proceeds, no auto-send to Seller, let it withdraw())
// 3. SafeTransferFrom() (avoided transferFrom())
// 4. SafeTransferFrom() at the end, after all state-changes done
function buyItem(address nftAddress, uint256 tokenId)
external payable
isListed(nftAddress, tokenId)
nonReentrant
 {
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
    // STATE CHANGES DONE PRIOR TO call safeTransferFrom() - Reentrancy-proof
    emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
}

// 2 checks: Owner?, Listed?
function cancelListing(address nftAddress, uint256 tokenId) 
external
isOwnerOrApproved(nftAddress, tokenId, msg.sender)
isListed(nftAddress, tokenId)
{
    delete (s_listings[nftAddress][tokenId]);
    emit ItemCanceled(msg.sender, nftAddress, tokenId);
}

// 2 checks: Owner?, Listed?
function updatePrice(address nftAddress, uint256 tokenId, uint256 newPrice)
external
isOwnerOrApproved(nftAddress, tokenId, msg.sender)
isListed(nftAddress, tokenId)
{
    s_listings[nftAddress][tokenId].price = newPrice;
    emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    // equivalent to re-listing the NFT, hence, same ItemListed event
}

function withdrawProceeds() external {
    uint256 proceeds = s_proceeds[msg.sender];
    if (proceeds <= 0) {
        revert NftMarketplace__NoProceedsYet();
    }
    // state change before proceeds-transfer
    s_proceeds[msg.sender] = 0;
    // Now, send the funds
    (bool success, ) = payable(msg.sender).call{value: proceeds}("");

    if(!success) {
        revert NftMarketplace__Transactionfailed();
    }
}

//////////////////////
///Getter functions///
//////////////////////

function getListing (address nftAddress, uint256 tokenId) 
external view returns (Listing memory) 
{
    return s_listings[nftAddress][tokenId];
}

function getProceeds(address seller) external view returns (uint256) {
    return s_proceeds[seller];
}

}

// A Decntralized NFT Marketplace
//     1. `listItem`  : List MFTs on Marketplace
//     2. `buyItem`   : Buy the listed NFTs
//     3. `cancelItem`: Cancel the Listed NFT
//     4. `updatePrice`: Update the price of listed NFT
//     5. `withdrawFunds`: withdraw the proceeds ffrom the sale of NFTs
