// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * @title  RimowaSoulbound — Token d'Identité VIP Non-Transférable
 * @author RIMOWA Digital & Innovation Lab
 * @notice Implémente ERC-5192 (Minimal Soulbound NFT).
 *         Lié à l'identité du propriétaire d'une valise RIMOWA.
 *         Contient : historique SAV, statut membre, garantie à vie.
 *
 * Logique :
 *   - Non-transférable par design (soulbound)
 *   - Créé lors du premier achat, lié au passeport (ERC-721)
 *   - Détruit et re-créé automatiquement lors d'une revente
 *     (l'ancien propriétaire perd son statut, le nouveau reçoit le sien)
 *   - Seul RIMOWA peut minter / mettre à jour le statut SAV
 */

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Interface ERC-5192 — Minimal Soulbound NFT Standard
interface IERC5192 {
    /// @notice Émis quand un token devient soulbound (non-transférable)
    event Locked(uint256 tokenId);
    /// @notice Émis quand un token devient transférable (jamais dans notre cas)
    event Unlocked(uint256 tokenId);

    /// @notice Retourne true si le token est verrouillé (non-transférable)
    function locked(uint256 tokenId) external view returns (bool);
}

contract RimowaSoulbound is ERC721, IERC5192, AccessControl, Pausable {
    // ═══════════════════════════════════════════════════════════════
    //                          ROLES
    // ═══════════════════════════════════════════════════════════════

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SAV_OPERATOR_ROLE = keccak256("SAV_OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ═══════════════════════════════════════════════════════════════
    //                          TYPES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Statut de fidélité du membre RIMOWA
    enum MembershipTier {
        NONE,    // Pas de statut (erreur ou non initialisé)
        SILVER,  // 1er achat
        GOLD,    // 2ème valise ou revente qualifiée
        ICONIC   // Collectionneur (3+ valises)
    }

    /// @notice Enregistrement d'un passage en SAV officiel RIMOWA
    struct RepairRecord {
        uint256 timestamp;
        string workshopCid; // CID IPFS du rapport de réparation
        string description; // Description courte (ex: "Remplacement roues")
    }

    /// @notice Données stockées dans le Soulbound Token
    struct SoulboundData {
        uint256 passportTokenId;      // Lien vers le passeport ERC-721
        uint256 memberSince;          // Timestamp d'acquisition
        MembershipTier tier;          // Statut Silver / Gold / Iconic
        bool lifetimeWarrantyActive;  // Garantie à vie numérique
        uint256 repairCount;          // Nombre de passages SAV
    }

    // ═══════════════════════════════════════════════════════════════
    //                          STORAGE
    // ═══════════════════════════════════════════════════════════════

    uint256 private _nextTokenId;

    /// @notice Données de chaque Soulbound Token
    mapping(uint256 => SoulboundData) private _soulboundData;

    /// @notice Historique des réparations par soulbound token
    /// @dev Tableau borné par repairCount pour éviter les boucles non bornées
    mapping(uint256 => RepairRecord[]) private _repairHistory;

    /// @notice Lien passportTokenId → soulboundTokenId (un seul actif à la fois)
    mapping(uint256 => uint256) private _passportToSoulbound;

    /// @notice Adresse du contrat RimowaPassport (pour validation croisée)
    address public passportContract;

    /// @notice Base URI IPFS
    string private constant IPFS_PREFIX = "ipfs://";

    /// @notice CID IPFS par token (pour les métadonnées du soulbound)
    mapping(uint256 => string) private _tokenCids;

    // ═══════════════════════════════════════════════════════════════
    //                          EVENTS
    // ═══════════════════════════════════════════════════════════════

    event SoulboundMinted(
        uint256 indexed soulboundId,
        uint256 indexed passportTokenId,
        address indexed owner,
        MembershipTier tier
    );

    event SoulboundBurned(
        uint256 indexed soulboundId,
        address indexed previousOwner
    );

    event SoulboundTransferred(
        uint256 indexed passportTokenId,
        address indexed previousOwner,
        address indexed newOwner,
        uint256 newSoulboundId
    );

    event RepairRecorded(
        uint256 indexed soulboundId,
        uint256 repairIndex,
        string workshopCid
    );

    event TierUpgraded(
        uint256 indexed soulboundId,
        MembershipTier oldTier,
        MembershipTier newTier
    );

    event PassportContractSet(address indexed contractAddress);

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @param initialAdmin    Adresse admin (multisig RIMOWA)
     * @param _passportContract Adresse du contrat RimowaPassport
     */
    constructor(address initialAdmin, address _passportContract)
        ERC721("RIMOWA Soulbound Identity", "RDSI")
    {
        require(initialAdmin != address(0), "RimowaSoulbound: zero admin");

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(MINTER_ROLE, initialAdmin);
        _grantRole(SAV_OPERATOR_ROLE, initialAdmin);
        _grantRole(PAUSER_ROLE, initialAdmin);

        if (_passportContract != address(0)) {
            passportContract = _passportContract;
            emit PassportContractSet(_passportContract);
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                   FONCTIONS PRINCIPALES
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Mint d'un Soulbound Token pour un nouveau propriétaire de valise.
     * @dev Appelé lors du premier achat en boutique ou lors d'une revente.
     *      Si un soulbound existe déjà pour ce passeport, il est brûlé d'abord.
     *
     * @param to              Adresse Smart Account du nouveau propriétaire
     * @param passportTokenId ID du passeport ERC-721 associé
     * @param ipfsCid         CID IPFS des métadonnées du soulbound
     * @param tier            Statut de fidélité initial
     */
    function mintSoulbound(
        address to,
        uint256 passportTokenId,
        string calldata ipfsCid,
        MembershipTier tier
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256 soulboundId) {
        require(to != address(0), "RimowaSoulbound: mint to zero address");
        require(bytes(ipfsCid).length > 0, "RimowaSoulbound: empty CID");
        require(tier != MembershipTier.NONE, "RimowaSoulbound: invalid tier");

        // Burn du soulbound précédent si une revente a eu lieu
        uint256 existingSoulbound = _passportToSoulbound[passportTokenId];
        if (existingSoulbound != 0 && _ownerOf(existingSoulbound) != address(0)) {
            address previousOwner = _ownerOf(existingSoulbound);
            _burn(existingSoulbound);
            delete _soulboundData[existingSoulbound];
            emit SoulboundBurned(existingSoulbound, previousOwner);
        }

        unchecked {
            soulboundId = ++_nextTokenId;
        }

        // Mint soulbound (non-transférable dès la création)
        _safeMint(to, soulboundId);

        // Stockage des données
        _soulboundData[soulboundId] = SoulboundData({
            passportTokenId: passportTokenId,
            memberSince: block.timestamp,
            tier: tier,
            lifetimeWarrantyActive: true,
            repairCount: 0
        });

        _tokenCids[soulboundId] = ipfsCid;
        _passportToSoulbound[passportTokenId] = soulboundId;

        emit SoulboundMinted(soulboundId, passportTokenId, to, tier);
        emit Locked(soulboundId);
    }

    /**
     * @notice Enregistre un passage en SAV officiel RIMOWA.
     * @dev Seul un SAV_OPERATOR_ROLE peut enregistrer une réparation.
     *      Le rapport est stocké sur IPFS, seul le CID est on-chain.
     *
     * @param soulboundId  ID du soulbound token
     * @param workshopCid  CID IPFS du rapport de réparation
     * @param description  Description courte de la réparation
     */
    function recordRepair(
        uint256 soulboundId,
        string calldata workshopCid,
        string calldata description
    ) external onlyRole(SAV_OPERATOR_ROLE) {
        require(_ownerOf(soulboundId) != address(0), "RimowaSoulbound: token does not exist");
        require(bytes(workshopCid).length > 0, "RimowaSoulbound: empty CID");
        require(bytes(description).length > 0, "RimowaSoulbound: empty description");

        SoulboundData storage data = _soulboundData[soulboundId];
        uint256 repairIndex = data.repairCount;

        _repairHistory[soulboundId].push(RepairRecord({
            timestamp: block.timestamp,
            workshopCid: workshopCid,
            description: description
        }));

        unchecked {
            data.repairCount++;
        }

        emit RepairRecorded(soulboundId, repairIndex, workshopCid);
    }

    /**
     * @notice Met à jour le statut de fidélité d'un membre.
     * @dev Appelé par RIMOWA lors d'un deuxième achat ou qualification spéciale.
     */
    function upgradeTier(
        uint256 soulboundId,
        MembershipTier newTier
    ) external onlyRole(MINTER_ROLE) {
        require(_ownerOf(soulboundId) != address(0), "RimowaSoulbound: token does not exist");
        require(newTier != MembershipTier.NONE, "RimowaSoulbound: invalid tier");

        SoulboundData storage data = _soulboundData[soulboundId];
        MembershipTier oldTier = data.tier;
        require(uint8(newTier) > uint8(oldTier), "RimowaSoulbound: can only upgrade tier");

        data.tier = newTier;
        emit TierUpgraded(soulboundId, oldTier, newTier);
    }

    /**
     * @notice Migre le soulbound lors d'une revente de valise.
     * @dev Brûle l'ancien soulbound, crée le nouveau pour le nouvel acheteur.
     *      Appelé automatiquement après le transfert du passeport ERC-721.
     *
     * @param passportTokenId ID du passeport transféré
     * @param newOwner        Adresse du nouvel acheteur
     * @param ipfsCid         CID des métadonnées du nouveau soulbound
     */
    function migrateSoulbound(
        uint256 passportTokenId,
        address newOwner,
        string calldata ipfsCid
    ) external onlyRole(MINTER_ROLE) returns (uint256 newSoulboundId) {
        require(newOwner != address(0), "RimowaSoulbound: zero address");

        address previousOwner = address(0);
        uint256 existingSoulbound = _passportToSoulbound[passportTokenId];

        if (existingSoulbound != 0 && _ownerOf(existingSoulbound) != address(0)) {
            previousOwner = _ownerOf(existingSoulbound);
        }

        // Mint du nouveau soulbound (l'ancien est brûlé dans mintSoulbound)
        newSoulboundId = this.mintSoulbound(newOwner, passportTokenId, ipfsCid, MembershipTier.SILVER);

        emit SoulboundTransferred(passportTokenId, previousOwner, newOwner, newSoulboundId);
    }

    /**
     * @notice Définit l'adresse du contrat RimowaPassport.
     */
    function setPassportContract(address _passportContract)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_passportContract != address(0), "RimowaSoulbound: zero address");
        passportContract = _passportContract;
        emit PassportContractSet(_passportContract);
    }

    // ═══════════════════════════════════════════════════════════════
    //                   FONCTIONS DE LECTURE
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Retourne les données du soulbound d'un propriétaire de passeport.
     */
    function getSoulboundData(uint256 soulboundId)
        external
        view
        returns (SoulboundData memory)
    {
        require(_ownerOf(soulboundId) != address(0), "RimowaSoulbound: token does not exist");
        return _soulboundData[soulboundId];
    }

    /**
     * @notice Retourne l'historique des réparations d'une valise.
     * @dev Retourne une copie du tableau — borné par repairCount (pas de boucle infinie).
     */
    function getRepairHistory(uint256 soulboundId)
        external
        view
        returns (RepairRecord[] memory)
    {
        return _repairHistory[soulboundId];
    }

    /**
     * @notice Retourne le soulbound associé à un passeport.
     */
    function getSoulboundByPassport(uint256 passportTokenId)
        external
        view
        returns (uint256)
    {
        return _passportToSoulbound[passportTokenId];
    }

    /**
     * @notice Vérifie si la garantie à vie est active pour un soulbound.
     */
    function hasLifetimeWarranty(uint256 soulboundId) external view returns (bool) {
        return _ownerOf(soulboundId) != address(0) &&
               _soulboundData[soulboundId].lifetimeWarrantyActive;
    }

    /**
     * @notice URI des métadonnées du soulbound.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "RimowaSoulbound: token does not exist");
        return string(abi.encodePacked(IPFS_PREFIX, _tokenCids[tokenId]));
    }

    // ═══════════════════════════════════════════════════════════════
    //                   ERC-5192 — SOULBOUND
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Implémentation ERC-5192 : tous les tokens sont locked.
     */
    function locked(uint256 tokenId) external view override returns (bool) {
        require(_ownerOf(tokenId) != address(0), "RimowaSoulbound: token does not exist");
        return true; // Toujours verrouillé
    }

    /**
     * @dev Bloque tous les transferts (soulbound = non-transférable).
     *      Seuls les mints (from == 0) et les burns (to == 0) sont autorisés.
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);

        // Bloquer les transferts peer-to-peer
        if (from != address(0) && to != address(0)) {
            revert("RimowaSoulbound: token is non-transferable");
        }

        return super._update(to, tokenId, auth);
    }

    // ═══════════════════════════════════════════════════════════════
    //                        PAUSE
    // ═══════════════════════════════════════════════════════════════

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    // ═══════════════════════════════════════════════════════════════
    //                   RÉSOLUTION DE CONFLITS
    // ═══════════════════════════════════════════════════════════════

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        // ERC-5192 interface ID
        return interfaceId == type(IERC5192).interfaceId || super.supportsInterface(interfaceId);
    }
}
