// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title EduCredential
/// @notice Issue, verify, and revoke on-chain verifiable education credentials as ERC-721 NFTs.
///         Uses EIP-712 signatures for off-chain approval by accredited institutions.
contract EduCredential is ERC721URIStorage, EIP712, AccessControl {
    using ECDSA for bytes32;

    /// @notice Role granted to accredited institutions that can sign issuance messages.
    bytes32 public constant MINTER_ROLE     = keccak256("MINTER_ROLE");
    /// @notice Role able to revoke credentials on-chain.
    bytes32 public constant REVOCATOR_ROLE  = keccak256("REVOCATOR_ROLE");

    // EIP-712 type hash for the Credential struct in signed messages
    bytes32 private constant CREDENTIAL_TYPEHASH = keccak256(
        "Credential(address student,uint256 courseId,uint256 issuanceDate,uint256 expirationDate,uint256 nonce,string uri)"
    );

    /// @notice Track nonces for each signing institution to prevent replay.
    mapping(address => uint256) public nonces;

    /// @notice Auto-incrementing counter for NFT token IDs.
    uint256 private _tokenIdCounter;

    /// @notice Stores on-chain issuance data for verification.
    struct Issuance {
        address issuer;
        uint256 courseId;
        uint256 issuanceDate;
        uint256 expirationDate;
    }
    mapping(uint256 => Issuance) private _issuanceData;

    /// @notice Emitted when a credential is minted.
    event CredentialMinted(
        uint256 indexed tokenId,
        address indexed issuer,
        address indexed student,
        uint256 courseId,
        uint256 issuanceDate,
        uint256 expirationDate,
        string uri
    );
    /// @notice Emitted when a credential is revoked.
    event CredentialRevoked(uint256 indexed tokenId);

    /// @param name    Name of the ERC-721 collection (e.g., “UniversityCreds”)
    /// @param symbol  Symbol for the ERC-721 tokens (e.g., “UCD”)
    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
        EIP712(name, "1")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(REVOCATOR_ROLE, msg.sender);
    }

    /// @notice Mint a credential NFT to `student` when `signature` from an accredited issuer is valid.
    /// @param student          Recipient of the credential NFT.
    /// @param courseId         Identifier for the course or program.
    /// @param issuanceDate     UNIX timestamp of issuance.
    /// @param expirationDate   UNIX timestamp when credential expires (or 0 if never expires).
    /// @param nonce            Nonce matching the issuer’s current counter.
    /// @param uri              Metadata URI (e.g., IPFS link to a verifiable JSON document).
    /// @param signature        EIP-712 signature from an address with MINTER_ROLE.
    function mintCredential(
        address student,
        uint256 courseId,
        uint256 issuanceDate,
        uint256 expirationDate,
        uint256 nonce,
        string calldata uri,
        bytes calldata signature
    ) external {
        // Construct the struct hash
        bytes32 structHash = keccak256(abi.encode(
            CREDENTIAL_TYPEHASH,
            student,
            courseId,
            issuanceDate,
            expirationDate,
            nonce,
            keccak256(bytes(uri))
        ));
        // Domain-aware hash
        bytes32 digest = _hashTypedDataV4(structHash);
        // Recover signer
        address issuer = digest.recover(signature);
        require(hasRole(MINTER_ROLE, issuer), "EduCredential: unauthorized signer");
        require(nonce == nonces[issuer], "EduCredential: invalid nonce");
        nonces[issuer] += 1;

        // Mint NFT
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(student, tokenId);
        _setTokenURI(tokenId, uri);

        // Store issuance data
        _issuanceData[tokenId] = Issuance({
            issuer:         issuer,
            courseId:       courseId,
            issuanceDate:   issuanceDate,
            expirationDate: expirationDate
        });

        emit CredentialMinted(tokenId, issuer, student, courseId, issuanceDate, expirationDate, uri);
    }

    /// @notice Returns on-chain data and metadata URI for a given credential token.
    /// @param tokenId The credential NFT ID.
    /// @return issuer          Address of the issuing institution.
    /// @return courseId        Course/program identifier.
    /// @return issuanceDate    Timestamp when issued.
    /// @return expirationDate  Timestamp when expires (0 if none).
    /// @return uri             Metadata URI.
    function getCredentialData(uint256 tokenId)
        external
        view
        returns (
            address issuer,
            uint256 courseId,
            uint256 issuanceDate,
            uint256 expirationDate,
            string memory uri
        )
    {
        require(_exists(tokenId), "EduCredential: token does not exist");
        Issuance storage data = _issuanceData[tokenId];
        return (
            data.issuer,
            data.courseId,
            data.issuanceDate,
            data.expirationDate,
            tokenURI(tokenId)
        );
    }

    /// @notice Revoke (burn) a credential. Only callable by an address with REVOCATOR_ROLE.
    /// @param tokenId The credential NFT ID to revoke.
    function revokeCredential(uint256 tokenId) external {
        require(hasRole(REVOCATOR_ROLE, msg.sender), "EduCredential: must have revocator role");
        require(_exists(tokenId), "EduCredential: token does not exist");
        _burn(tokenId);
        emit CredentialRevoked(tokenId);
    }

    /// @dev Override to clean up issuance data on burn.
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        delete _issuanceData[tokenId];
    }

    /// @dev Override to return the stored URI.
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
