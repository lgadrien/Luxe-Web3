import { NextResponse } from 'next/server';
import fs from 'fs/promises';
import path from 'path';
import { getProductById } from '@/data/products';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const email = searchParams.get('email');

    if (!email) {
      return NextResponse.json({ error: "Email requis." }, { status: 400 });
    }

    const dbPath = path.join(process.cwd(), 'src/data/db.json');
    let db: any[] = [];
    try {
      const fileData = await fs.readFile(dbPath, 'utf8');
      db = JSON.parse(fileData);
    } catch(e) {
      // Si le fichier n'existe pas, on renvoie un tableau vide
      return NextResponse.json({ passports: [] });
    }

    // On trouve toutes les transactions de cet utilisateur
    const userPurchases = db.filter(item => item.email === email.toLowerCase());

    // On joint avec les données du produit (images, nom, etc.)
    const passports = userPurchases.map(purchase => {
      const product = getProductById(purchase.productId);
      return {
        ...purchase,
        product
      };
    });

    return NextResponse.json({ passports });

  } catch (error: any) {
    console.error("Erreur serveur Coffre Fort:", error);
    return NextResponse.json({ error: error.message || "Erreur inconnue" }, { status: 500 });
  }
}
