import { NextResponse } from 'next/server';
import nodemailer from 'nodemailer';

export async function POST(request: Request) {
  try {
    const { email, productName, serialNumber, txHash } = await request.json();

    if (!email) {
      return NextResponse.json({ error: 'Email manquant' }, { status: 400 });
    }

    // Configurer le transport SMTP
    // Il faut paramétrer ces variables dans le fichier .env.local du frontend
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: Number(process.env.SMTP_PORT) || 587,
      secure: false, // true pour le port 465, false pour les autres (587)
      auth: {
        user: process.env.SMTP_USER, // Exemple: contact@rimowa.com
        pass: process.env.SMTP_PASS, // Mot de passe d'application SMTP
      },
    });

    const mailOptions = {
      from: `"RIMOWA Web3" <${process.env.SMTP_USER || 'no-reply@rimowa-web3.com'}>`, // L'expéditeur
      to: email, // L'acheteur
      subject: `Votre Passeport Numérique RIMOWA : ${productName}`,
      html: `
        <div style="font-family: Arial, sans-serif; padding: 30px; color: #1a1a1a; max-width: 600px; margin: 0 auto; border: 1px solid #eee;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #1a1a1a; letter-spacing: 2px;">RIMOWA</h1>
          </div>
          <h2 style="color: #d4af37; text-transform: uppercase;">Félicitations pour votre achat !</h2>
          <p>Votre produit <strong>${productName}</strong> est désormais doté d'une identité numérique ancrée sur la blockchain de manière permanente.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
          <ul style="list-style: none; padding: 0;">
            <li style="margin-bottom: 10px;"><strong>Produit :</strong> ${productName}</li>
            <li style="margin-bottom: 10px;"><strong>Numéro de série :</strong> ${serialNumber}</li>
            <li style="margin-bottom: 10px;"><strong>Transaction Hash :</strong> <a href="https://sepolia.etherscan.io/tx/${txHash}" style="color: #d4af37;">${txHash}</a></li>
          </ul>
          <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
          <p>Conservez précieusement ce reçu. Vous retrouverez votre Jumeau Numérique 3D exclusif depuis votre portefeuille dépositaire.</p>
          <p><em>L'Alliance de la Haute Ingénierie Web3 et de l'Excellence du Luxe.</em></p>
        </div>
      `,
    };

    const info = await transporter.sendMail(mailOptions);

    return NextResponse.json({ success: true, messageId: info.messageId });
  } catch (error: any) {
    console.error('Erreur Serveur SMTP:', error);
    return NextResponse.json({ error: 'Échec de l\'envoi de l\'email', details: error.message }, { status: 500 });
  }
}
