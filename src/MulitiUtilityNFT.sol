// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import {Broker, LockupLinear} from "@sablier/v2-core/src/types/DataTypes.sol";
import {ud60x18} from "@prb/math/src/UD60x18.sol";


contract MultiUtilityNFT is ERC721, Ownable, ReentrancyGuard {
    enum MintingPhase {
        InActive,
        Phase1,
        Phase2,
        Phase3
    }

    MintingPhase public currentPhase;

    address public paymentToken;
    address public sablierContractAddress;

    uint256 public tokenIdCounter;
    uint256 public fullMintPrice;
    uint256 public discountedMintPrice;

    bytes32 phase1MerkleRoot;
    bytes32 phase2MerkleRoot;

    mapping(bytes => bool) public usedSignatures;
    mapping(address => bool) public hasMinted;

    event NFTMinted(address indexed to, uint256 indexed tokenId, MintingPhase currentPhase);
    event MintingPhaseUpdated(MintingPhase newPhase);
    event VestingStreamCreated(uint256 streamId);
    event VestingTokensWithdrawn(uint256 streamId, uint256 amount);

    constructor(
        address _paymentToken,
        address _sablierContractAddress,
        uint256 _fullMintPrice,
        uint256 _discountedMintPrice
    ) ERC721("MultiUtilityNFT", "MNFT") Ownable(msg.sender) {
        paymentToken = _paymentToken;
        sablierContractAddress = _sablierContractAddress;
        fullMintPrice = _fullMintPrice;
        discountedMintPrice = _discountedMintPrice;
        currentPhase = MintingPhase.InActive;
    }

    modifier isMerkleRootSet {
        if (currentPhase == MintingPhase.Phase1) {
            require(phase1MerkleRoot != bytes32(0), "Merkle root not set");
        } else if (currentPhase == MintingPhase.Phase2) {
            require(phase2MerkleRoot != bytes32(0), "Merkle root not set");
        }
        _;
    }

    function setPhase(MintingPhase _currentPhase) external onlyOwner {
        currentPhase = _currentPhase;
        emit MintingPhaseUpdated(_currentPhase);
    }

    function setMerkleRoot(MintingPhase _currentPhase, bytes32 _merkleRoot) external onlyOwner {
        if(_currentPhase == MintingPhase.Phase1) {
            phase1MerkleRoot = _merkleRoot;
        } else if (_currentPhase == MintingPhase.Phase2) {
            phase2MerkleRoot = _merkleRoot;
        }
    }

    function verifySignature(bytes memory _signature) internal view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, block.chainid));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, _signature);
        return signer == owner() && !usedSignatures[_signature];
    }

    function verifyMerkleProof(bytes32[] calldata proof, bytes32 root) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        return MerkleProof.verify(proof, root, leaf);
    }

    function mint(bytes32[] calldata _phase1MerkleProof) external nonReentrant isMerkleRootSet {
        require(!hasMinted[msg.sender], "Already minted");
        require(currentPhase == MintingPhase.Phase1, "Not phase 1");
        require(verifyMerkleProof(_phase1MerkleProof, phase1MerkleRoot), "Invalid proof");

        hasMinted[msg.sender] = true;

        uint256 _mintTokenId = tokenIdCounter;
        _safeMint(msg.sender, _mintTokenId);
        tokenIdCounter += 1;

        emit NFTMinted(msg.sender, _mintTokenId, MintingPhase.Phase1);
    }

    function mintWithDiscount(bytes memory _signature, bytes32[] calldata _phase2MerkleProof) external nonReentrant isMerkleRootSet {
        require(!usedSignatures[_signature], "Signature already used");
        require(currentPhase == MintingPhase.Phase2, "Not phase 2");
        require(verifyMerkleProof(_phase2MerkleProof, phase2MerkleRoot), "Invalid proof");
        require(verifySignature(_signature), "Invalid signature");

        usedSignatures[_signature] = true;
        bool _transfer = IERC20(paymentToken).transferFrom(msg.sender, address(this), discountedMintPrice);
        require(_transfer, "Transfer failed");

        uint256 _mintTokenId = tokenIdCounter;
        _safeMint(msg.sender, _mintTokenId);
        tokenIdCounter += 1;

        emit NFTMinted(msg.sender, _mintTokenId, MintingPhase.Phase2);
    }

    function mintWithoutDiscount() external nonReentrant {
        require(currentPhase == MintingPhase.Phase3, "Not phase 3");
        bool _transfer = IERC20(paymentToken).transferFrom(msg.sender, address(this), fullMintPrice);
        require(_transfer, "Transfer failed");

        uint256 _mintTokenId = tokenIdCounter;
        _safeMint(msg.sender, _mintTokenId);
        tokenIdCounter += 1;

        emit NFTMinted(msg.sender, _mintTokenId, MintingPhase.Phase3);
    }

    function createVestingStream() external onlyOwner {
        uint256 _contractBalance = IERC20(paymentToken).balanceOf(address(this));
        require(_contractBalance > 0, "No tokens to vest");

        IERC20(paymentToken).approve(sablierContractAddress, _contractBalance);

        LockupLinear.CreateWithDurations memory params;

        params.sender = address(this);
        params.recipient = owner();
        params.totalAmount = uint128(_contractBalance);
        params.asset = IERC20(paymentToken);
        params.cancelable = false;
        params.transferable = true;
        params.durations = LockupLinear.Durations({cliff: 365 days, total: 720 days});
        params.broker = Broker(address(0), ud60x18(0));

        uint256 _streamId = ISablierV2LockupLinear(sablierContractAddress).createWithDurations(params);

        emit VestingStreamCreated(_streamId);
    }

    function withdrawVestedTokens(uint256 _streamId) external onlyOwner {
        uint256 _amountWithdrawn = ISablierV2LockupLinear(sablierContractAddress).withdrawMax({streamId: _streamId, to: owner()});

        emit VestingTokensWithdrawn(_streamId, _amountWithdrawn);
    }
}