// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMetadata.sol";

/** Metadata contract where tokenURI is ipfs://<cid>/<tokenId */
contract MultiUriMetadata is IMetadata, Ownable {
    event URIChanged(string indexed newURI);
    event MetadataFrozen();

    string public baseURI;
    bool public metadataFrozen;

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
        return string(abi.encodePacked(baseURI, "/", tokenId));
    }
}