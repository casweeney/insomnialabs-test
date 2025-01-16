// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {MultiUtilityNFT} from "../src/MulitiUtilityNFT.sol";
import {PaymentToken} from "../src/mocks/PaymentToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Base } from "./Base.t.sol";

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


    function testVestingStreamCreation() public {
        string memory fork_url = vm.envString("MAINNET_FORK_URL");
        uint256 mainnetFork = vm.createFork(fork_url);
        vm.selectFork(mainnetFork);

        vm.startPrank(owner);
        paymentToken = new PaymentToken();
        nft = new MultiUtilityNFT(
            address(paymentToken),
            0x3962f6585946823440d274aD7C719B02b49DE51E, // Ethereum Mainnet Sablier V2 address
            FULL_MINT_PRICE,
            DISCOUNTED_MINT_PRICE
        );
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase3);
        vm.stopPrank();

        vm.startPrank(freeMintUser);
        paymentToken.mint(FULL_MINT_PRICE);
        paymentToken.approve(address(nft), FULL_MINT_PRICE);
        nft.mintWithoutDiscount();
        vm.stopPrank();

        uint256 initialContractBalance = paymentToken.balanceOf(address(nft));
        assertEq(initialContractBalance, FULL_MINT_PRICE, "Incorrect contract balance before stream creation");

        vm.startPrank(owner);
        vm.expectEmit(false, false, false, false);
        emit VestingStreamCreated(0);
        nft.createVestingStream();
        
        vm.stopPrank();
    }

    function testCreateVestingStream_NoBalance_Reverts() public {
        string memory fork_url = vm.envString("MAINNET_FORK_URL");
        uint256 mainnetFork = vm.createFork(fork_url);
        vm.selectFork(mainnetFork);

        vm.startPrank(owner);
        paymentToken = new PaymentToken();
        nft = new MultiUtilityNFT(
            address(paymentToken),
            0x3962f6585946823440d274aD7C719B02b49DE51E,
            FULL_MINT_PRICE,
            DISCOUNTED_MINT_PRICE
        );
        
        vm.expectRevert("No tokens to vest");
        nft.createVestingStream();
        vm.stopPrank();
    }

    

    function testWithdrawVestedTokens() public {
        string memory fork_url = vm.envString("MAINNET_FORK_URL");
        uint256 mainnetFork = vm.createFork(fork_url);
        vm.selectFork(mainnetFork);

        vm.startPrank(owner);
        paymentToken = new PaymentToken();
        nft = new MultiUtilityNFT(
            address(paymentToken),
            0x3962f6585946823440d274aD7C719B02b49DE51E,
            FULL_MINT_PRICE,
            DISCOUNTED_MINT_PRICE
        );
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase3);
        vm.stopPrank();

        vm.startPrank(freeMintUser);
        paymentToken.mint(FULL_MINT_PRICE);
        paymentToken.approve(address(nft), FULL_MINT_PRICE);
        nft.mintWithoutDiscount();
        vm.stopPrank();

        vm.startPrank(owner);
        nft.createVestingStream();

        // Warp time past cliff period
        vm.warp(block.timestamp + 721 days); // Past the total duration of 720 days

        uint256 lockCountId = nft.lockCreationCount();
        uint256 lockId = nft.getLockId(lockCountId);
        uint256 balanceBefore = paymentToken.balanceOf(owner);

        vm.expectEmit(true, false, false, false);
        emit VestingTokensWithdrawn(lockId, 0);
        nft.withdrawVestedTokens(lockId);

        uint256 balanceAfter = paymentToken.balanceOf(owner);
        assertTrue(balanceAfter > balanceBefore, "Balance should increase after withdrawal");

        vm.stopPrank();
    }

    function testWithdrawVestedTokens_NotOwner_Reverts() public {
        string memory fork_url = vm.envString("MAINNET_FORK_URL");
        uint256 mainnetFork = vm.createFork(fork_url);
        vm.selectFork(mainnetFork);

        vm.startPrank(owner);
        paymentToken = new PaymentToken();
        nft = new MultiUtilityNFT(
            address(paymentToken),
            0x3962f6585946823440d274aD7C719B02b49DE51E,
            FULL_MINT_PRICE,
            DISCOUNTED_MINT_PRICE
        );

        vm.stopPrank();

        vm.startPrank(freeMintUser);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, freeMintUser));
        nft.withdrawVestedTokens(1);
        vm.stopPrank();
    }
}
