// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {MultiUtilityNFT} from "../src/MulitiUtilityNFT.sol";
import {PaymentToken} from "../src/mocks/PaymentToken.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";

contract Base is Test {
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
    address mainnetUser = 0xf584F8728B874a6a5c7A8d4d387C9aae9172D621;
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
        sablier = ISablierV2LockupLinear(0x3962f6585946823440d274aD7C719B02b49DE51E); // Ethereum mainnet address

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
}