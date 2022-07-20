// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@rari-capital/solmate/src/tokens/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@rari-capital/solmate/src/utils/ReentrancyGuard.sol";
import "@jbx-protocol/contracts-v2/contracts/JBETHERC20ProjectPayer.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IMetadata.sol";

// Custom Errors
error AUCTION_NOT_OVER();
error AUCTION_OVER();
error BID_TOO_LOW();
error ALREADY_HIGHEST_BIDDER();
error INVALID_DURATION();
error INVALID_TOKEN_ID();
error METADATA_IS_IMMUTABLE();
error TOKEN_TRANSFER_FAILURE();

contract NFTAuctionMachine is
    ERC721,
    Ownable,
    ReentrancyGuard,
    JBETHERC20ProjectPayer
{
    using Strings for uint256;

    IWETH9 public immutable weth; // WETH contract address
    uint256 public immutable auctionDuration; // Duration of auctions in seconds
    uint256 public immutable projectId; // Juicebox project id that will receive auction proceeds
    uint256 public totalSupply; // Total supply of the NFT, increases over time
    uint256 public auctionEndingAt; // Current auction ending time
    uint256 public highestBid; // Current highest bid
    address public highestBidder; // Current highest bidder
    IMetadata public metadata; // Metadata contract
    bool public metadataFrozen; // freeze status of the metadata contract

    event Bid(address indexed bidder, uint256 amount);
    event NewAuction(uint256 indexed auctionEndingAt, uint256 tokenId);
    event MetadataFrozen();

    /**
        Creates a new instance of NFTAuctionMachine
        @param _name Name.
        @param _symbol Symbol.
        @param _duration Duration of the auction.
        @param _projectId JB Project ID of a particular project to pay to.
        @param _metadata Address of a contract that returns tokenURI
        @param _weth WETH contract address
        @param _jbDirectory JB Directory contract address
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _duration,
        uint256 _projectId,
        IMetadata _metadata,
        IWETH9 _weth,
        IJBDirectory _jbDirectory
    )
        ERC721(_name, _symbol)
        JBETHERC20ProjectPayer(
            _projectId,
            payable(msg.sender),
            false,
            "NFT auction proceeds",
            "",
            false,
            IJBDirectory(_jbDirectory),
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
        weth = _weth;
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
    */
    function bid() public payable nonReentrant {
        if (block.timestamp > auctionEndingAt) {
            revert AUCTION_OVER();
        }
        if (msg.value < (highestBid + 0.001 ether)) {
            revert BID_TOO_LOW();
        }
        if (msg.sender == highestBidder) {
            revert ALREADY_HIGHEST_BIDDER();
        }

        uint256 lastAmount = highestBid;
        address lastBidder = highestBidder;

        highestBid = msg.value;
        highestBidder = msg.sender;

        if (lastAmount > 0) {
            (bool sent, ) = lastBidder.call{value: lastAmount, gas: 20000}("");
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
        if (block.timestamp <= auctionEndingAt) {
            revert AUCTION_NOT_OVER();
        }
        auctionEndingAt = block.timestamp + auctionDuration;

        if (highestBidder == address(0)) {
            unchecked {
                totalSupply++;
            }
            uint256 tokenId = totalSupply;
            emit Transfer(address(0), address(0), tokenId);
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
            emit NewAuction(auctionEndingAt, tokenId + 1);
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
    }

    /**
    @dev Updates the metadata contract address.
    @param _metadata Address of a contract that returns tokenURI
    */
    function setMetadata(IMetadata _metadata) external onlyOwner {
        if (metadataFrozen) {
            revert METADATA_IS_IMMUTABLE();
        }

        metadata = _metadata;
    }

    /**
    @dev Freezes the metadata contract.
    */
    function freezeMetadataInstance() external onlyOwner {
        metadataFrozen = true;
        emit MetadataFrozen();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(JBETHERC20ProjectPayer, ERC721)
        returns (bool)
    {
        return
            JBETHERC20ProjectPayer.supportsInterface(interfaceId) ||
            ERC721.supportsInterface(interfaceId);
    }
}
