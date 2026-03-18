// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * @title  RimowaNFCVerifier — Pont Phygital NFC ↔ Blockchain
 * @author RIMOWA Digital & Innovation Lab
 * @notice Vérification cryptographique on-chain des puces NFC intégrées
 *         dans chaque valise RIMOWA. Implémente le protocole SUN
 *         (Secure Unique NFC) compatible avec NXP NTAG 424 DNA.
 *
 * Protocole SUN RIMOWA :
 *   1. La puce NXP NTAG 424 DNA génère à chaque scan une URL unique :
 *      https://auth.rimowa.com/verify?uid=<UID>&ctr=<counter>&mac=<CMAC>
 *   2. L'app RIMOWA extrait (uid, counter, mac) et appelle ce contrat
 *   3. Ce contrat vérifie la signature ECDSA off-chain fournie par le backend
 *   4. Si valide → authenticité prouvée on-chain
 *
 * Anti-clonage :
 *   - Le compteur NFC (counter) est monotone : un clone sans le compteur exact
 *     sera immédiatement détecté
 *   - La clé de dérivation est stockée uniquement par le backend sécurisé RIMOWA
 *   - On-chain : seule la vérification ECDSA de la signature backend est effectuée
 *
 * Sécurité :
 *   - ECDSA avec secp256k1 (même courbe qu'Ethereum)
 *   - Zéro tx.origin
 *   - ReentrancyGuard sur les fonctions d'état
 *   - Registre des compteurs pour détecter les replay attacks
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RimowaNFCVerifier is AccessControl, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;

    // ═══════════════════════════════════════════════════════════════
    //                          ROLES
    // ═══════════════════════════════════════════════════════════════

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant CHIP_REGISTRAR_ROLE = keccak256("CHIP_REGISTRAR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ═══════════════════════════════════════════════════════════════
    //                          TYPES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Données d'une puce NFC enregistrée
    struct NFCChip {
        bytes16 uid;            // UID unique de la puce NXP (16 bytes)
        uint256 passportTokenId; // Token ERC-721 associé
        uint32 lastValidCounter; // Dernier compteur NFC valide connu
        bool active;            // Puce active (désactivée si compromission détectée)
        uint256 registeredAt;   // Timestamp d'enregistrement
    }

    // ═══════════════════════════════════════════════════════════════
    //                          STORAGE
    // ═══════════════════════════════════════════════════════════════

    /// @notice Adresse du signataire backend RIMOWA (serveur sécurisé HSM)
    address public rimowaSigner;

    /// @notice Adresse du contrat RimowaPassport
    address public passportContract;

    /// @notice Registre des puces NFC : uid → NFCChip
    mapping(bytes16 => NFCChip) private _chips;

    /// @notice Anti-replay : uid + counter → déjà utilisé ?
    mapping(bytes32 => bool) private _usedNonces;

    /// @notice Nombre total de vérifications réussies
    uint256 public totalVerifications;

    // ═══════════════════════════════════════════════════════════════
    //                          EVENTS
    // ═══════════════════════════════════════════════════════════════

    event ChipRegistered(
        bytes16 indexed uid,
        uint256 indexed passportTokenId,
        uint256 timestamp
    );

    event NFCVerified(
        bytes16 indexed uid,
        uint256 indexed passportTokenId,
        uint32 counter,
        address indexed verifiedBy,
        uint256 timestamp
    );

    event NFCVerificationFailed(
        bytes16 indexed uid,
        uint32 counter,
        address indexed attemptedBy,
        string reason
    );

    event ChipDeactivated(bytes16 indexed uid, string reason);
    event SignerUpdated(address indexed oldSigner, address indexed newSigner);
    event PassportContractUpdated(address indexed newContract);

    // ═══════════════════════════════════════════════════════════════
    //                        CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @param initialAdmin      Adresse admin (multisig RIMOWA)
     * @param _rimowaSigner     Adresse EOA/HSM du serveur de signature backend
     * @param _passportContract Adresse du contrat RimowaPassport
     */
    constructor(
        address initialAdmin,
        address _rimowaSigner,
        address _passportContract
    ) {
        require(initialAdmin != address(0), "RimowaNFCVerifier: zero admin");
        require(_rimowaSigner != address(0), "RimowaNFCVerifier: zero signer");

        rimowaSigner = _rimowaSigner;

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(SIGNER_ROLE, _rimowaSigner);
        _grantRole(CHIP_REGISTRAR_ROLE, initialAdmin);
        _grantRole(PAUSER_ROLE, initialAdmin);

        if (_passportContract != address(0)) {
            passportContract = _passportContract;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                   ENREGISTREMENT DES PUCES
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Enregistre une nouvelle puce NFC lors de la fabrication.
     * @dev Appelé lors du jumelage physique valise ↔ blockchain.
     *
     * @param uid             UID de la puce NXP NTAG 424 DNA (16 bytes)
     * @param passportTokenId Token ERC-721 correspondant
     */
    function registerChip(
        bytes16 uid,
        uint256 passportTokenId
    ) external onlyRole(CHIP_REGISTRAR_ROLE) whenNotPaused {
        require(uid != bytes16(0), "RimowaNFCVerifier: zero UID");
        require(!_chips[uid].active, "RimowaNFCVerifier: chip already registered");
        require(passportTokenId > 0, "RimowaNFCVerifier: invalid passport ID");

        _chips[uid] = NFCChip({
            uid: uid,
            passportTokenId: passportTokenId,
            lastValidCounter: 0,
            active: true,
            registeredAt: block.timestamp
        });

        emit ChipRegistered(uid, passportTokenId, block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════════
    //                   VÉRIFICATION NFC
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Vérifie l'authenticité d'une valise via sa puce NFC.
     *
     * @dev Flow complet :
     *   1. L'app RIMOWA scanne la puce → récupère uid, counter, rawMac
     *   2. Le backend RIMOWA vérifie le CMAC NXP hors-chaîne, puis signe
     *      le message (uid + counter + passportTokenId) avec sa clé ECDSA
     *   3. L'app appelle verifyNFC() avec uid, counter, signature
     *   4. Ce contrat vérifie la signature ECDSA du backend
     *   5. Vérifie le compteur monotone (anti-replay)
     *   6. Émet NFCVerified si tout est valide
     *
     * @param uid         UID de la puce NFC
     * @param counter     Compteur de scan NFC (monotone croissant)
     * @param signature   Signature ECDSA du backend RIMOWA sur le message hashé
     * @return tokenId    Token ERC-721 associé (0 si échec)
     */
    function verifyNFC(
        bytes16 uid,
        uint32 counter,
        bytes calldata signature
    ) external whenNotPaused nonReentrant returns (uint256 tokenId) {
        NFCChip storage chip = _chips[uid];

        // Vérification 1 : puce enregistrée et active
        if (!chip.active) {
            emit NFCVerificationFailed(uid, counter, msg.sender, "Chip not active");
            return 0;
        }

        // Vérification 2 : compteur monotone (anti-replay et anti-clone)
        if (counter <= chip.lastValidCounter) {
            emit NFCVerificationFailed(uid, counter, msg.sender, "Counter not greater than last valid");
            return 0;
        }

        // Vérification 3 : nonce anti-replay (uid + counter déjà utilisé ?)
        bytes32 nonce = keccak256(abi.encodePacked(uid, counter));
        if (_usedNonces[nonce]) {
            emit NFCVerificationFailed(uid, counter, msg.sender, "Nonce already used");
            return 0;
        }

        // Vérification 4 : signature ECDSA du backend RIMOWA
        // Message signé = hash(uid, counter, passportTokenId, chainId)
        bytes32 messageHash = keccak256(
            abi.encodePacked(uid, counter, chip.passportTokenId, block.chainid)
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address recovered = ethSignedHash.recover(signature);

        if (recovered != rimowaSigner) {
            emit NFCVerificationFailed(uid, counter, msg.sender, "Invalid signature");
            return 0;
        }

        // ✅ Toutes les vérifications passées — mettre à jour l'état
        chip.lastValidCounter = counter;
        _usedNonces[nonce] = true;

        unchecked {
            totalVerifications++;
        }

        tokenId = chip.passportTokenId;

        emit NFCVerified(uid, tokenId, counter, msg.sender, block.timestamp);
    }

    /**
     * @notice Version view pour vérifier une signature sans modifier l'état.
     * @dev Utile pour les interfaces front-end avant de soumettre la tx.
     *      N'émet pas d'événements, ne met pas à jour les compteurs.
     */
    function previewVerification(
        bytes16 uid,
        uint32 counter,
        bytes calldata signature
    ) external view returns (bool isValid, uint256 tokenId, string memory reason) {
        NFCChip storage chip = _chips[uid];

        if (!chip.active) return (false, 0, "Chip not active");
        if (counter <= chip.lastValidCounter) return (false, 0, "Counter too low");

        bytes32 nonce = keccak256(abi.encodePacked(uid, counter));
        if (_usedNonces[nonce]) return (false, 0, "Nonce already used");

        bytes32 messageHash = keccak256(
            abi.encodePacked(uid, counter, chip.passportTokenId, block.chainid)
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address recovered = ethSignedHash.recover(signature);

        if (recovered != rimowaSigner) return (false, 0, "Invalid signature");

        return (true, chip.passportTokenId, "Valid");
    }

    // ═══════════════════════════════════════════════════════════════
    //                   ADMINISTRATION
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Désactive une puce si compromission détectée.
     */
    function deactivateChip(bytes16 uid, string calldata reason)
        external
        onlyRole(CHIP_REGISTRAR_ROLE)
    {
        require(_chips[uid].active, "RimowaNFCVerifier: chip not active");
        _chips[uid].active = false;
        emit ChipDeactivated(uid, reason);
    }

    /**
     * @notice Met à jour l'adresse du signataire backend (rotation des clés).
     */
    function updateSigner(address newSigner)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newSigner != address(0), "RimowaNFCVerifier: zero address");
        address oldSigner = rimowaSigner;

        // Révoquer l'ancien rôle, accorder au nouveau
        _revokeRole(SIGNER_ROLE, oldSigner);
        _grantRole(SIGNER_ROLE, newSigner);

        rimowaSigner = newSigner;
        emit SignerUpdated(oldSigner, newSigner);
    }

    /**
     * @notice Met à jour l'adresse du contrat RimowaPassport.
     */
    function setPassportContract(address _passportContract)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_passportContract != address(0), "RimowaNFCVerifier: zero address");
        passportContract = _passportContract;
        emit PassportContractUpdated(_passportContract);
    }

    // ═══════════════════════════════════════════════════════════════
    //                   FONCTIONS DE LECTURE
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Retourne les données d'une puce NFC.
     */
    function getChipData(bytes16 uid) external view returns (NFCChip memory) {
        require(_chips[uid].registeredAt != 0, "RimowaNFCVerifier: chip not found");
        return _chips[uid];
    }

    /**
     * @notice Construit le hash du message attendu pour un scan NFC.
     * @dev Utile pour le backend pour construire la signature correcte.
     */
    function buildMessageHash(
        bytes16 uid,
        uint32 counter,
        uint256 passportTokenId
    ) external view returns (bytes32) {
        return keccak256(abi.encodePacked(uid, counter, passportTokenId, block.chainid));
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
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
