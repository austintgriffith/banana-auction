// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IMetadata {
    function tokenURI(uint256 _tokenId) external view returns (string memory);

    function isMetaDataFrozen() external view returns (bool);
}