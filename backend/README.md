# RIMOWA Digital Product Passport — Backend Web3

> Infrastructure blockchain du Passeport Numérique de Produit RIMOWA.
> Smart contracts déployables sur **Base Sepolia** (testnet) via **Foundry**.

---

## Vue d'ensemble

Chaque valise RIMOWA reçoit à la fabrication un **passeport numérique certifié on-chain** :

| Token                           | Standard             | Rôle                                                               |
| ------------------------------- | -------------------- | ------------------------------------------------------------------ |
| Passeport principal             | ERC-721 + EIP-2981   | 1 token = 1 valise unique. Royalties 5% sur revente                |
| Accessoires & Éditions limitées | ERC-1155             | Cadenas TSA, housses, collabs Supreme/Porsche/Dior                 |
| Identité VIP                    | ERC-5192 (Soulbound) | Non-transférable. SAV, fidélité Silver/Gold/Iconic, garantie à vie |
| Vérification NFC                | ECDSA secp256k1      | Pont phygital — puce NXP NTAG 424 DNA ↔ blockchain                 |

Le client RIMOWA **ne voit jamais** de seed phrase, d'adresse `0x...` ni de frais de gas.
L'authentification se fait via l'app RIMOWA (biométrie ou email) grâce à l'**Account Abstraction ERC-4337**.

---

## Stack Technique

| Composant                 | Technologie                                                               |
| ------------------------- | ------------------------------------------------------------------------- |
| Framework smart contracts | [Foundry](https://book.getfoundry.sh/)                                    |
| Réseau                    | Base Sepolia (Chain ID: 84532)                                            |
| Nœud RPC                  | [Alchemy](https://alchemy.com)                                            |
| Métadonnées JSON          | [Pinata](https://pinata.cloud) (IPFS)                                     |
| Jumeaux 3D permanents     | [Arweave](https://arweave.org)                                            |
| Account Abstraction       | ERC-4337 — [ZeroDev](https://zerodev.app) / [Pimlico](https://pimlico.io) |
| EntryPoint                | `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789`                              |

---

## Structure du Projet

```
backend/
├── foundry.toml              # Config Foundry (solc 0.8.24, optimizer, remappings)
├── .env.example              # Template des variables d'environnement
│
├── src/
│   ├── RimowaPassport.sol    # ERC-721 + EIP-2981 — Passeport principal
│   ├── RimowaAccessories.sol # ERC-1155 — Accessoires & éditions limitées
│   ├── RimowaSoulbound.sol   # ERC-5192 — Identité VIP non-transférable
│   └── RimowaNFCVerifier.sol # ECDSA — Pont phygital NFC ↔ blockchain
│
├── test/
│   └── RimowaPassport.t.sol  # 22 tests Foundry TDD (100% passing)
│
├── script/
│   └── Deploy.s.sol          # Script de déploiement Base Sepolia
│
└── lib/
    ├── forge-std/            # Outils de test Foundry
    └── openzeppelin-contracts/ # ERC-721, ERC-1155, AccessControl...
```

---

## Prérequis

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installé (`foundryup`)
- Compte [Alchemy](https://alchemy.com) — créer une app sur Base Sepolia
- Compte [Pinata](https://pinata.cloud) — pour l'upload des métadonnées IPFS
- Compte [Basescan](https://basescan.org) — pour la vérification des contrats

---

## Installation

```bash
# Cloner le repo et aller dans le dossier backend
cd backend/

# Installer les dépendances (forge-std + OpenZeppelin)
forge install

# Compiler les contrats
forge build
```

---

## Configuration

```bash
cp .env.example .env
```

Remplir `.env` :

```env
ALCHEMY_RPC_URL=https://base-sepolia.g.alchemy.com/v2/VOTRE_CLE_ALCHEMY
PRIVATE_KEY=0xVOTRE_CLE_PRIVEE_DEPLOYEUR
BASESCAN_API_KEY=VOTRE_CLE_BASESCAN
PINATA_GATEWAY=https://gateway.pinata.cloud/ipfs/

# Optionnel (défaut = adresse du déployeur)
RIMOWA_ADMIN=0xADRESSE_MULTISIG_RIMOWA
RIMOWA_SIGNER=0xADRESSE_BACKEND_NFC_HSM
ROYALTY_RECEIVER=0xADRESSE_TRESORERIE_RIMOWA
PINATA_CID=QmVotreCIDPinataDeTest
```

> ⚠️ Ne jamais committer `.env`. Il est dans `.gitignore`.

---

## Tests

```bash
# Lancer tous les tests (22 tests, 100% passing)
forge test -vvv

# Un test spécifique
forge test --match-test testNFCSignatureVerification -vvvv

# Rapport de couverture
forge coverage

# Rapport de gas
forge test --gas-report
```

### Résultat attendu

```
Ran 22 tests for test/RimowaPassport.t.sol:RimowaPassportTest
[PASS] testOwnerIsDeployer()
[PASS] testMintCreatesCorrectTokenURI()
[PASS] testCannotTransferSoulbound()
[PASS] testRoyaltiesOnResale()             ← 5% = 0.1 ETH sur 2 ETH
[PASS] testNFCSignatureVerification()      ← ECDSA backend validé
[PASS] testPaymasterSponsorsGas()          ← ERC-4337 Paymaster OK
[PASS] testRevokeOnCounterfeitDetected()   ← Révocation contrefaçon OK
[PASS] ... 15 tests supplémentaires
Suite result: ok. 22 passed; 0 failed;
```

---

## Déploiement (Base Sepolia)

```bash
source .env

forge script script/Deploy.s.sol \
  --rpc-url $ALCHEMY_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  -vvvv
```

Le script déploie dans l'ordre :

1. `RimowaPassport` (ERC-721)
2. `RimowaAccessories` (ERC-1155)
3. `RimowaSoulbound` (ERC-5192)
4. `RimowaNFCVerifier` (ECDSA)
5. Configure les liens croisés entre contrats
6. Crée les types d'accessoires par défaut (cadenas TSA, housse, étiquette)
7. Mint un passeport de démonstration

Les adresses déployées sont affichées dans la console et vérifiables sur [Base Sepolia Scan](https://sepolia.basescan.org).

---

## Architecture On-Chain / Off-Chain

```
On-chain (Base Sepolia)
  └── Hash CID IPFS uniquement — zéro donnée brute

Off-chain IPFS / Pinata
  └── JSON métadonnées : modèle, coloris, contenance, boutique...

Permanent Arweave
  └── Jumeaux numériques 3D (.glb / .usdz) de chaque modèle
```

### Structure JSON IPFS (exemple)

```json
{
  "name": "RIMOWA Original Cabin #RIM-2024-001",
  "description": "Valise cabine en aluminium. Passeport numérique certifié.",
  "image": "ipfs://<CID_photo_officielle>",
  "animation_url": "ar://<CID_jumeau_3D>.glb",
  "attributes": [
    { "trait_type": "Modèle", "value": "Original Cabin" },
    { "trait_type": "Matière", "value": "Aluminium" },
    { "trait_type": "Coloris", "value": "Silver" },
    { "trait_type": "Contenance", "value": "36L" },
    { "trait_type": "Année", "value": "2024" },
    { "trait_type": "Boutique", "value": "Paris Champs-Élysées" },
    { "trait_type": "Garantie", "value": "À vie" }
  ]
}
```

---

## Pont Phygital NFC

Chaque valise RIMOWA contient une **puce NXP NTAG 424 DNA** dans la coque :

1. Le client scanne la puce avec l'app RIMOWA
2. La puce génère une URL unique avec un **compteur monotone** (protocole SUN)
3. Le backend RIMOWA vérifie le CMAC hors-chaîne et signe le message (ECDSA)
4. `RimowaNFCVerifier.verifyNFC()` valide la signature on-chain
5. L'app affiche : _"Votre valise est authentifiée ✓"_

Le clonage de puce est rendu obsolète par le compteur monotone : un clone ne peut pas reproduire le compteur exact.

---

## Rôles et Contrôle d'Accès

| Rôle                  | Accordé à               | Permissions                       |
| --------------------- | ----------------------- | --------------------------------- |
| `DEFAULT_ADMIN_ROLE`  | Multisig RIMOWA         | Gestion des rôles, configuration  |
| `MINTER_ROLE`         | Boutiques RIMOWA        | Mint des passeports et soulbounds |
| `REVOKER_ROLE`        | Équipe anti-contrefaçon | Révocation on-chain               |
| `SAV_OPERATOR_ROLE`   | Ateliers SAV RIMOWA     | Enregistrement des réparations    |
| `CHIP_REGISTRAR_ROLE` | Usine RIMOWA            | Enregistrement des puces NFC      |
| `PAUSER_ROLE`         | Équipe sécurité         | Circuit breaker d'urgence         |

---

## Checklist Sécurité

- ✅ `ReentrancyGuard` sur toutes les fonctions d'état critiques
- ✅ Zéro `tx.origin` — uniquement `msg.sender`
- ✅ `Pausable` d'urgence sur les 4 contrats
- ✅ Royalties plafonnées à 10% maximum
- ✅ Protection anti-replay NFC (nonce `uid + counter`)
- ✅ Compteur NFC monotone (détection de clonage)
- ✅ Révocation de passeport en cas de contrefaçon prouvée
- ✅ `uint256` dans les structs (pas de slot packing inefficace)
- ✅ Zéro boucle non bornée on-chain

---

## Commandes Utiles

```bash
# Formater le code
forge fmt

# Linter
forge lint

# Snapshot de gas (pour tracking des régressions)
forge snapshot

# Node local pour les tests
anvil

# Lire une variable on-chain
cast call <CONTRAT> "totalSupply()" --rpc-url $ALCHEMY_RPC_URL

# Vérifier un contrat manuellement
forge verify-contract <ADRESSE> src/RimowaPassport.sol:RimowaPassport \
  --chain base-sepolia \
  --etherscan-api-key $BASESCAN_API_KEY
```
