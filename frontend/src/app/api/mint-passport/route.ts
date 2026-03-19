import { NextResponse } from 'next/server';
import { ethers } from 'ethers';

export async function POST(request: Request) {
  try {
    const { email, serialNumber, cid } = await request.json();

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
    
    // 5. Exécution On-chain INVISIBLE pour l'utilisateur
    // L'administrateur (adminWallet) paie l'essence (gas), l'utilisateur reçoit le NFT.
    const tx = await contract.mintPassport(userWeb3Vault.address, serialNumber, cid);
    console.log(`[SERVEUR] Transaction envoyée ! Hash: ${tx.hash}`);
    
    // 6. On attend la finalisation du bloc
    await tx.wait();
    console.log(`[SERVEUR] Transaction validée avec succès sur Sepolia !`);

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
