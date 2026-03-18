// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * ██████╗ ██╗███╗   ███╗ ██████╗ ██╗    ██╗ █████╗
 * ██╔══██╗██║████╗ ████║██╔═══██╗██║    ██║██╔══██╗
 * ██████╔╝██║██╔████╔██║██║   ██║██║ █╗ ██║███████║
 * ██╔══██╗██║██║╚██╔╝██║██║   ██║██║███╗██║██╔══██║
 * ██║  ██║██║██║ ╚═╝ ██║╚██████╔╝╚███╔███╔╝██║  ██║
 * ╚═╝  ╚═╝╚═╝╚═╝     ╚═╝ ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═╝
 *
 * @title  RimowaPassport — Passeport Numérique de Produit (DPP)
 * @author RIMOWA Digital & Innovation Lab
 * @notice ERC-721 principal représentant une valise RIMOWA unique.
 *         Implémente EIP-2981 pour les royalties sur reventes secondaires.
 *         Aucune donnée brute n'est stockée on-chain : seul le CID IPFS
 *         est conservé, pointant vers les métadonnées JSON hébergées sur Pinata.
 *
 * Architecture :
 *   ┌──────────────────────────────────────────────────────────────┐
 *   │  Client App  →  Smart Account (ERC-4337)  →  Ce Contrat     │
 *   │  tokenURI()  →  IPFS (Pinata)  →  Arweave (3D twin)        │
 *   └──────────────────────────────────────────────────────────────┘
 *
 * Sécurité :
 *   - ReentrancyGuard sur tous les transferts de valeur
 *   - Zéro tx.origin, uniquement msg.sender
 *   - Pausable d'urgence (Pausable)
 *   - Révocation on-chain si contrefaçon détectée
 *   - Aucune boucle non bornée on-chain
 */

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RimowaPassport is ERC721URIStorage, ERC2981, AccessControl, Pausable, ReentrancyGuard {
    using Strings for uint256;

    // ═══════════════════════════════════════════════════════════════
    //                          ROLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice MINTER_ROLE : accordé aux boutiques RIMOWA autorisées
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice REVOKER_ROLE : accordé à l'équipe anti-contrefaçon RIMOWA
    bytes32 public constant REVOKER_ROLE = keccak256("REVOKER_ROLE");
    /// @notice PAUSER_ROLE : accordé à l'équipe de sécurité RIMOWA
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ═══════════════════════════════════════════════════════════════
    //                          STORAGE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Compteur auto-incrémenté pour les token IDs (pas de SafeMath, overflow impossible en 256 bits)
    uint256 private _nextTokenId;

    /// @notice Préfixe IPFS : les URIs sont stockées sans le préfixe pour économiser du gas
    string private _baseIPFS;

    /// @notice Mapping numéro de série → tokenId (unicité physique garantie)
    mapping(string => uint256) private _serialToTokenId;

    /// @notice Inverse : tokenId → numéro de série
    mapping(uint256 => string) private _tokenIdToSerial;

    /// @notice Tokens révoqués (contrefaçon prouvée ou défaut critique)
    mapping(uint256 => bool) public revoked;

    /// @notice Lien vers le contrat Soulbound associé
    address public soulboundContract;

    // ═══════════════════════════════════════════════════════════════
    //                          EVENTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Émis lors du mint d'un nouveau passeport
    event PassportMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string serialNumber,
        string ipfsCid
    );

    /// @notice Émis lors du transfert de propriété (revente)
    event OwnershipTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 timestamp
    );

    /// @notice Émis lors d'une révocation pour contrefaçon
    event PassportRevoked(uint256 indexed tokenId, address indexed revokedBy, string reason);

    /// @notice Émis lors de la mise à jour du contrat Soulbound associé
    event SoulboundContractUpdated(address indexed newContract);

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @param initialAdmin Adresse admin principale (multisig RIMOWA recommandé)
     * @param royaltyReceiver Adresse recevant les royalties (trésorerie RIMOWA)
     * @param royaltyFeeBps Pourcentage de royalties en basis points (ex: 500 = 5%)
     * @param baseIPFS Préfixe IPFS de base (ex: "ipfs://")
     */
    constructor(
        address initialAdmin,
        address royaltyReceiver,
        uint96 royaltyFeeBps,
        string memory baseIPFS
    ) ERC721("RIMOWA Digital Passport", "RDPP") {
        require(initialAdmin != address(0), "RimowaPassport: admin cannot be zero address");
        require(royaltyReceiver != address(0), "RimowaPassport: royalty receiver cannot be zero address");
        require(royaltyFeeBps <= 1000, "RimowaPassport: royalties cannot exceed 10%");

        _baseIPFS = baseIPFS;

        // Configuration des rôles — admin = root
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(MINTER_ROLE, initialAdmin);
        _grantRole(REVOKER_ROLE, initialAdmin);
        _grantRole(PAUSER_ROLE, initialAdmin);

        // Royalties par défaut (EIP-2981) — appliquées à tous les tokens
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeBps);
    }

    // ═══════════════════════════════════════════════════════════════
    //                     FONCTIONS PRINCIPALES
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Mint d'un nouveau passeport numérique RIMOWA.
     * @dev Seul un MINTER_ROLE peut appeler cette fonction.
     *      Le numéro de série doit être unique — une valise = un token.
     *      Le CID IPFS doit pointer vers les métadonnées JSON Pinata.
     *      Aucune donnée brute n'est stockée ici, seulement le CID.
     *
     * @param to           Adresse du Smart Account propriétaire (ERC-4337)
     * @param serialNumber Numéro de série gravé sur la valise physique
     * @param ipfsCid      CID IPFS du JSON de métadonnées (sans préfixe)
     */
    function mintPassport(
        address to,
        string calldata serialNumber,
        string calldata ipfsCid
    ) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant returns (uint256 tokenId) {
        require(to != address(0), "RimowaPassport: mint to zero address");
        require(bytes(serialNumber).length > 0, "RimowaPassport: empty serial number");
        require(bytes(ipfsCid).length > 0, "RimowaPassport: empty IPFS CID");
        require(_serialToTokenId[serialNumber] == 0, "RimowaPassport: serial already registered");

        // Incrémentation avant le mint pour éviter le reentrancy
        unchecked {
            tokenId = ++_nextTokenId;
        }

        // Mapping bidirectionnel numéro de série ↔ tokenId
        _serialToTokenId[serialNumber] = tokenId;
        _tokenIdToSerial[tokenId] = serialNumber;

        // Mint ERC-721
        _safeMint(to, tokenId);

        // Stockage du CID IPFS (pas de données brutes)
        _setTokenURI(tokenId, string(abi.encodePacked(_baseIPFS, ipfsCid)));

        emit PassportMinted(tokenId, to, serialNumber, ipfsCid);
    }

    /**
     * @notice Révoque un passeport en cas de contrefaçon prouvée ou défaut critique.
     * @dev Seul un REVOKER_ROLE peut révoquer. Le token reste dans le mapping
     *      mais est marqué comme invalide. Les transferts sont bloqués.
     *
     * @param tokenId Token à révoquer
     * @param reason  Raison de la révocation (pour la traçabilité)
     */
    function revokePassport(
        uint256 tokenId,
        string calldata reason
    ) external onlyRole(REVOKER_ROLE) {
        require(_ownerOf(tokenId) != address(0), "RimowaPassport: token does not exist");
        require(!revoked[tokenId], "RimowaPassport: token already revoked");

        revoked[tokenId] = true;
        emit PassportRevoked(tokenId, msg.sender, reason);
    }

    /**
     * @notice Pause d'urgence — bloque tous les mints et transferts.
     * @dev Utilisé en cas de faille de sécurité détectée.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Reprend les opérations après résolution de l'incident.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Lie le contrat Soulbound (ERC-5192) à ce passeport.
     * @dev Appelé après le déploiement pour configurer l'architecture.
     */
    function setSoulboundContract(address _soulboundContract)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_soulboundContract != address(0), "RimowaPassport: zero address");
        soulboundContract = _soulboundContract;
        emit SoulboundContractUpdated(_soulboundContract);
    }

    /**
     * @notice Définit des royalties spécifiques pour un token particulier.
     * @dev Permet de configurer des royalties différentes pour les éditions limitées.
     */
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(feeNumerator <= 1000, "RimowaPassport: royalties cannot exceed 10%");
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    // ═══════════════════════════════════════════════════════════════
    //                   FONCTIONS DE LECTURE
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Retourne le tokenId correspondant à un numéro de série.
     * @param serialNumber Numéro de série gravé sur la valise physique
     */
    function getTokenIdBySerial(string calldata serialNumber) external view returns (uint256) {
        uint256 tokenId = _serialToTokenId[serialNumber];
        require(tokenId != 0, "RimowaPassport: serial not found");
        return tokenId;
    }

    /**
     * @notice Retourne le numéro de série correspondant à un tokenId.
     * @param tokenId Identifiant du token ERC-721
     */
    function getSerialByTokenId(uint256 tokenId) external view returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "RimowaPassport: token does not exist");
        return _tokenIdToSerial[tokenId];
    }

    /**
     * @notice Vérifie si un passeport est valide (non révoqué et existant).
     * @param tokenId Identifiant du token ERC-721
     */
    function isPassportValid(uint256 tokenId) external view returns (bool) {
        return _ownerOf(tokenId) != address(0) && !revoked[tokenId];
    }

    /**
     * @notice Nombre total de passeports mintés.
     */
    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    // ═══════════════════════════════════════════════════════════════
    //                   OVERRIDES ERC-721
    // ═══════════════════════════════════════════════════════════════

    /**
     * @dev Vérifie que le token n'est pas révoqué avant tout transfert.
     *      Également bloqué si le contrat est en pause.
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override whenNotPaused returns (address) {
        // Bloquer les transferts de tokens révoqués (sauf burn = to == address(0))
        if (to != address(0)) {
            require(!revoked[tokenId], "RimowaPassport: token is revoked");
        }

        address from = super._update(to, tokenId, auth);

        // Émet l'événement de transfert de propriété si ce n'est pas un mint
        if (from != address(0) && to != address(0)) {
            emit OwnershipTransferred(tokenId, from, to, block.timestamp);
        }

        return from;
    }

    // ═══════════════════════════════════════════════════════════════
    //                   RÉSOLUTION DE CONFLITS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @dev ERC165 : résolution des conflits ERC721 / ERC2981 / AccessControl.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, ERC2981, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
