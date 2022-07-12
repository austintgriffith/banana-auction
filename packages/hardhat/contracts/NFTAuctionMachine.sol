// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@rari-capital/solmate/src/tokens/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@rari-capital/solmate/src/utils/ReentrancyGuard.sol";
import "@jbx-protocol/contracts-v2/contracts/JBETHERC20ProjectPayer.sol";
import "./IWETH9.sol";

interface IMetadata {
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

// CUSTOM ERRORS will save gas
error AUCTION_NOT_OVER();
error AUCTION_OVER();
error BID_TOO_LOW();
error DUPLICATE_HIGHEST_BIDDER();
error INVALID_DURATION();
error INVALID_TOKEN_ID();
error TOKEN_TRANSFER_FAILURE();

contract NFTAuctionMachine is
    ERC721,
    Ownable,
    ReentrancyGuard,
    JBETHERC20ProjectPayer
{
    using Strings for uint256;

    // using constant can save gas more cheap than immutable hence hardcoded the address
    IWETH9 public constant weth =
        IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH contract
    // immutable vars to save gas
    uint256 public immutable auctionDuration; // Duration of auctions in seconds
    uint256 public immutable projectId; // Juicebox project id

    // initialising costs a bit of gas by default the value is 0
    uint256 public totalSupply; // total supply of the NFT
    uint256 public auctionEndingAt; // Current auction ending time
    uint256 public highestBid; // Current highest bid
    address public highestBidder; // Current highest bidder
    IMetadata public metadata; // Metadata contract
    bool public metadataFrozen; // Metadata mutability
    // string baseURI; // Base URI for all token URIs

    event Bid(address indexed bidder, uint256 amount);
    event NewAuction(uint256 indexed auctionEndingAt, uint256 tokenId);

    /**
        Creates a new instance of NFTAuctionMachine
        @param _name Name.
        @param _symbol Symbol.
        @param _duration Duration of the auction.
        @param _projectId JB Project ID of a particular project to pay to.
        @param _metadata Address of a contract that returns tokenURI
     */
    // @param uri Base URI.
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _duration,
        uint256 _projectId,
        IMetadata _metadata
    )
        // string memory uri
        ERC721(_name, _symbol)
        JBETHERC20ProjectPayer(
            _projectId,
            payable(msg.sender),
            false,
            "i love buffaloes",
            "",
            false,
            IJBDirectory(0xCc8f7a89d89c2AB3559f484E0C656423E979ac9C),
            address(this)
        )
    {
        if (_duration == 0) {
            revert INVALID_DURATION();
        }
        auctionDuration = _duration;
        auctionEndingAt = block.timestamp + _duration;
        projectId = _projectId;
        metadata = _metadata;
    }

    /**
    @dev Returns time remaining in the auction.
    */
    function timeLeft() public view returns (uint256) {
        if (block.timestamp > auctionEndingAt) {
            return 0;
        } else {
            return auctionEndingAt - block.timestamp;
        }
    }

    /**
    @dev Allows users to bid & send eth to the contract.
    with .call() there is a caveat around eth transfer, so even though the function follows the checks & effects pattern, we need nonReentrant to be extra secure
    */
    function bid() public payable nonReentrant {
        if (auctionEndingAt >= block.timestamp) {
            revert AUCTION_OVER();
        }
        if (msg.value < (highestBid + 0.001 ether)) {
            revert BID_TOO_LOW();
        }
        if (msg.sender == highestBidder) {
            revert DUPLICATE_HIGHEST_BIDDER();
        }

        uint256 lastAmount = highestBid;
        address lastBidder = highestBidder;

        highestBid = msg.value;
        highestBidder = msg.sender;

        if (lastAmount > 0) {
            (bool sent, ) = lastBidder.call{value: lastAmount}("");
            if (!sent) {
                weth.deposit{value: lastAmount}();
                bool success = weth.transfer(lastBidder, lastAmount);
                if (!success) {
                    revert TOKEN_TRANSFER_FAILURE();
                }
            }
        }

        emit Bid(msg.sender, msg.value);
    }

    /**
    @dev Allows anyone to mint the nft to the highest bidder/burn if there were no bids & restart the auction with a new end time.
    */
    function finalize() public {
        if (block.timestamp < auctionEndingAt) {
            revert AUCTION_NOT_OVER();
        }
        auctionEndingAt = block.timestamp + auctionDuration;

        if (highestBidder == address(0)) {
            unchecked {
                totalSupply++;
            }
            uint256 tokenId = totalSupply;
            _burn(tokenId);
        } else {
            uint256 lastAmount = highestBid;
            address lastBidder = highestBidder;

            highestBid = 0;
            highestBidder = address(0);

            _pay(
                projectId, //uint256 _projectId,
                JBTokens.ETH, // address _token
                lastAmount, //uint256 _amount,
                18, //uint256 _decimals,
                lastBidder, //address _beneficiary,
                0, //uint256 _minReturnedTokens,
                false, //bool _preferClaimedTokens,
                "nft mint", //string calldata _memo,
                "" //bytes calldata _metadata
            );

            unchecked {
                totalSupply++;
            }
            uint256 tokenId = totalSupply;
            _mint(lastBidder, tokenId);
            emit NewAuction(auctionEndingAt, totalSupply + 1);
        }
    }

    /**
    @dev Returns the token URI for a particular ID.
    @param tokenId Token ID to get metadata for
    */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (tokenId > totalSupply) {
            revert INVALID_TOKEN_ID();
        }

        return metadata.tokenURI(tokenId);
        // string memory base = _baseURI();
        // return string(abi.encodePacked(base, "/", tokenId));
    }

    /**
    @dev Updates the metadata contract address.
    @param _metadata Address of a contract that returns tokenURI
    */
    function setMetadata(IMetadata _metadata) external onlyOwner {
        require(!metadataFrozen, "Metadata is immutable");
        metadata = _metadata;
    }

    /**
    @dev Freezes the metadata contract address.
    */
    function freezeMetadata() external onlyOwner {
        metadataFrozen = true;
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(JBETHERC20ProjectPayer, ERC721)
        returns (bool)
    {
        return
            interfaceId == type(IJBProjectPayer).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

// Metadata contract where all NFTs get same metadata
contract SingleUriMetadata is IMetadata, Ownable {
    event URIChanged(string indexed newURI);
    event MetadataFrozen();

    string public uri;
    bool metadataFrozen;

    constructor(string memory _uri) {
        _setURI(_uri);
    }

    /**
    @dev Updates the URI.
    @param newURI New Base URI Value, should include ipfs:// prefix or equivalent.
    */
    function _setURI(string memory newURI) internal virtual onlyOwner {
        require(!metadataFrozen, "Metadata is immutable");
        uri = newURI;
        emit URIChanged(uri);
    }

    /**
    @dev Freezes the metadata uri.
    */
    function freezeMetadata() external onlyOwner {
        metadataFrozen = true;
        emit MetadataFrozen();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return string(uri);
    }
}

// Metadata contract where tokenURI is ipfs://<cid>/<tokenId>
contract MultiUriMetadata is IMetadata, Ownable {
    event URIChanged(string indexed newURI);
    event MetadataFrozen();

    string public baseURI;
    bool metadataFrozen;

    constructor(string memory _uri) {
        _setBaseURI(_uri);
    }

    /**
    @dev Updates the baseURI.
    @param newBaseURI New Base URI Value
    */
    function _setBaseURI(string memory newBaseURI) internal virtual onlyOwner {
        require(!metadataFrozen, "Metadata is immutable");
        baseURI = newBaseURI;
        emit URIChanged(baseURI);
    }

    /**
    @dev Freezes the metadata uri.
    */
    function freezeMetadata() external onlyOwner {
        metadataFrozen = true;
        emit MetadataFrozen();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return string(abi.encodePacked(baseURI, "/", tokenId));
    }
}
