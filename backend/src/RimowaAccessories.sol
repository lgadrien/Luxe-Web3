// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * @title  RimowaAccessories — Accessoires & Éditions Limitées
 * @author RIMOWA Digital & Innovation Lab
 * @notice ERC-1155 pour les accessoires officiels et collections capsules.
 *
 * Types de tokens :
 *   ID 1-999    → Accessoires officiels (cadenas TSA, housses, étiquettes...)
 *   ID 1000+    → Éditions limitées (Supreme, Porsche, Dior, Moncler...)
 *
 * Optimisations gas :
 *   - Batch mint via mintBatch() pour les grandes séries
 *   - URI partagée par collection (pas de stockage individuel)
 *   - Structs avec uint256 pour éviter le slot packing inefficace
 */

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RimowaAccessories is ERC1155Supply, ERC2981, AccessControl, Pausable, ReentrancyGuard {
    // ═══════════════════════════════════════════════════════════════
    //                          ROLES
    // ═══════════════════════════════════════════════════════════════

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant COLLECTION_MANAGER_ROLE = keccak256("COLLECTION_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ═══════════════════════════════════════════════════════════════
    //                          TYPES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Catégorie d'un token
    enum TokenCategory {
        ACCESSORY,       // Accessoire standard (cadenas, housse...)
        LIMITED_EDITION  // Édition limitée (collaboration)
    }

    /// @notice Métadonnées d'un type de token (stockées off-chain, CID seulement)
    struct TokenConfig {
        uint256 maxSupply;       // 0 = illimité
        uint256 mintedCount;     // Compteur de minted (pour les séries limitées)
        TokenCategory category;
        bool active;             // Peut-on encore minter ce type ?
        string ipfsCid;         // CID IPFS du JSON de métadonnées
    }

    // ═══════════════════════════════════════════════════════════════
    //                          STORAGE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Prefix IPFS commun
    string private constant IPFS_PREFIX = "ipfs://";

    /// @notice Configuration par tokenId
    mapping(uint256 => TokenConfig) private _tokenConfigs;

    /// @notice Prochain ID disponible pour une nouvelle collection
    uint256 private _nextCollectionId = 1000;

    // ═══════════════════════════════════════════════════════════════
    //                          EVENTS
    // ═══════════════════════════════════════════════════════════════

    event TokenTypeCreated(
        uint256 indexed tokenId,
        TokenCategory category,
        uint256 maxSupply,
        string ipfsCid
    );

    event AccessoryMinted(
        uint256 indexed tokenId,
        address indexed to,
        uint256 amount
    );

    event BatchMinted(
        address indexed to,
        uint256[] tokenIds,
        uint256[] amounts
    );

    event CollectionDeactivated(uint256 indexed tokenId);

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @param initialAdmin     Adresse admin (multisig RIMOWA)
     * @param royaltyReceiver  Adresse royalties
     * @param royaltyFeeBps    Royalties en basis points
     */
    constructor(
        address initialAdmin,
        address royaltyReceiver,
        uint96 royaltyFeeBps
    ) ERC1155("") {
        require(initialAdmin != address(0), "RimowaAccessories: zero admin");
        require(royaltyReceiver != address(0), "RimowaAccessories: zero royalty receiver");
        require(royaltyFeeBps <= 1000, "RimowaAccessories: royalties > 10%");

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(MINTER_ROLE, initialAdmin);
        _grantRole(COLLECTION_MANAGER_ROLE, initialAdmin);
        _grantRole(PAUSER_ROLE, initialAdmin);

        _setDefaultRoyalty(royaltyReceiver, royaltyFeeBps);
    }

    // ═══════════════════════════════════════════════════════════════
    //                   GESTION DES COLLECTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Crée un nouveau type d'accessoire (ID 1-999).
     * @dev L'ID est fourni explicitement pour garder la cohérence avec
     *      le catalogue physique RIMOWA (ex: TSA Lock = ID 1).
     *
     * @param tokenId   ID du token (doit être < 1000 pour les accessoires)
     * @param maxSupply Offre maximale (0 = illimité)
     * @param ipfsCid   CID IPFS des métadonnées
     */
    function createAccessoryType(
        uint256 tokenId,
        uint256 maxSupply,
        string calldata ipfsCid
    ) external onlyRole(COLLECTION_MANAGER_ROLE) {
        require(tokenId > 0 && tokenId < 1000, "RimowaAccessories: accessory ID must be 1-999");
        require(!_tokenConfigs[tokenId].active, "RimowaAccessories: token type already exists");
        require(bytes(ipfsCid).length > 0, "RimowaAccessories: empty CID");

        _tokenConfigs[tokenId] = TokenConfig({
            maxSupply: maxSupply,
            mintedCount: 0,
            category: TokenCategory.ACCESSORY,
            active: true,
            ipfsCid: ipfsCid
        });

        emit TokenTypeCreated(tokenId, TokenCategory.ACCESSORY, maxSupply, ipfsCid);
    }

    /**
     * @notice Crée une nouvelle édition limitée (collaboration Supreme, Porsche...).
     * @dev L'ID est auto-incrémenté à partir de 1000.
     *      Les éditions limitées ont obligatoirement un maxSupply > 0.
     *
     * @param maxSupply Offre maximale (doit être > 0)
     * @param ipfsCid   CID IPFS des métadonnées de la collaboration
     * @return tokenId  ID assigné à cette édition
     */
    function createLimitedEdition(
        uint256 maxSupply,
        string calldata ipfsCid
    ) external onlyRole(COLLECTION_MANAGER_ROLE) returns (uint256 tokenId) {
        require(maxSupply > 0, "RimowaAccessories: limited edition must have max supply");
        require(bytes(ipfsCid).length > 0, "RimowaAccessories: empty CID");

        unchecked {
            tokenId = _nextCollectionId++;
        }

        _tokenConfigs[tokenId] = TokenConfig({
            maxSupply: maxSupply,
            mintedCount: 0,
            category: TokenCategory.LIMITED_EDITION,
            active: true,
            ipfsCid: ipfsCid
        });

        emit TokenTypeCreated(tokenId, TokenCategory.LIMITED_EDITION, maxSupply, ipfsCid);
    }

    /**
     * @notice Désactive une collection (plus de mint possible).
     */
    function deactivateCollection(uint256 tokenId)
        external
        onlyRole(COLLECTION_MANAGER_ROLE)
    {
        require(_tokenConfigs[tokenId].active, "RimowaAccessories: already inactive");
        _tokenConfigs[tokenId].active = false;
        emit CollectionDeactivated(tokenId);
    }

    // ═══════════════════════════════════════════════════════════════
    //                        MINT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Mint d'un accessoire ou d'une édition limitée.
     *
     * @param to      Adresse du Smart Account destinataire
     * @param tokenId ID du token à minter
     * @param amount  Quantité (ex: 1 pour une édition limitée, N pour un cadenas)
     * @param data    Données supplémentaires (vide si aucun)
     */
    function mint(
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes calldata data
    ) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(to != address(0), "RimowaAccessories: mint to zero address");
        require(amount > 0, "RimowaAccessories: amount must be > 0");

        TokenConfig storage config = _tokenConfigs[tokenId];
        require(config.active, "RimowaAccessories: token type not active");

        // Vérification de l'offre maximale
        if (config.maxSupply > 0) {
            require(
                config.mintedCount + amount <= config.maxSupply,
                "RimowaAccessories: would exceed max supply"
            );
        }

        // Mise à jour AVANT le mint pour éviter le reentrancy
        unchecked {
            config.mintedCount += amount;
        }

        _mint(to, tokenId, amount, data);
        emit AccessoryMinted(tokenId, to, amount);
    }

    /**
     * @notice Batch mint pour optimiser le gas sur de grandes séries.
     * @dev Avantage : une seule tx pour minter plusieurs accessoires différents.
     *      Typique pour : pack de bienvenue RIMOWA (cadenas + housse + étiquette).
     *
     * @param to      Adresse destinataire
     * @param ids     Tableau des IDs à minter
     * @param amounts Tableau des quantités correspondantes
     * @param data    Données supplémentaires
     */
    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(to != address(0), "RimowaAccessories: mint to zero address");
        require(ids.length == amounts.length, "RimowaAccessories: length mismatch");
        require(ids.length > 0, "RimowaAccessories: empty arrays");

        // Validation de tous les tokens avant tout mint (atomicité)
        uint256 len = ids.length;
        for (uint256 i = 0; i < len;) {
            TokenConfig storage config = _tokenConfigs[ids[i]];
            require(config.active, "RimowaAccessories: token type not active");
            require(amounts[i] > 0, "RimowaAccessories: amount must be > 0");

            if (config.maxSupply > 0) {
                require(
                    config.mintedCount + amounts[i] <= config.maxSupply,
                    "RimowaAccessories: would exceed max supply"
                );
            }
            // Mise à jour du compteur
            unchecked {
                config.mintedCount += amounts[i];
                ++i;
            }
        }

        _mintBatch(to, ids, amounts, data);
        emit BatchMinted(to, ids, amounts);
    }

    // ═══════════════════════════════════════════════════════════════
    //                   FONCTIONS DE LECTURE
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Retourne la configuration d'un type de token.
     */
    function getTokenConfig(uint256 tokenId)
        external
        view
        returns (TokenConfig memory)
    {
        return _tokenConfigs[tokenId];
    }

    /**
     * @notice URI IPFS d'un token (construit depuis le CID stocké).
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(_tokenConfigs[tokenId].active || totalSupply(tokenId) > 0, "RimowaAccessories: unknown token");
        return string(abi.encodePacked(IPFS_PREFIX, _tokenConfigs[tokenId].ipfsCid));
    }

    /**
     * @notice Disponibilité restante pour un token à offre limitée.
     *         Retourne type(uint256).max pour les tokens sans limite.
     */
    function remainingSupply(uint256 tokenId) external view returns (uint256) {
        TokenConfig storage config = _tokenConfigs[tokenId];
        if (config.maxSupply == 0) return type(uint256).max;
        return config.maxSupply - config.mintedCount;
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
        override(ERC1155, ERC2981, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
