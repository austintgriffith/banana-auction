// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMetadata.sol";

/** Metadata contract where all NFTs get same metadata */
contract SingleUriMetadata is IMetadata, Ownable {
    event URIChanged(string indexed newURI);
    event MetadataFrozen();

    string public uri;
    bool public metadataFrozen;

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

    function isMetaDataFrozen() external override view returns (bool) {
        return metadataFrozen;
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