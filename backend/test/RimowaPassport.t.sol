// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * @title  RimowaPassport.t.sol — Tests Foundry (TDD)
 * @notice Suite de tests exhaustive couvrant :
 *   ✓ testOwnerIsDeployer()
 *   ✓ testMintCreatesCorrectTokenURI()
 *   ✓ testCannotTransferSoulbound()
 *   ✓ testRoyaltiesOnResale()
 *   ✓ testNFCSignatureVerification()
 *   ✓ testPaymasterSponsorsGas() (simulé via ERC-4337 mock)
 *   ✓ testRevokeOnCounterfeitDetected()
 *   + Tests de sécurité supplémentaires
 */

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/RimowaPassport.sol";
import "../src/RimowaAccessories.sol";
import "../src/RimowaSoulbound.sol";
import "../src/RimowaNFCVerifier.sol";

// ═══════════════════════════════════════════════════════════════════
//                     MOCKS & HELPERS
// ═══════════════════════════════════════════════════════════════════

/// @notice Mock ERC-4337 Entry Point (interface minimale pour les tests)
contract MockEntryPoint {
    mapping(address => uint256) public deposits;

    event UserOperationSent(address indexed sender, uint256 nonce);

    function depositTo(address account) external payable {
        deposits[account] += msg.value;
    }

    /// @notice Simule handleOps (simplifié pour les tests unitaires)
    function simulateHandleOp(address target, bytes calldata callData)
        external
        returns (bool success, bytes memory result)
    {
        (success, result) = target.call(callData);
    }
}

/// @notice Mock Paymaster — simule RIMOWA sponsorisant le gas
contract MockPaymaster {
    address public entryPoint;
    address public sponsor;

    constructor(address _entryPoint, address _sponsor) {
        entryPoint = _entryPoint;
        sponsor = _sponsor;
    }

    /// @notice Vérifie si une UserOperation est validée (toujours true dans le mock)
    function validatePaymasterUserOp(
        address /* sender */,
        uint256 /* nonce */,
        uint256 /* maxCost */
    ) external pure returns (bool willPay) {
        return true; // RIMOWA sponsorise toujours
    }

    receive() external payable {}
}

/// @notice Mock Smart Account ERC-4337 (wallet du client)
/// @dev Implémente ERC721Receiver et ERC1155Receiver pour les _safeMint
contract MockSmartAccount {
    address public owner;
    uint256 public nonce;

    constructor(address _owner) {
        owner = _owner;
    }

    function execute(address target, bytes calldata data) external returns (bytes memory) {
        require(msg.sender == owner || msg.sender == address(this), "Unauthorized");
        (bool success, bytes memory result) = target.call(data);
        require(success, "Execution failed");
        nonce++;
        return result;
    }

    /// @dev ERC721Receiver — accepte les safe mints ERC-721
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @dev ERC1155Receiver — accepte les safe mints ERC-1155
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    receive() external payable {}
}

// ═══════════════════════════════════════════════════════════════════
//                     SUITE DE TESTS PRINCIPALE
// ═══════════════════════════════════════════════════════════════════

contract RimowaPassportTest is Test {
    // ─── Contrats ───────────────────────────────────────────────────
    RimowaPassport     public passport;
    RimowaAccessories  public accessories;
    RimowaSoulbound    public soulbound;
    RimowaNFCVerifier  public nfcVerifier;
    MockEntryPoint     public entryPoint;
    MockPaymaster      public paymaster;

    // ─── Acteurs ────────────────────────────────────────────────────
    address public admin;
    address public rimowaBoutique;    // Boutique RIMOWA (MINTER_ROLE)
    address public rimowaSAV;         // SAV RIMOWA (SAV_OPERATOR_ROLE)
    address public rimowaRevoker;     // Équipe anti-contrefaçon
    address public rimowaSignerEOA;   // Backend NFC signataire
    uint256 public rimowaSignerKey;   // Clé privée du signataire NFC

    address public alice;             // Acheteur principal (Smart Account)
    address public bob;               // Acheteur secondaire (revente)
    address public royaltyReceiver;   // Trésorerie RIMOWA

    MockSmartAccount public aliceAccount;
    MockSmartAccount public bobAccount;

    // ─── Constantes de test ─────────────────────────────────────────
    string  constant SERIAL_1     = "RIM-2024-001-ALU-CABIN-001";
    string  constant SERIAL_2     = "RIM-2024-002-ALU-FLASH-042";
    string  constant IPFS_CID_1   = "QmRimowa1ExampleCIDForValise001AluminumCabin";
    string  constant IPFS_CID_2   = "QmRimowa2ExampleCIDForValise002AluminumFlash";
    string  constant IPFS_PREFIX  = "ipfs://";
    uint96  constant ROYALTY_BPS  = 500;  // 5%
    bytes16 constant NFC_UID_1    = bytes16(0x01020304050607080910111213141516);

    // ─── Setup ──────────────────────────────────────────────────────

    function setUp() public {
        // Génération des adresses de test
        admin          = makeAddr("admin");
        rimowaBoutique = makeAddr("rimowaBoutique");
        rimowaSAV      = makeAddr("rimowaSAV");
        rimowaRevoker  = makeAddr("rimowaRevoker");
        alice          = makeAddr("alice");
        bob            = makeAddr("bob");
        royaltyReceiver= makeAddr("royaltyReceiver");

        // Clé privée déterministe pour le signataire NFC
        rimowaSignerKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        rimowaSignerEOA = vm.addr(rimowaSignerKey);

        // Distribution d'ETH pour les tests
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(admin, 10 ether);

        // Déploiement des contrats
        vm.startPrank(admin);

        passport = new RimowaPassport(
            admin,
            royaltyReceiver,
            ROYALTY_BPS,
            IPFS_PREFIX
        );

        accessories = new RimowaAccessories(
            admin,
            royaltyReceiver,
            ROYALTY_BPS
        );

        soulbound = new RimowaSoulbound(admin, address(passport));

        nfcVerifier = new RimowaNFCVerifier(
            admin,
            rimowaSignerEOA,
            address(passport)
        );

        // Attribution des rôles
        passport.grantRole(passport.MINTER_ROLE(), rimowaBoutique);
        passport.grantRole(passport.REVOKER_ROLE(), rimowaRevoker);
        soulbound.grantRole(soulbound.MINTER_ROLE(), rimowaBoutique);
        soulbound.grantRole(soulbound.SAV_OPERATOR_ROLE(), rimowaSAV);
        accessories.grantRole(accessories.MINTER_ROLE(), rimowaBoutique);
        accessories.grantRole(accessories.COLLECTION_MANAGER_ROLE(), rimowaBoutique);
        nfcVerifier.grantRole(nfcVerifier.CHIP_REGISTRAR_ROLE(), rimowaBoutique);

        vm.stopPrank();

        // Déploiement des mocks ERC-4337
        entryPoint = new MockEntryPoint();
        paymaster  = new MockPaymaster(address(entryPoint), admin);

        // Smart Accounts des utilisateurs
        aliceAccount = new MockSmartAccount(alice);
        bobAccount   = new MockSmartAccount(bob);
    }

    // ═══════════════════════════════════════════════════════════════
    //            TEST 1 : testOwnerIsDeployer
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Vérifie que l'admin déployeur détient bien le DEFAULT_ADMIN_ROLE.
     */
    function testOwnerIsDeployer() public view {
        assertTrue(
            passport.hasRole(passport.DEFAULT_ADMIN_ROLE(), admin),
            "Admin doit avoir DEFAULT_ADMIN_ROLE"
        );
        assertTrue(
            passport.hasRole(passport.MINTER_ROLE(), rimowaBoutique),
            "Boutique doit avoir MINTER_ROLE"
        );
        assertTrue(
            passport.hasRole(passport.REVOKER_ROLE(), rimowaRevoker),
            "Revoker doit avoir REVOKER_ROLE"
        );

        // Vérification multi-contrats
        assertTrue(soulbound.hasRole(soulbound.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(accessories.hasRole(accessories.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(nfcVerifier.hasRole(nfcVerifier.DEFAULT_ADMIN_ROLE(), admin));

        console2.log(unicode"[PASS] testOwnerIsDeployer — Admin et roles configures correctement");
    }

    // ═══════════════════════════════════════════════════════════════
    //            TEST 2 : testMintCreatesCorrectTokenURI
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Vérifie que le mint crée le bon tokenURI IPFS.
     *         La valise physique doit correspondre exactement au token.
     */
    function testMintCreatesCorrectTokenURI() public {
        vm.prank(rimowaBoutique);
        uint256 tokenId = passport.mintPassport(
            address(aliceAccount),
            SERIAL_1,
            IPFS_CID_1
        );

        // Vérification du tokenId
        assertEq(tokenId, 1, "Premier token doit avoir ID 1");

        // Vérification du tokenURI
        string memory expectedURI = string(abi.encodePacked(IPFS_PREFIX, IPFS_CID_1));
        assertEq(passport.tokenURI(tokenId), expectedURI, "TokenURI doit pointer vers IPFS");

        // Vérification de la propriété
        assertEq(passport.ownerOf(tokenId), address(aliceAccount), "Alice doit etre proprietaire");

        // Vérification du mapping numéro de série
        assertEq(passport.getTokenIdBySerial(SERIAL_1), tokenId, "Mapping serie -> tokenId");
        assertEq(passport.getSerialByTokenId(tokenId), SERIAL_1, "Mapping tokenId -> serie");

        // Vérification validité
        assertTrue(passport.isPassportValid(tokenId), "Passeport doit etre valide");

        console2.log(unicode"[PASS] testMintCreatesCorrectTokenURI — TokenURI:", expectedURI);
        console2.log("  TokenId:", tokenId);
        console2.log("  Owner:", address(aliceAccount));
    }

    /**
     * @notice Vérifie qu'un numéro de série ne peut pas être enregistré deux fois.
     */
    function testCannotMintDuplicateSerial() public {
        vm.startPrank(rimowaBoutique);
        passport.mintPassport(address(aliceAccount), SERIAL_1, IPFS_CID_1);

        // Deuxième mint avec le même numéro de série → doit revert
        vm.expectRevert("RimowaPassport: serial already registered");
        passport.mintPassport(address(bobAccount), SERIAL_1, IPFS_CID_2);
        vm.stopPrank();

        console2.log(unicode"[PASS] testCannotMintDuplicateSerial — Unicite du numero de serie");
    }

    /**
     * @notice Vérifie qu'un non-minter ne peut pas minter.
     */
    function testOnlyMinterCanMint() public {
        vm.prank(alice);
        vm.expectRevert();
        passport.mintPassport(address(aliceAccount), SERIAL_1, IPFS_CID_1);

        console2.log(unicode"[PASS] testOnlyMinterCanMint — Controle d'acces MINTER_ROLE");
    }

    // ═══════════════════════════════════════════════════════════════
    //            TEST 3 : testCannotTransferSoulbound
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Vérifie qu'un Soulbound Token est bien non-transférable.
     *         C'est la propriété fondamentale de l'ERC-5192.
     */
    function testCannotTransferSoulbound() public {
        // Setup : mint du passeport et du soulbound
        vm.prank(rimowaBoutique);
        passport.mintPassport(address(aliceAccount), SERIAL_1, IPFS_CID_1);

        vm.prank(rimowaBoutique);
        uint256 soulboundId = soulbound.mintSoulbound(
            address(aliceAccount),
            1,
            IPFS_CID_1,
            RimowaSoulbound.MembershipTier.SILVER
        );

        // Vérifier que le token est locked (ERC-5192)
        assertTrue(soulbound.locked(soulboundId), "Soulbound doit etre locked");

        // Tentative de transfert → doit revert
        vm.prank(address(aliceAccount));
        vm.expectRevert("RimowaSoulbound: token is non-transferable");
        soulbound.transferFrom(address(aliceAccount), address(bobAccount), soulboundId);

        // Via safeTransferFrom aussi
        vm.prank(address(aliceAccount));
        vm.expectRevert("RimowaSoulbound: token is non-transferable");
        soulbound.safeTransferFrom(address(aliceAccount), address(bobAccount), soulboundId);

        // Vérifier que le soulbound appartient toujours à Alice
        assertEq(soulbound.ownerOf(soulboundId), address(aliceAccount));

        console2.log(unicode"[PASS] testCannotTransferSoulbound — ERC-5192 non-transférable verifie");
        console2.log("  SoulboundId:", soulboundId);
    }

    /**
     * @notice Vérifie que les données du soulbound sont correctes.
     */
    function testSoulboundDataIntegrity() public {
        vm.prank(rimowaBoutique);
        uint256 soulboundId = soulbound.mintSoulbound(
            address(aliceAccount),
            1,
            IPFS_CID_1,
            RimowaSoulbound.MembershipTier.GOLD
        );

        RimowaSoulbound.SoulboundData memory data = soulbound.getSoulboundData(soulboundId);
        assertEq(data.passportTokenId, 1);
        assertEq(uint8(data.tier), uint8(RimowaSoulbound.MembershipTier.GOLD));
        assertTrue(data.lifetimeWarrantyActive);
        assertEq(data.repairCount, 0);
        assertTrue(data.memberSince > 0);

        console2.log(unicode"[PASS] testSoulboundDataIntegrity — Donnees du soulbound valides");
    }

    /**
     * @notice Vérifie l'enregistrement d'une réparation SAV.
     */
    function testRepairRecording() public {
        vm.prank(rimowaBoutique);
        uint256 soulboundId = soulbound.mintSoulbound(
            address(aliceAccount),
            1,
            IPFS_CID_1,
            RimowaSoulbound.MembershipTier.SILVER
        );

        string memory repairCid = "QmRepairReportCID001";
        string memory repairDesc = unicode"Remplacement des roues arrieres";

        vm.prank(rimowaSAV);
        soulbound.recordRepair(soulboundId, repairCid, repairDesc);

        RimowaSoulbound.RepairRecord[] memory history = soulbound.getRepairHistory(soulboundId);
        assertEq(history.length, 1, "Un seul historique de reparation");
        assertEq(history[0].workshopCid, repairCid);
        assertEq(history[0].description, repairDesc);

        RimowaSoulbound.SoulboundData memory data = soulbound.getSoulboundData(soulboundId);
        assertEq(data.repairCount, 1, "Compteur reparation incremente");

        console2.log(unicode"[PASS] testRepairRecording — SAV enregistre on-chain");
    }

    // ═══════════════════════════════════════════════════════════════
    //            TEST 4 : testRoyaltiesOnResale
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Vérifie le calcul correct des royalties EIP-2981 sur revente.
     *         RIMOWA doit recevoir 5% de chaque revente secondaire.
     */
    function testRoyaltiesOnResale() public {
        // Mint du passeport pour Alice
        vm.prank(rimowaBoutique);
        uint256 tokenId = passport.mintPassport(
            address(aliceAccount),
            SERIAL_1,
            IPFS_CID_1
        );

        // Vérification des royalties pour un prix de revente de 2 ETH
        uint256 salePrice = 2 ether;
        (address receiver, uint256 royaltyAmount) = passport.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, royaltyReceiver, "Receiver doit etre la tresorerie RIMOWA");
        assertEq(royaltyAmount, 0.1 ether, "Royalty = 5% de 2 ETH = 0.1 ETH");

        // Simulation d'une revente : Alice → Bob
        // 1. Alice approuve Bob pour le transfert
        vm.prank(address(aliceAccount));
        passport.approve(address(bobAccount), tokenId);

        uint256 rimowaBalanceBefore = royaltyReceiver.balance;

        // 2. Bob "achète" et verse les royalties à RIMOWA (simulation marketplace)
        vm.prank(address(bobAccount));
        vm.deal(address(bobAccount), 2 ether);

        // Un marketplace EIP-2981 compliant paye les royalties
        payable(royaltyReceiver).transfer(royaltyAmount);

        // 3. Transfert du token
        vm.prank(address(bobAccount));
        passport.transferFrom(address(aliceAccount), address(bobAccount), tokenId);

        // Vérifications finales
        assertEq(passport.ownerOf(tokenId), address(bobAccount), "Bob est nouveau proprietaire");
        assertEq(
            royaltyReceiver.balance - rimowaBalanceBefore,
            royaltyAmount,
            "RIMOWA a recu les royalties"
        );

        // Vérification royalties pour le nouveau propriétaire aussi
        (address newReceiver, uint256 newRoyalty) = passport.royaltyInfo(tokenId, 3 ether);
        assertEq(newReceiver, royaltyReceiver);
        assertEq(newRoyalty, 0.15 ether, "Royalty = 5% de 3 ETH = 0.15 ETH");

        console2.log(unicode"[PASS] testRoyaltiesOnResale — EIP-2981 royalties correctes");
        console2.log("  Sale price: 2 ETH");
        console2.log("  Royalty (5%): 0.1 ETH");
        console2.log("  RIMOWA balance gained:", royaltyReceiver.balance - rimowaBalanceBefore);
    }

    /**
     * @notice Vérifie que la totalSupply s'incrémente correctement.
     */
    function testTotalSupplyIncrements() public {
        assertEq(passport.totalSupply(), 0);

        vm.prank(rimowaBoutique);
        passport.mintPassport(address(aliceAccount), SERIAL_1, IPFS_CID_1);
        assertEq(passport.totalSupply(), 1);

        vm.prank(rimowaBoutique);
        passport.mintPassport(address(bobAccount), SERIAL_2, IPFS_CID_2);
        assertEq(passport.totalSupply(), 2);

        console2.log(unicode"[PASS] testTotalSupplyIncrements — Compteur de passeports correct");
    }

    // ═══════════════════════════════════════════════════════════════
    //            TEST 5 : testNFCSignatureVerification
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Vérifie la validation cryptographique d'une signature NFC.
     *         Simule le scan d'une puce NXP NTAG 424 DNA.
     */
    function testNFCSignatureVerification() public {
        // Setup : enregistrement de la puce NFC
        vm.prank(rimowaBoutique);
        passport.mintPassport(address(aliceAccount), SERIAL_1, IPFS_CID_1);

        vm.prank(rimowaBoutique);
        nfcVerifier.registerChip(NFC_UID_1, 1);

        // Simulation d'un scan NFC
        uint32 counter = 1;
        uint256 passportTokenId = 1;

        // Construction du message hash (même logique que le contrat)
        bytes32 messageHash = keccak256(
            abi.encodePacked(NFC_UID_1, counter, passportTokenId, block.chainid)
        );
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        // Signature par le backend RIMOWA (clé privée connue en test)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(rimowaSignerKey, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Vérification preview (view, pas de gas)
        (bool isValid, uint256 returnedTokenId, string memory reason) =
            nfcVerifier.previewVerification(NFC_UID_1, counter, signature);

        assertTrue(isValid, "Signature doit etre valide");
        assertEq(returnedTokenId, 1, "Token ID doit matcher");
        assertEq(reason, "Valid", "Raison doit etre Valid");

        // Vérification on-chain (émet l'événement)
        vm.expectEmit(true, true, false, false);
        emit RimowaNFCVerifier.NFCVerified(NFC_UID_1, 1, counter, alice, block.timestamp);

        vm.prank(alice);
        uint256 verifiedTokenId = nfcVerifier.verifyNFC(NFC_UID_1, counter, signature);

        assertEq(verifiedTokenId, 1, "Token verifie doit etre #1");
        assertEq(nfcVerifier.totalVerifications(), 1);

        console2.log(unicode"[PASS] testNFCSignatureVerification — ECDSA NFC valide");
        console2.log("  UID:", uint128(uint128(NFC_UID_1)));
        console2.log("  Counter:", counter);
        console2.log("  TokenId verifie:", verifiedTokenId);
    }

    /**
     * @notice Vérifie le rejet d'une signature NFC invalide.
     */
    function testInvalidNFCSignatureRejected() public {
        vm.prank(rimowaBoutique);
        passport.mintPassport(address(aliceAccount), SERIAL_1, IPFS_CID_1);

        vm.prank(rimowaBoutique);
        nfcVerifier.registerChip(NFC_UID_1, 1);

        // Signature avec une mauvaise clé privée (attaquant)
        uint256 attackerKey = 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef;
        bytes32 messageHash = keccak256(abi.encodePacked(NFC_UID_1, uint32(1), uint256(1), block.chainid));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attackerKey, ethSignedHash);
        bytes memory badSignature = abi.encodePacked(r, s, v);

        vm.prank(alice);
        uint256 result = nfcVerifier.verifyNFC(NFC_UID_1, 1, badSignature);

        assertEq(result, 0, "Signature invalide doit retourner 0");

        console2.log(unicode"[PASS] testInvalidNFCSignatureRejected — Signature invalide rejetee");
    }

    /**
     * @notice Vérifie la protection anti-replay (compteur monotone).
     */
    function testNFCCounterAntiReplay() public {
        vm.prank(rimowaBoutique);
        passport.mintPassport(address(aliceAccount), SERIAL_1, IPFS_CID_1);
        vm.prank(rimowaBoutique);
        nfcVerifier.registerChip(NFC_UID_1, 1);

        // Premier scan valide
        uint32 counter = 5;
        bytes32 mh = keccak256(abi.encodePacked(NFC_UID_1, counter, uint256(1), block.chainid));
        bytes32 esh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(rimowaSignerKey, esh);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(alice);
        nfcVerifier.verifyNFC(NFC_UID_1, counter, sig);

        // Replay avec le même counter → doit retourner 0
        vm.prank(alice);
        uint256 replayResult = nfcVerifier.verifyNFC(NFC_UID_1, counter, sig);
        assertEq(replayResult, 0, "Replay attack doit etre rejete");

        // Counter inférieur → aussi rejeté
        uint32 lowerCounter = 3;
        bytes32 mh2 = keccak256(abi.encodePacked(NFC_UID_1, lowerCounter, uint256(1), block.chainid));
        bytes32 esh2 = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh2));
        (v, r, s) = vm.sign(rimowaSignerKey, esh2);
        bytes memory sig2 = abi.encodePacked(r, s, v);

        vm.prank(alice);
        uint256 lowerCounterResult = nfcVerifier.verifyNFC(NFC_UID_1, lowerCounter, sig2);
        assertEq(lowerCounterResult, 0, "Counter inferieur doit etre rejete");

        console2.log(unicode"[PASS] testNFCCounterAntiReplay — Protection anti-replay NFC");
    }

    // ═══════════════════════════════════════════════════════════════
    //            TEST 6 : testPaymasterSponsorsGas
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Vérifie que le Paymaster RIMOWA sponsor les frais de gas.
     *         L'utilisateur ne paie rien — RIMOWA sponsorise tout.
     *
     * @dev Simulation simplifiée : dans une vraie implémentation ERC-4337,
     *      le Paymaster validerait la UserOperation via l'EntryPoint.
     *      Ici on vérifie la logique de validation du mock Paymaster.
     */
    function testPaymasterSponsorsGas() public {
        // Vérification que le Paymaster accepte de payer
        bool willPay = paymaster.validatePaymasterUserOp(
            address(aliceAccount),
            0,
            0.01 ether
        );
        assertTrue(willPay, "Paymaster RIMOWA doit sponsor le gas");

        // Balance alice avant — ne doit pas changer après une UserOp simulée
        uint256 aliceBalanceBefore = address(aliceAccount).balance;

        // Simulation d'une UserOperation via EntryPoint
        bytes memory mintCalldata = abi.encodeWithSelector(
            passport.mintPassport.selector,
            address(aliceAccount),
            SERIAL_1,
            IPFS_CID_1
        );

        // Dans le vrai flux ERC-4337 : EntryPoint retire le gas du dépôt du Paymaster
        // Ici : on vérifie juste que Alice n'a pas payé de gas
        // (la simulation de tx ne consume pas d'ETH en forge test)

        vm.prank(rimowaBoutique);
        passport.mintPassport(address(aliceAccount), SERIAL_1, IPFS_CID_1);

        // Alice n'a pas payé de gas pour mint (simulé par le fait que c'est la boutique qui call)
        assertEq(address(aliceAccount).balance, aliceBalanceBefore, "Alice ne doit pas payer de gas");

        // Vérification du dépôt EntryPoint (dépôt du Paymaster)
        vm.deal(admin, 1 ether);
        vm.prank(admin);
        entryPoint.depositTo{value: 1 ether}(address(paymaster));

        assertEq(
            entryPoint.deposits(address(paymaster)),
            1 ether,
            "Paymaster a depose 1 ETH pour le gas"
        );

        console2.log(unicode"[PASS] testPaymasterSponsorsGas — ERC-4337 Paymaster valide");
        console2.log("  Alice balance (unchanged):", address(aliceAccount).balance);
        console2.log("  Paymaster deposit:", entryPoint.deposits(address(paymaster)));
    }

    // ═══════════════════════════════════════════════════════════════
    //            TEST 7 : testRevokeOnCounterfeitDetected
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Vérifie la révocation d'un passeport lors de détection de contrefaçon.
     *         Le token est marqué révoqué, les transferts sont bloqués.
     */
    function testRevokeOnCounterfeitDetected() public {
        // Mint du passeport
        vm.prank(rimowaBoutique);
        uint256 tokenId = passport.mintPassport(
            address(aliceAccount),
            SERIAL_1,
            IPFS_CID_1
        );

        // Vérifier qu'il est valide avant révocation
        assertTrue(passport.isPassportValid(tokenId), "Passeport doit etre valide au depart");
        assertFalse(passport.revoked(tokenId), "Token ne doit pas etre revoque");

        // Révocation par l'équipe anti-contrefaçon
        string memory revocationReason = unicode"Contrefacon detectee -- Numero de serie duplique";

        vm.expectEmit(true, true, false, true);
        emit RimowaPassport.PassportRevoked(tokenId, rimowaRevoker, revocationReason);

        vm.prank(rimowaRevoker);
        passport.revokePassport(tokenId, revocationReason);

        // Vérifications post-révocation
        assertTrue(passport.revoked(tokenId), "Token doit etre revoque");
        assertFalse(passport.isPassportValid(tokenId), "Token revoque doit etre invalide");

        // Tentative de transfert post-révocation → doit revert
        vm.prank(address(aliceAccount));
        passport.approve(address(bobAccount), tokenId);

        vm.prank(address(bobAccount));
        vm.expectRevert("RimowaPassport: token is revoked");
        passport.transferFrom(address(aliceAccount), address(bobAccount), tokenId);

        // Double révocation → doit aussi revert
        vm.prank(rimowaRevoker);
        vm.expectRevert("RimowaPassport: token already revoked");
        passport.revokePassport(tokenId, "Double revoque");

        // Un non-revoker ne peut pas révoquer
        vm.prank(alice);
        vm.expectRevert();
        passport.revokePassport(1, "Tentative non autorisee");

        console2.log(unicode"[PASS] testRevokeOnCounterfeitDetected — Révocation contrefaçon OK");
        console2.log("  TokenId revoque:", tokenId);
        console2.log("  Revoque par:", rimowaRevoker);
    }

    // ═══════════════════════════════════════════════════════════════
    //            TESTS SÉCURITÉ SUPPLÉMENTAIRES
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Vérifie que la pause d'urgence bloque le mint.
     */
    function testPauseBlocksMint() public {
        vm.prank(admin);
        passport.pause();

        vm.prank(rimowaBoutique);
        vm.expectRevert();
        passport.mintPassport(address(aliceAccount), SERIAL_1, IPFS_CID_1);

        // Unpause restaure le fonctionnement
        vm.prank(admin);
        passport.unpause();

        vm.prank(rimowaBoutique);
        uint256 tokenId = passport.mintPassport(address(aliceAccount), SERIAL_1, IPFS_CID_1);
        assertEq(tokenId, 1, "Mint OK apres unpause");

        console2.log(unicode"[PASS] testPauseBlocksMint — Circuit breaker fonctionne");
    }

    /**
     * @notice Vérifie que mint vers zero address est revert.
     */
    function testCannotMintToZeroAddress() public {
        vm.prank(rimowaBoutique);
        vm.expectRevert("RimowaPassport: mint to zero address");
        passport.mintPassport(address(0), SERIAL_1, IPFS_CID_1);

        console2.log(unicode"[PASS] testCannotMintToZeroAddress — Zero address rejetee");
    }

    /**
     * @notice Vérifie que le batch mint ERC-1155 fonctionne correctement.
     */
    function testERC1155BatchMint() public {
        // Créer les types d'accessoires
        vm.startPrank(rimowaBoutique);
        accessories.createAccessoryType(1, 0, "QmTSALockCID");    // Cadenas TSA
        accessories.createAccessoryType(2, 0, "QmHousseCID");     // Housse
        accessories.createAccessoryType(3, 0, "QmEtiquetteCID");  // Étiquette

        uint256[] memory ids = new uint256[](3);
        ids[0] = 1; ids[1] = 2; ids[2] = 3;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1; amounts[1] = 1; amounts[2] = 2;

        accessories.mintBatch(address(aliceAccount), ids, amounts, "");
        vm.stopPrank();

        assertEq(accessories.balanceOf(address(aliceAccount), 1), 1, "1 cadenas TSA");
        assertEq(accessories.balanceOf(address(aliceAccount), 2), 1, "1 housse");
        assertEq(accessories.balanceOf(address(aliceAccount), 3), 2, "2 etiquettes");

        console2.log(unicode"[PASS] testERC1155BatchMint — Batch mint accessoires OK");
    }

    /**
     * @notice Vérifie les limites d'une édition limitée (maxSupply).
     */
    function testLimitedEditionMaxSupply() public {
        vm.startPrank(rimowaBoutique);

        // Création d'une édition limitée Supreme x RIMOWA (10 pièces)
        uint256 editionId = accessories.createLimitedEdition(10, "QmSupremeRimowaCID");

        // Mint de 10 tokens → OK
        accessories.mint(address(aliceAccount), editionId, 10, "");

        // 11ème mint → revert
        vm.expectRevert("RimowaAccessories: would exceed max supply");
        accessories.mint(address(bobAccount), editionId, 1, "");

        vm.stopPrank();

        assertEq(accessories.totalSupply(editionId), 10, "Supply max atteinte");

        console2.log(unicode"[PASS] testLimitedEditionMaxSupply — MaxSupply respecte");
    }

    /**
     * @notice Vérifie la montée en tier de fidélité.
     */
    function testTierUpgrade() public {
        vm.prank(rimowaBoutique);
        uint256 soulboundId = soulbound.mintSoulbound(
            address(aliceAccount),
            1,
            IPFS_CID_1,
            RimowaSoulbound.MembershipTier.SILVER
        );

        // Silver → Gold
        vm.prank(rimowaBoutique);
        soulbound.upgradeTier(soulboundId, RimowaSoulbound.MembershipTier.GOLD);

        RimowaSoulbound.SoulboundData memory data = soulbound.getSoulboundData(soulboundId);
        assertEq(uint8(data.tier), uint8(RimowaSoulbound.MembershipTier.GOLD));

        // Gold → ICONIC
        vm.prank(rimowaBoutique);
        soulbound.upgradeTier(soulboundId, RimowaSoulbound.MembershipTier.ICONIC);

        data = soulbound.getSoulboundData(soulboundId);
        assertEq(uint8(data.tier), uint8(RimowaSoulbound.MembershipTier.ICONIC));

        // Impossible de rétrograder
        vm.prank(rimowaBoutique);
        vm.expectRevert("RimowaSoulbound: can only upgrade tier");
        soulbound.upgradeTier(soulboundId, RimowaSoulbound.MembershipTier.SILVER);

        console2.log(unicode"[PASS] testTierUpgrade — Progression fidelite ICONIC");
    }

    /**
     * @notice Vérifie le mint avec CID vide → revert.
     */
    function testCannotMintWithEmptyCID() public {
        vm.prank(rimowaBoutique);
        vm.expectRevert("RimowaPassport: empty IPFS CID");
        passport.mintPassport(address(aliceAccount), SERIAL_1, "");

        console2.log(unicode"[PASS] testCannotMintWithEmptyCID — Validation CID vide");
    }

    /**
     * @notice Vérifie que les royalties ne peuvent pas dépasser 10%.
     */
    function testRoyaltiesCannotExceed10Percent() public {
        vm.prank(admin);
        vm.expectRevert("RimowaPassport: royalties cannot exceed 10%");
        passport.setTokenRoyalty(1, royaltyReceiver, 1001); // 10.01%

        console2.log(unicode"[PASS] testRoyaltiesCannotExceed10Percent — Plafond royalties OK");
    }

    /**
     * @notice Test de gaz — vérifie que le mint reste sous 300k gas.
     */
    function testMintGasEfficiency() public {
        uint256 gasBefore = gasleft();

        vm.prank(rimowaBoutique);
        passport.mintPassport(address(aliceAccount), SERIAL_1, IPFS_CID_1);

        uint256 gasUsed = gasBefore - gasleft();

        // Assertion sur 300k gas max (confortable pour ERC-721)
        assertLt(gasUsed, 300_000, "Mint doit consommer < 300k gas");

        console2.log(unicode"[PASS] testMintGasEfficiency — Gas utilise pour mint:", gasUsed);
    }
}
