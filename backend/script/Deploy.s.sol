// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * @title  Deploy.s.sol — Script de Déploiement Foundry
 * @notice Déploie l'ensemble de l'infrastructure RIMOWA DPP sur Base Sepolia.
 *         Lance forge script avec : --rpc-url $ALCHEMY_RPC_URL --broadcast
 *
 * Variables d'environnement requises (.env) :
 *   ALCHEMY_RPC_URL   : RPC Base Sepolia via Alchemy
 *   PRIVATE_KEY       : Clé privée du déployeur (jamais commitée)
 *   PINATA_CID        : CID IPFS de test du premier passeport
 *   RIMOWA_ADMIN      : Adresse multisig admin RIMOWA (optionnel, défaut = déployeur)
 *   RIMOWA_SIGNER     : Adresse EOA/HSM du serveur de signature NFC backend
 *   ROYALTY_RECEIVER  : Adresse de la trésorerie RIMOWA
 *
 * Commande de déploiement :
 *   source .env
 *   forge script script/Deploy.s.sol \
 *     --rpc-url $ALCHEMY_RPC_URL \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast \
 *     --verify \
 *     -vvvv
 *
 * Ordre de déploiement (respecter les dépendances) :
 *   1. RimowaPassport     (ERC-721 principal)
 *   2. RimowaAccessories  (ERC-1155 accessoires)
 *   3. RimowaSoulbound    (ERC-5192, dépend de RimowaPassport)
 *   4. RimowaNFCVerifier  (NFC, dépend de RimowaPassport)
 *   5. Configuration croisée des contrats
 *   6. Mint de démonstration (passeport test)
 */

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/RimowaPassport.sol";
import "../src/RimowaAccessories.sol";
import "../src/RimowaSoulbound.sol";
import "../src/RimowaNFCVerifier.sol";

contract DeployRimowa is Script {
    // ═══════════════════════════════════════════════════════════════
    //                    CONFIGURATION
    // ═══════════════════════════════════════════════════════════════

    /// @notice Chaîne ID de Base Sepolia
    uint256 constant BASE_SEPOLIA_CHAIN_ID = 84532;

    /// @notice Royalties par défaut : 5% (500 basis points)
    uint96 constant DEFAULT_ROYALTY_BPS = 500;

    /// @notice ERC-4337 EntryPoint officiel (même adresse sur toutes les chaînes)
    address constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    /// @notice Préfixe IPFS standard
    string constant IPFS_PREFIX = "ipfs://";

    // ═══════════════════════════════════════════════════════════════
    //                      SCRIPT PRINCIPAL
    // ═══════════════════════════════════════════════════════════════

    function run() external {
        // Vérification du réseau
        require(
            block.chainid == BASE_SEPOLIA_CHAIN_ID,
            "Deploy: Ce script est configure pour Base Sepolia uniquement"
        );

        // Chargement des variables d'environnement
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // Admin : utilise RIMOWA_ADMIN si défini, sinon le déployeur
        address admin = vm.envOr("RIMOWA_ADMIN", deployer);

        // Signataire NFC (backend RIMOWA HSM)
        address rimowaSigner = vm.envOr("RIMOWA_SIGNER", deployer);

        // Trésorerie royalties
        address royaltyReceiver = vm.envOr("ROYALTY_RECEIVER", deployer);

        // CID IPFS du passeport de démonstration
        string memory pinataCid = vm.envOr(
            "PINATA_CID",
            string("QmRimowaDefaultDemoCIDReplaceWithRealPinataCID")
        );

        console2.log("=================================================");
        console2.log(unicode"   RIMOWA Digital Product Passport -- Deploiement");
        console2.log("=================================================");
        console2.log("Chain ID:       ", block.chainid);
        console2.log("Deployer:       ", deployer);
        console2.log("Admin:          ", admin);
        console2.log("Signer NFC:     ", rimowaSigner);
        console2.log("Royalties:      ", royaltyReceiver);
        console2.log("Royalty BPS:    ", DEFAULT_ROYALTY_BPS, "(5%)");
        console2.log("Demo IPFS CID:  ", pinataCid);
        console2.log("-------------------------------------------------");

        vm.startBroadcast(deployerKey);

        // ─── 1. Déploiement RimowaPassport (ERC-721 + EIP-2981) ───────
        RimowaPassport passport = new RimowaPassport(
            admin,
            royaltyReceiver,
            DEFAULT_ROYALTY_BPS,
            IPFS_PREFIX
        );
        console2.log("[1/4] RimowaPassport deploye:", address(passport));

        // ─── 2. Déploiement RimowaAccessories (ERC-1155) ──────────────
        RimowaAccessories accessories = new RimowaAccessories(
            admin,
            royaltyReceiver,
            DEFAULT_ROYALTY_BPS
        );
        console2.log("[2/4] RimowaAccessories deploye:", address(accessories));

        // ─── 3. Déploiement RimowaSoulbound (ERC-5192) ────────────────
        RimowaSoulbound soulbound = new RimowaSoulbound(admin, address(passport));
        console2.log("[3/4] RimowaSoulbound deploye:", address(soulbound));

        // ─── 4. Déploiement RimowaNFCVerifier ──────────────────────────
        RimowaNFCVerifier nfcVerifier = new RimowaNFCVerifier(
            admin,
            rimowaSigner,
            address(passport)
        );
        console2.log("[4/4] RimowaNFCVerifier deploye:", address(nfcVerifier));

        // ─── 5. Configuration croisée ─────────────────────────────────
        console2.log("-------------------------------------------------");
        console2.log("[5/7] Configuration croisee...");

        // Lier le contrat Soulbound au contrat Passport
        passport.setSoulboundContract(address(soulbound));

        // Accorder MINTER_ROLE au Soulbound pour l'auto-migration lors des reventes
        // (En production : accordé à l'adresse du compte admin RIMOWA ou à un smart account)
        // passport.grantRole(passport.MINTER_ROLE(), address(soulbound)); // Optionnel

        console2.log("  Soulbound lie au Passport: OK");

        // ─── 6. Types d'accessoires par défaut ────────────────────────
        console2.log("[6/7] Creation des types d accessoires...");

        // ID 1 : Cadenas TSA (offre illimitée)
        accessories.createAccessoryType(
            1,
            0,
            "QmTSALockRimowaCIDPinataReplaceWithReal001"
        );

        // ID 2 : Housse de protection (offre illimitée)
        accessories.createAccessoryType(
            2,
            0,
            "QmHousseProtectionRimowaCIDPinataReplaceWithReal002"
        );

        // ID 3 : Étiquette bagage cuir (offre illimitée)
        accessories.createAccessoryType(
            3,
            0,
            "QmEtiquetteBagageRimowaCIDPinataReplaceWithReal003"
        );

        // ID 1000 : Édition limitée — RIMOWA x Porsche Design (500 pièces)
        accessories.createLimitedEdition(
            500,
            "QmPorscheDesignRimowaCIDPinataReplaceWithReal1000"
        );

        console2.log("  Accessoires ID 1,2,3 + Edition Porsche crees: OK");

        // ─── 7. Mint de démonstration ──────────────────────────────────
        console2.log("[7/7] Mint du passeport de demonstration...");

        // Numéro de série de démonstration
        string memory demoSerial = "RIM-2024-DEMO-001-ALU-CABIN-SILVER";

        uint256 demoTokenId = passport.mintPassport(
            deployer,  // En production : adresse du Smart Account ERC-4337 du client
            demoSerial,
            pinataCid
        );

        console2.log(unicode"  Passeport demo minte — TokenId:", demoTokenId);
        console2.log("  Proprietaire:", deployer);
        console2.log("  Serie:", demoSerial);
        console2.log("  TokenURI:", passport.tokenURI(demoTokenId));

        vm.stopBroadcast();

        // ─── Résumé final ──────────────────────────────────────────────
        console2.log("=================================================");
        console2.log("        DEPLOIEMENT TERMINE AVEC SUCCES");
        console2.log("=================================================");
        console2.log("");
        console2.log("Adresses des contrats (a sauvegarder) :");
        console2.log("  RIMOWA_PASSPORT_ADDR=",  address(passport));
        console2.log("  RIMOWA_ACCESSORIES_ADDR=", address(accessories));
        console2.log("  RIMOWA_SOULBOUND_ADDR=",  address(soulbound));
        console2.log("  RIMOWA_NFC_VERIFIER_ADDR=", address(nfcVerifier));
        console2.log("");
        console2.log("Verification sur BaseScan :");
        console2.log("  https://sepolia.basescan.org/address/", address(passport));
        console2.log("");
        console2.log("Prochaines etapes :");
        console2.log("  1. Configurer le Paymaster ERC-4337 (ZeroDev/Pimlico)");
        console2.log("  2. Lier les Smart Accounts clients");
        console2.log("  3. Enregistrer les puces NFC via registerChip()");
        console2.log("  4. Uploader les metadonnees sur Pinata/IPFS");
        console2.log("  5. Uploader les jumeaux 3D sur Arweave");
        console2.log("=================================================");
    }
}
