// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./WETH9.sol";
import "@jbx-protocol/contracts-v2/contracts/JBETHERC20ProjectPayer.sol";

contract NFTAuctionMachine is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    JBETHERC20ProjectPayer
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public auctionDuration;

    WETH9 public weth;

    IJBProjectPayer public jb;
    // IJBPaymentTerminal public terminal = directory.primaryTerminalOf(_projectId, _token);

    string public hardcodedTokenURI;

    uint256 public jbProjectId;

    constructor(
        string memory _name,
        string memory _symbol,
        address WETHADDRESS,
        address JBADDRESS,
        uint256 duration,
        string memory uri,
        uint256 projectId
    )
        ERC721(_name, _symbol)
        JBETHERC20ProjectPayer(
            projectId,
            msg.sender,
            false,
            "i love buffalos",
            "",
            false,
            address(0xCc8f7a89d89c2AB3559f484E0C656423E979ac9C),
            address(this)
        )
    {
        require(duration > 0, "MUST HAVE DURATION");
        weth = WETH9(payable(WETHADDRESS));
        jb = IJBProjectPayer(payable(JBADDRESS));
        auctionDuration = duration;
        auctionEndingAt = block.timestamp + auctionDuration;
        hardcodedTokenURI = uri;
        jbProjectId = projectId;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    event Bid(address indexed bidder, uint256 amount);

    uint256 public auctionEndingAt;

    uint256 public highestBid;
    address public highestBidder;

    function timeLeft() public view returns (uint256) {
        if (block.timestamp > auctionEndingAt) {
            return 0;
        } else {
            return auctionEndingAt - block.timestamp;
        }
    }

    //king of the hill type bid
    function bid() public payable {
        require(block.timestamp < auctionEndingAt, "BIDDING IS CLOSED");
        require(msg.value >= highestBid + 0.001 ether, "BID MOAR PLZ");
        require(msg.sender != highestBidder, "YOU ALREADY KING");

        uint256 lastAmount = highestBid;
        address lastBidder = highestBidder;

        highestBid = msg.value;
        highestBidder = msg.sender;

        if (lastAmount > 0) {
            (bool sent, ) = lastBidder.call{value: lastAmount}("");
            if (!sent) {
                weth.deposit{value: lastAmount}();
                require(
                    weth.transfer(lastBidder, lastAmount),
                    "Payment failed"
                );
            }
        }

        emit Bid(msg.sender, msg.value);
    }

    //function execute
    function finalize() public returns (uint256) {
        require(block.timestamp >= auctionEndingAt, "NOT YET");
        auctionEndingAt = block.timestamp + auctionDuration;

        if (highestBidder == address(0)) {
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(
                address(0x000000000000000000000000000000000000dEaD),
                tokenId
            );
            _setTokenURI(tokenId, hardcodedTokenURI);
            return tokenId;
        } else {
            uint256 lastAmount = highestBid;
            address lastBidder = highestBidder;

            highestBid = 0;
            highestBidder = address(0);

            jb.pay{value: lastAmount}(
                jbProjectId, //uint256 _projectId,
                address(0), // address _token
                lastAmount, //uint256 _amount,
                18, //uint256 _decimals,
                lastBidder, //address _beneficiary,
                0, //uint256 _minReturnedTokens,
                false, //bool _preferClaimedTokens,
                "i love buffalos", //string calldata _memo,
                "" //bytes calldata _metadata
            );

            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(lastBidder, tokenId);
            _setTokenURI(tokenId, hardcodedTokenURI); // BYO METADATA
            return tokenId;
        }
    }

    // function updateJBPaymentTerminal() external {
    //     terminal = directory.primaryTerminalOf(_projectId, _token);
    // }

    // The following functions are overrides required by Solidity.

    // function _beforeTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) internal override(ERC721, ERC721Enumerable) {
    //     super._beforeTokenTransfer(from, to, tokenId);
    // }

    // function _burn(uint256 tokenId)
    //     internal
    //     override(ERC721, ERC721URIStorage)
    // {
    //     super._burn(tokenId);
    // }

    // function tokenURI(uint256 tokenId)
    //     public
    //     view
    //     override(ERC721, ERC721URIStorage)
    //     returns (string memory)
    // {
    //     return super.tokenURI(tokenId);
    // }


}
