// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiUtilityNFT {
    enum MintingPhase {
        Phase1,
        Phase2,
        Phase3
    }

    MintingPhase public currentPhase;

    address public paymentToken;

    uint256 public fullMintPrice;
    uint256 public discountedMintPrice;

    bytes32 phase1MerkleRoot;
    bytes32 phase2MerkleRoot;

    uint256 tokenIdCounter;
}