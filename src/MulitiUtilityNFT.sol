// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISablier.sol";


contract MultiUtilityNFT is ERC721, Ownable {
    enum MintingPhase {
        InActive,
        Phase1,
        Phase2,
        Phase3
    }

    MintingPhase public currentPhase;

    address public paymentToken;
    address public sablierContractAddress;

    uint256 public fullMintPrice;
    uint256 public discountedMintPrice;

    bytes32 phase1MerkleRoot;
    bytes32 phase2MerkleRoot;

    uint256 tokenIdCounter;

    mapping(bytes => bool) public usedSignatures;

    constructor(
        address _paymentToken,
        address _sablierContractAddress,
        bytes32 _phase1MerkleRoot,
        uint256 _fullMintPrice,
        uint256 _discountedMintPrice
    ) ERC721("MultiUtilityNFT", "MNFT") Ownable(msg.sender) {
        paymentToken = _paymentToken;
        sablierContractAddress = _sablierContractAddress;
        phase1MerkleRoot = _phase1MerkleRoot;
        fullMintPrice = _fullMintPrice;
        discountedMintPrice = _discountedMintPrice;
    }

    function setPhase(MintingPhase _currentPhase) external onlyOwner {
        currentPhase = _currentPhase;
    }

    function setMerkleRoot(MintingPhase _currentPhase, bytes32 _merkleRoot) external onlyOwner {
        if(_currentPhase == MintingPhase.Phase1) {
            phase1MerkleRoot == _merkleRoot;
        } else if (_currentPhase == MintingPhase.Phase2) {
            phase2MerkleRoot = _merkleRoot;
        }
    }

    function verifySignature(bytes memory _signature) public view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, block.chainid));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, _signature);
        return signer == owner() && !usedSignatures[_signature];
    }

    function verifyMerkleProof(bytes32[] calldata proof, bytes32 root) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        return MerkleProof.verify(proof, root, leaf);
    }

    function mintPhase1(bytes32[] calldata _merkleProof) external {
        require(currentPhase == MintingPhase.Phase1, "Not phase 1");
        require(verifyMerkleProof(_merkleProof, phase1MerkleRoot), "Invalid proof");

        _safeMint(msg.sender, tokenIdCounter);
        tokenIdCounter += 1;
    }

    function mintPhase2(bytes memory _signature, bytes32[] calldata _merkleProof) external {
        require(currentPhase == MintingPhase.Phase2, "Not phase 2");
        require(verifyMerkleProof(_merkleProof, phase2MerkleRoot), "Invalid proof");
        require(verifySignature(_signature), "Invalid signature");

        usedSignatures[_signature] = true;
        bool _transfer = IERC20(paymentToken).transferFrom(msg.sender, address(this), discountedMintPrice);
        require(_transfer, "Transfer failed");

        _safeMint(msg.sender, tokenIdCounter);
        tokenIdCounter += 1;
    }

    function mintPhase3() external {
        require(currentPhase == MintingPhase.Phase3, "Not phase 3");
        bool _transfer = IERC20(paymentToken).transferFrom(msg.sender, fullMintPrice);
        require(_transfer, "Transfer failed");

        _safeMint(msg.sender, tokenIdCounter);

        tokenIdCounter += 1;
    }

    function createVestingStream() external {
        uint256 _contractBalance = IERC20(paymentToken).balanceOf(address(this));
        require(_contractBalance > 0, "No tokens to vest");

        IERC20(paymentToken).approve(sablierContractAddress, _contractBalance);

        uint256 _startTime = block.timestamp;
        uint256 _endTime = _startTime + 365 days;

        uint256 _streamId = ISablier(sablierContractAddress).createStream(
            owner(),
            _contractBalance,
            paymentToken,
            _startTime,
            _endTime
        );
    }

    function withdrawVestedTokens(uint256 _streamId) external onlyOwner {
        uint256 _amountToWithdraw = ISablier.balanceOf(_streamId, owner());
        ISablier(sablierContractAddress).withdrawFromStream(_streamId, _amountToWithdraw);
    }
}