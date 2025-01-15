// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {MultiUtilityNFT} from "../src/MulitiUtilityNFT.sol";
import {PaymentToken} from "../src/mocks/PaymentToken.sol";
import {Sablier} from "../src/mocks/Sablier.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MulitiUtilityNFTTest is Test {
    MultiUtilityNFT public nft;
    PaymentToken paymentToken;
    Sablier sablier;

    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);

    bytes32[] public phase1MerkleProof;
    bytes32[] public phase2MerkleProof;

    bytes32 public phase1MerkleRoot;
    bytes32 public phase2MerkleRoot;

    uint256 public constant FULL_MINT_PRICE = 2 ether;
    uint256 public constant DISCOUNTED_MINT_PRICE = 0.5 ether;
    
    event NFTMinted(address indexed to, uint256 indexed tokenId, MultiUtilityNFT.MintingPhase currentPhase);
    event MintingPhaseUpdated(MultiUtilityNFT.MintingPhase newPhase);
    event VestingStreamCreated(uint256 streamId);
    event VestingTokensWithdrawn(uint256 streamId, uint256 amount);

    function setUp() public {
        vm.startPrank(owner);

        paymentToken = new PaymentToken();
        sablier = new Sablier();

        phase1MerkleRoot = keccak256(abi.encodePacked(user1));
        phase2MerkleRoot = keccak256(abi.encodePacked(user2));

        nft = new MultiUtilityNFT(
            address(paymentToken),
            address(sablier),
            FULL_MINT_PRICE,
            DISCOUNTED_MINT_PRICE
        );

        nft.setPhase(MultiUtilityNFT.MintingPhase.InActive);

        vm.stopPrank();

        phase1MerkleProof = new bytes32[](0);
        phase2MerkleProof = new bytes32[](0);
    }

    function testInitialState() public view {
        assertEq(address(nft.paymentToken()), address(paymentToken));
        assertEq(nft.sablierContractAddress(), address(sablier));
        assertEq(nft.fullMintPrice(), FULL_MINT_PRICE);
        assertEq(nft.discountedMintPrice(), DISCOUNTED_MINT_PRICE);
        assertEq(uint(nft.currentPhase()), uint(MultiUtilityNFT.MintingPhase.InActive));
    }

    function testSetPhase() public {
        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase1);

        assertEq(uint(nft.currentPhase()), uint(MultiUtilityNFT.MintingPhase.Phase1));
        vm.stopPrank();
    }

    function testSetPhase_NonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase1);
    }

    function testMint() public {
        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase1);
        nft.setMerkleRoot(MultiUtilityNFT.MintingPhase.Phase1, phase1MerkleRoot);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 expectedTokenId = nft.tokenIdCounter();
        vm.expectEmit(true, true, false, true);
        emit NFTMinted(user1, expectedTokenId, MultiUtilityNFT.MintingPhase.Phase1);
        nft.mint(phase1MerkleProof);
        assertEq(nft.balanceOf(user1), 1);
        vm.stopPrank();
    }

    // function testMintWithDiscount() public {
    //     vm.startPrank(owner);
    //     nft.setPhase(MultiUtilityNFT.MintingPhase.Phase2);
    //     nft.setMerkleRoot(MultiUtilityNFT.MintingPhase.Phase2, phase2MerkleRoot);
    //     vm.stopPrank();

    //     // Setup user2
    //     vm.startPrank(user2);
    //     paymentToken.mint(DISCOUNTED_MINT_PRICE);
    //     paymentToken.approve(address(nft), DISCOUNTED_MINT_PRICE);

    //     // Generate signature (matching the contract's verification)
    //     bytes32 messageHash = keccak256(abi.encodePacked(user2, block.chainid));  // user2 is msg.sender
    //     bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
    //     vm.stopPrank();

    //     // Owner signs the message
    //     vm.startPrank(owner);
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, ethSignedMessageHash);
    //     bytes memory signature = abi.encodePacked(r, s, v);
    //     vm.stopPrank();

    //     // Mint
    //     vm.startPrank(user2);
    //     uint256 expectedTokenId = nft.tokenIdCounter();
    //     vm.expectEmit(true, true, false, true);
    //     emit NFTMinted(user2, expectedTokenId, MultiUtilityNFT.MintingPhase.Phase2);
    //     nft.mintWithDiscount(signature, phase2MerkleProof);
    //     assertEq(nft.balanceOf(user2), 1);
    //     vm.stopPrank();
    // }

    function mintWithoutDiscount() public {
        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase3);
        vm.stopPrank();

        vm.startPrank(user1);
        paymentToken.mint(FULL_MINT_PRICE);
        paymentToken.approve(address(nft), FULL_MINT_PRICE);

        uint256 expectedTokenId = nft.tokenIdCounter();

        vm.expectEmit(true, true, false, true);
        emit NFTMinted(user1, expectedTokenId, MultiUtilityNFT.MintingPhase.Phase3);
        nft.mintWithoutDiscount();

        assertEq(nft.balanceOf(user1), 1);
        vm.stopPrank();
    }

    function testVestingStreamCreation() public {
        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase3);
        vm.stopPrank();

        vm.startPrank(user1);
        paymentToken.mint(FULL_MINT_PRICE);
        paymentToken.approve(address(nft), FULL_MINT_PRICE);
        nft.mintWithoutDiscount();
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit VestingStreamCreated(1);
        nft.createVestingStream();
        assertTrue(sablier.streamExists(1));
        vm.stopPrank();
    }

    function testWithdrawVestedTokens() public {
        testVestingStreamCreation();

        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit VestingTokensWithdrawn(1, FULL_MINT_PRICE);
        vm.warp(block.timestamp + 366 days);
        nft.withdrawVestedTokens(1);
        vm.stopPrank();
    }
}
