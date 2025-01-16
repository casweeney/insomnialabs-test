// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {MultiUtilityNFT} from "../src/MulitiUtilityNFT.sol";
import {PaymentToken} from "../src/mocks/PaymentToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";

contract MulitiUtilityNFTTest is Test {
    MultiUtilityNFT public nft;
    PaymentToken paymentToken;
    ISablierV2LockupLinear sablier;
    string projectPath = vm.projectRoot();

    string phase1MerkleProof;
    string phase2MerkleProof;

    string phase1MerkleProofJson;
    string phase2MerkleProofJson;

    bytes32 public phase1MerkleRoot;
    bytes32 public phase2MerkleRoot;

    address owner;
    uint256 ownerPrivateKey;
    address freeMintUser = 0x14fAB7Ffc93CECea209cd310A18eb1a760A904a0; // user from the phase1 addresses
    address discountMintUser = 0x9a3A60f5AEE7aef1fB0d4DA8534452A2E2A89d46; // user from the phase2 addresses
    address replayUser = 0x99cb7f24Da7F4BF494BB9740a3FF46D07Bee1525; //user to replay signature
    bytes discountMintUserSignature;

    uint256 public constant FULL_MINT_PRICE = 2 ether;
    uint256 public constant DISCOUNTED_MINT_PRICE = 0.5 ether;
    
    event NFTMinted(address indexed to, uint256 indexed tokenId, MultiUtilityNFT.MintingPhase currentPhase);
    event MintingPhaseUpdated(MultiUtilityNFT.MintingPhase newPhase);
    event VestingStreamCreated(uint256 streamId);
    event VestingTokensWithdrawn(uint256 streamId, uint256 amount);

    function setUp() public {
        (owner, ownerPrivateKey) = makeAddrAndKey("owner");

        vm.startPrank(owner);

        paymentToken = new PaymentToken();

        nft = new MultiUtilityNFT(
            address(paymentToken),
            address(sablier),
            FULL_MINT_PRICE,
            DISCOUNTED_MINT_PRICE
        );

        nft.setPhase(MultiUtilityNFT.MintingPhase.InActive);

        vm.stopPrank();

        phase1MerkleProof = string.concat(projectPath, "/script/typescript/gen_files/freeMerkleProof.json");
        phase2MerkleProof = string.concat(projectPath, "/script/typescript/gen_files/discountMerkleProof.json");

        phase1MerkleProofJson = vm.readFile(phase1MerkleProof);
        phase2MerkleProofJson = vm.readFile(phase2MerkleProof);

        phase1MerkleRoot = vm.parseJsonBytes32(phase1MerkleProofJson, ".root");
        phase2MerkleRoot = vm.parseJsonBytes32(phase2MerkleProofJson, ".root");
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

    function testSetPhase_NonOwner_Reverts() public {
        vm.prank(freeMintUser);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, freeMintUser));
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase1);
    }

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

    function testMintWithDiscount_Twice_Reverts() public {
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
        
        paymentToken.mint(DISCOUNTED_MINT_PRICE * 2);
        paymentToken.approve(address(nft), DISCOUNTED_MINT_PRICE);

        nft.mintWithDiscount(discountMintUserSignature, userProof);

        vm.expectRevert("Already minted");
        nft.mintWithDiscount(discountMintUserSignature, userProof);

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
        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintingPhase.Phase3);
        vm.stopPrank();

        vm.startPrank(freeMintUser);
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

    // function testWithdrawVestedTokens() public {
    //     testVestingStreamCreation();

    //     vm.startPrank(owner);
    //     vm.expectEmit(true, true, false, true);
    //     emit VestingTokensWithdrawn(1, FULL_MINT_PRICE);
    //     vm.warp(block.timestamp + 366 days);
    //     nft.withdrawVestedTokens(1);
    //     vm.stopPrank();
    // }
}
