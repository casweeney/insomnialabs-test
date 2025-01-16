// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {MultiUtilityNFT} from "../../src/MulitiUtilityNFT.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Base } from "../Base.t.sol";

contract MulitiUtilityNFTTest is Base {
    function testMint() public {
        string[] memory freeMintUserProof = vm.parseJsonStringArray(phase1MerkleProofJson, ".0x14fab7ffc93cecea209cd310a18eb1a760a904a0.proof");

        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase1);
        nft.setMerkleRoot(MultiUtilityNFT.MintingPhase.Phase1, phase1MerkleRoot);
        vm.stopPrank();

        vm.startPrank(freeMintUser);
        bytes32[] memory userProof = new bytes32[](freeMintUserProof.length);

        for (uint256 i = 0; i < freeMintUserProof.length; i++) {
            userProof[i] = vm.parseBytes32(freeMintUserProof[i]);
        }

        uint256 expectedTokenId = nft.tokenIdCounter();
        vm.expectEmit(true, true, false, true);
        emit NFTMinted(freeMintUser, expectedTokenId, MultiUtilityNFT.MintingPhase.Phase1);
        nft.mint(userProof);
        assertEq(nft.balanceOf(freeMintUser), 1);
        vm.stopPrank();
    }

    function testMint_InvalidProof_Reverts() public {
        string[] memory freeMintUserProof = vm.parseJsonStringArray(phase2MerkleProofJson, ".0x9a3a60f5aee7aef1fb0d4da8534452a2e2a89d46.proof"); // used a wrong user proof

        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase1);
        nft.setMerkleRoot(MultiUtilityNFT.MintingPhase.Phase1, phase1MerkleRoot);
        vm.stopPrank();

        vm.startPrank(freeMintUser);
        bytes32[] memory userProof = new bytes32[](freeMintUserProof.length);

        for (uint256 i = 0; i < freeMintUserProof.length; i++) {
            userProof[i] = vm.parseBytes32(freeMintUserProof[i]);
        }

        vm.expectRevert("Invalid proof");

        nft.mint(userProof);
        vm.stopPrank();
    }

    function testMint_Twice_Reverts() public {
        string[] memory freeMintUserProof = vm.parseJsonStringArray(phase1MerkleProofJson, ".0x14fab7ffc93cecea209cd310a18eb1a760a904a0.proof");

        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase1);
        nft.setMerkleRoot(MultiUtilityNFT.MintingPhase.Phase1, phase1MerkleRoot);
        vm.stopPrank();

        vm.startPrank(freeMintUser);
        bytes32[] memory userProof = new bytes32[](freeMintUserProof.length);

        for (uint256 i = 0; i < freeMintUserProof.length; i++) {
            userProof[i] = vm.parseBytes32(freeMintUserProof[i]);
        }

        // mint first time
        nft.mint(userProof);

        vm.expectRevert("Already minted");
        // mint second time
        nft.mint(userProof);
        
        vm.stopPrank();
    }

    function testMintWithDiscount() public {
        string[] memory discountMintUserProof = vm.parseJsonStringArray(phase2MerkleProofJson, ".0x9a3a60f5aee7aef1fb0d4da8534452a2e2a89d46.proof");

        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase2);
        nft.setMerkleRoot(MultiUtilityNFT.MintingPhase.Phase2, phase2MerkleRoot);
        vm.stopPrank();

        vm.startPrank(discountMintUser);
        bytes32[] memory userProof = new bytes32[](discountMintUserProof.length);

        for (uint256 i = 0; i < discountMintUserProof.length; i++) {
            userProof[i] = vm.parseBytes32(discountMintUserProof[i]);
        }

        // Generate signature for Phase 2
        bytes32 messageHash = keccak256(abi.encodePacked(discountMintUser, block.chainid));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, ethSignedMessageHash);
        discountMintUserSignature = abi.encodePacked(r, s, v);
        
        paymentToken.mint(DISCOUNTED_MINT_PRICE);
        paymentToken.approve(address(nft), DISCOUNTED_MINT_PRICE);

        uint256 expectedTokenId = nft.tokenIdCounter();

        vm.expectEmit(true, true, false, true);
        emit NFTMinted(discountMintUser, expectedTokenId, MultiUtilityNFT.MintingPhase.Phase2);
        nft.mintWithDiscount(discountMintUserSignature, userProof);

        assertEq(nft.balanceOf(discountMintUser), 1);
        vm.stopPrank();
    }

    function testMintWithDiscount_SignatureReplay_Reverts() public {
        string[] memory discountMintUserProof = vm.parseJsonStringArray(phase2MerkleProofJson, ".0x9a3a60f5aee7aef1fb0d4da8534452a2e2a89d46.proof");
        string[] memory replayUserProof = vm.parseJsonStringArray(phase2MerkleProofJson, ".0x99cb7f24da7f4bf494bb9740a3ff46d07bee1525.proof");

        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase2);
        nft.setMerkleRoot(MultiUtilityNFT.MintingPhase.Phase2, phase2MerkleRoot);
        vm.stopPrank();

        // Generate signature for Phase 2
        bytes32 messageHash = keccak256(abi.encodePacked(discountMintUser, block.chainid));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, ethSignedMessageHash);
        discountMintUserSignature = abi.encodePacked(r, s, v);

        vm.startPrank(discountMintUser);
        bytes32[] memory userProof = new bytes32[](discountMintUserProof.length);

        for (uint256 i = 0; i < discountMintUserProof.length; i++) {
            userProof[i] = vm.parseBytes32(discountMintUserProof[i]);
        }
        
        paymentToken.mint(DISCOUNTED_MINT_PRICE);
        paymentToken.approve(address(nft), DISCOUNTED_MINT_PRICE);

        nft.mintWithDiscount(discountMintUserSignature, userProof);
        vm.stopPrank();

        vm.startPrank(replayUser);
        bytes32[] memory rUserProof = new bytes32[](replayUserProof.length);

        for (uint256 i = 0; i < replayUserProof.length; i++) {
            rUserProof[i] = vm.parseBytes32(replayUserProof[i]);
        }

        paymentToken.mint(DISCOUNTED_MINT_PRICE);
        paymentToken.approve(address(nft), DISCOUNTED_MINT_PRICE);

        vm.expectRevert("Signature already used");

        nft.mintWithDiscount(discountMintUserSignature, rUserProof);
        vm.stopPrank();
    }

    function testMintWithoutDiscount() public {
        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase3);
        vm.stopPrank();

        vm.startPrank(freeMintUser);
        paymentToken.mint(FULL_MINT_PRICE);
        paymentToken.approve(address(nft), FULL_MINT_PRICE);

        uint256 expectedTokenId = nft.tokenIdCounter();

        vm.expectEmit(true, true, false, true);
        emit NFTMinted(freeMintUser, expectedTokenId, MultiUtilityNFT.MintingPhase.Phase3);
        nft.mintWithoutDiscount();

        assertEq(nft.balanceOf(freeMintUser), 1);
        vm.stopPrank();
    }
}
