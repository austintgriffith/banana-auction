// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@rari-capital/solmate/src/tokens/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@jbx-protocol/contracts-v2/contracts/JBETHERC20ProjectPayer.sol";
import "./WETH9.sol";

// import "canonical-weth/contracts/WETH9.sol"; // would be preferable but incompatible pragma

contract NFTAuctionMachine is ERC721, Ownable, JBETHERC20ProjectPayer {
    using Strings for uint256;

    uint256 public immutable auctionDuration; // Duration of auctions in seconds
    uint256 public totalSupply = 0; // total supply of the NFT
    uint256 public auctionEndingAt; // Current auction ending time
    uint256 public highestBid; // Current highest bid
    address public highestBidder; // Current highest bidder
    uint256 public projectId; // Juicebox project id
    WETH9 public weth; // WETH contract
    string baseURI; // Base URI for all token URIs

    event Bid(address indexed bidder, uint256 amount);
    event BaseURIChanged(string indexed newBaseURI);
    event NewAuction(uint256 indexed auctionEndingAt, uint256 tokenId);

    constructor(
        string memory _name,
        string memory _symbol,
        address WETHADDRESS,
        uint256 _duration,
        uint256 _projectId,
        string memory uri
    )
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
        require(_duration > 0, "MUST HAVE DURATION");
        weth = WETH9(payable(WETHADDRESS));
        auctionDuration = _duration;
        auctionEndingAt = block.timestamp + _duration;
        projectId = _projectId;
        _setBaseURI(uri);
    }

    function _baseURI() internal view returns (string memory) {
        return baseURI;
    }

    function timeLeft() public view returns (uint256) {
        if (block.timestamp > auctionEndingAt) {
            return 0;
        } else {
            return auctionEndingAt - block.timestamp;
        }
    }

    function bid() public payable {
        require(block.timestamp < auctionEndingAt, "Auction over");
        require(msg.value >= highestBid + 0.001 ether, "Bid too low");
        require(msg.sender != highestBidder, "Already winning bid");

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

    function finalize() public returns (uint256) {
        require(block.timestamp >= auctionEndingAt, "Auction not over");
        auctionEndingAt = block.timestamp + auctionDuration;

        if (highestBidder == address(0)) {
            unchecked {
                totalSupply++;
            }
            uint256 tokenId = totalSupply;
            _burn(tokenId);
            return tokenId;
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
            return tokenId;
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(tokenId <= totalSupply, "Token does not exist");
        string memory base = _baseURI();

        return string(abi.encodePacked(base, "/", tokenId));
    }

    function _setBaseURI(string memory newBaseURI) internal virtual onlyOwner {
        baseURI = newBaseURI;
        emit BaseURIChanged(newBaseURI);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
    }

    // The following functions are overrides required by Solidity.

    // function _beforeTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) internal  {
    //     super._beforeTokenTransfer(from, to, tokenId);
    // }

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
