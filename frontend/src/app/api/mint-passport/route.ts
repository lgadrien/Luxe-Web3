import { NextResponse } from 'next/server';
import { ethers } from 'ethers';
import fs from 'fs/promises';
import path from 'path';
import { getProductById } from '@/data/products';

export async function POST(request: Request) {
  try {
    const { email, serialNumber, cid, productId } = await request.json();

    // 1. Connexion au noeud RPC (Sepolia Public Node par défaut pour la démo)
    const rpcUrl = process.env.RPC_URL || "https://rpc.sepolia.org";
    const provider = new ethers.JsonRpcProvider(rpcUrl);

    // 2. Chargement du portefeuille de la boutique RIMOWA (Le Relayer qui paie le gas)
    const privateKey = process.env.ADMIN_PRIVATE_KEY;
    if (!privateKey) {
      throw new Error("🚨 La clé privée (ADMIN_PRIVATE_KEY) est manquante dans le fichier .env.local du backend/frontend !");
    }
    const adminWallet = new ethers.Wallet(privateKey, provider);

    // 3. Liaison au Smart Contract déployé
    const contractAddress = "0x3eD4C7CDac825029F694c216Bf3825073AB356C2";
    const abi = [
      "function mintPassport(address to, string serialNumber, string pinataCid) external returns (uint256)"
    ];
    const contract = new ethers.Contract(contractAddress, abi, adminWallet);

    // 4. Création d'un portefeuille numérique automatique (Smart Account ERC-4337 abstrait)
    // Au lieu de forcer l'utilisateur à avoir MetaMask, la marque lui crée un coffre fort numérique généré en arrière plan (Custodial Wallet).
    const userWeb3Vault = ethers.Wallet.createRandom();

    console.log(`[SERVEUR] Ordre de Mint reçu pour l'email: ${email}`);
    console.log(`[SERVEUR] Création du coffre fort client : ${userWeb3Vault.address}`);
    
    // --- 4.5. Pinata Web3 Storage (Génération de Metadata décentralisée) ---
    const pinataJWT = process.env.PINATA_JWT;
    let finalCid = cid || "QmTestFrontendIntegrationRealTime123";

    if (pinataJWT && productId) {
      const product = getProductById(productId);
      const metadataJSON = {
        name: `Passeport Numérique RIMOWA : ${product?.name || serialNumber}`,
        description: product?.description || "Produit authentique RIMOWA sécurisé sur Ethereum.",
        image: `https://rimowa.com${product?.images?.[0] || '/fake-image.png'}`, // Habituellement, on upload l'image sur IPFS aussi. 
        attributes: [
          { trait_type: "Numéro de Série", value: serialNumber },
          { trait_type: "Authenticité", value: "Garantie Manufacture RIMOWA" },
          { trait_type: "Propriétaire Initial", value: email.toLowerCase() }
        ]
      };

      console.log(`[SERVEUR] Upload de l'âme du NFT sur IPFS (Pinata) en cours...`);
      const cleanJwt = pinataJWT.replace(/\s+/g, ""); // Nettoyage d'espaces / retours à la ligne copiés par erreur
      const pinataRes = await fetch("https://api.pinata.cloud/pinning/pinJSONToIPFS", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${cleanJwt}`
        },
        body: JSON.stringify({
          pinataMetadata: { name: `RIMOWA_${serialNumber}.json` },
          pinataContent: metadataJSON
        })
      });

      if (pinataRes.ok) {
        const pinataData = await pinataRes.json();
        finalCid = pinataData.IpfsHash;
        console.log(`[SERVEUR] Succès Pinata ! CID généré => ipfs://${finalCid}`);
      } else {
        const errorText = await pinataRes.text();
        console.error(`[SERVEUR] Erreur API Pinata (${pinataRes.status}) :`, errorText);
      }
    }
    
    // 5. Exécution On-chain INVISIBLE pour l'utilisateur
    // L'administrateur (adminWallet) paie l'essence (gas), l'utilisateur reçoit le NFT.
    const tx = await contract.mintPassport(userWeb3Vault.address, serialNumber, finalCid);
    console.log(`[SERVEUR] Transaction envoyée ! Hash: ${tx.hash}`);
    
    // 6. On attend la finalisation du bloc
    await tx.wait();
    console.log(`[SERVEUR] Transaction validée avec succès sur Sepolia !`);

    // 6.5 Sauvegarde dans la "Base de données" ( Coffre Fort )
    const dbPath = path.join(process.cwd(), 'src/data/db.json');
    let db = [];
    try {
      const fileData = await fs.readFile(dbPath, 'utf8');
      db = JSON.parse(fileData);
    } catch(e) { }

    db.push({
      email: email.toLowerCase(),
      productId,
      serialNumber,
      txHash: tx.hash,
      vaultAddress: userWeb3Vault.address,
      mintDate: new Date().toISOString()
    });

    await fs.writeFile(dbPath, JSON.stringify(db, null, 2), 'utf8');

    // 7. On renvoie le succès au frontend
    return NextResponse.json({ 
      success: true, 
      txHash: tx.hash,
      vaultAddress: userWeb3Vault.address 
    });

  } catch (error: any) {
    console.error("Erreur serveur d'Abstraction :", error);
    return NextResponse.json({ error: error.message || "Erreur inconnue" }, { status: 500 });
  }
}
