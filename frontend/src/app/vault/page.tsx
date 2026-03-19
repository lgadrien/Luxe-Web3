"use client";
import React, { useState } from 'react';
import Script from 'next/script';
import './Vault.css';

export default function Vault() {
  const [email, setEmail] = useState('');
  const [passports, setPassports] = useState<any[] | null>(null);
  const [loading, setLoading] = useState(false);

  const fetchPassports = async () => {
    if (!email || !email.includes('@')) {
      alert("Veuillez saisir une adresse email valide.");
      return;
    }

    setLoading(true);
    try {
      const res = await fetch(`/api/vault?email=${encodeURIComponent(email)}`);
      const data = await res.json();
      
      if (!res.ok) throw new Error(data.error);

      setPassports(data.passports);
    } catch (err: any) {
      alert("Erreur de connexion au coffre: " + err.message);
    } finally {
      setLoading(false);
    }
  };

  const downloadCertificate = (item: any) => {
    // Utilisation du CDN pour bypasser totalement le bug de compilation Turbopack/fflate de Next.js
    const jspdfModule = (window as any).jspdf;
    if (!jspdfModule || !jspdfModule.jsPDF) {
      alert("Le générateur de PDF est en cours de chargement...");
      return;
    }
    const jsPDF = jspdfModule.jsPDF;

    // Format A4 orientation paysage
    const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });

    // Dessin du cadre extérieur doré
    doc.setDrawColor(212, 175, 55); 
    doc.setLineWidth(2);
    doc.rect(10, 10, 277, 190);
    
    // Cadre intérieur fin
    doc.setLineWidth(0.5);
    doc.rect(14, 14, 269, 182);

    // Titre RIMOWA
    doc.setFontSize(40);
    doc.setTextColor(30, 30, 30);
    doc.text("RIMOWA", 148.5, 45, { align: "center" });

    // Sous-titre
    doc.setFontSize(22);
    doc.setTextColor(212, 175, 55); // Doré
    doc.text("CERTIFICAT D'AUTHENTICITÉ", 148.5, 65, { align: "center" });

    // Ligne Séparatrice
    doc.setDrawColor(220, 220, 220);
    doc.line(70, 75, 227, 75);

    // Contenu
    doc.setFontSize(14);
    doc.setTextColor(80, 80, 80);
    doc.text("Nous certifions par la présente que l'objet suivant a été authentifié", 148.5, 90, { align: "center" });
    doc.text("et est lié à un jumeau numérique inaltérable sur la blockchain.", 148.5, 100, { align: "center" });

    // Détails de la pièce
    doc.setFontSize(14);
    doc.setTextColor(0, 0, 0);
    doc.text(`PRODUIT : ${item.product?.name || 'Produit RIMOWA'}`, 148.5, 125, { align: "center" });
    doc.text(`NUMÉRO DE SÉRIE : ${item.serialNumber}`, 148.5, 135, { align: "center" });
    doc.text(`ATTRIBUÉ À : ${item.email}`, 148.5, 145, { align: "center" });

    // Données techniques de preuve (en petit)
    doc.setFontSize(10);
    doc.setTextColor(150, 150, 150);
    doc.text(`Acquisition Web3 le : ${new Date(item.mintDate).toLocaleDateString()}`, 148.5, 165, { align: "center" });
    doc.text(`Adresse du Coffre Fort (Smart Account) : ${item.vaultAddress}`, 148.5, 173, { align: "center" });
    doc.text(`Preuve Blockchain (TxHash) : ${item.txHash}`, 148.5, 181, { align: "center" });

    // Slogan de fin
    doc.text("L'Alliance de l'Excellence du Luxe et de la Technologie Web3.", 148.5, 195, { align: "center" });

    // Lancement automatique du téléchargement
    doc.save(`Certificat_RIMOWA_${item.serialNumber}.pdf`);
  };

  return (
    <div className="vault-page">
      <Script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js" strategy="lazyOnload" />

      <div className="vault-header reveal-up">
        <h1>Le Coffre Fort Web3</h1>
        <p>Vos actifs physiques et numériques en un seul point d'accès. Retrouvez vos Jumeaux 3D certifiés sur la blockchain d'Ethereum.</p>
      </div>

      {!passports && !loading && (
        <div className="login-form reveal-up delay-100">
          <input 
            type="email" 
            placeholder="Saisissez votre email" 
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="input-modern w-full" 
            autoComplete="email"
          />
          <button className="btn-primary w-full" onClick={fetchPassports}>Accéder au Coffre</button>
        </div>
      )}

      {loading && (
        <div style={{ textAlign: 'center', marginTop: '40px' }}>
          <div className="spinner"></div>
          <p style={{ marginTop: '20px' }}>Connexion sécurisée avec le réseau Ethereum...</p>
        </div>
      )}

      {passports && !loading && (
        <div className="vault-content reveal-up">
          <button 
            className="btn-secondary" 
            style={{ marginBottom: '30px' }} 
            onClick={() => setPassports(null)}
          >
            ← Refermer le coffre
          </button>
          
          <h2 style={{ marginBottom: '10px' }}>Vos Passeports Numériques.</h2>
          <p style={{ color: '#666', marginBottom: '30px' }}>Authentifié via : {email}</p>

          {passports.length === 0 ? (
            <div className="empty-vault">
              <p>Aucun passeport lié à cette adresse email. Rendez-vous en boutique pour votre premier achat.</p>
            </div>
          ) : (
            <div className="vault-grid">
              {passports.map((item, idx) => (
                <div className="passport-card" key={idx} style={{ animationDelay: `${idx * 0.15}s` }}>
                  <div className="passport-img-wrapper">
                    <div className="passport-hologram"></div>
                    {item.product?.images?.[0] ? (
                       <img src={item.product.images[0]} alt={item.product?.name} />
                    ) : (
                       <div style={{ color: '#ccc' }}>Image non disponible</div>
                    )}
                  </div>
                  
                  <div className="passport-info">
                    <h3>{item.product?.name || "Produit Web3 RIMOWA"}</h3>
                    
                    <div className="passport-detail">
                      <span>Numéro de série</span>
                      <strong>{item.serialNumber}</strong>
                    </div>
                    
                    <div className="passport-detail">
                      <span>Acquis le</span>
                      <strong>{new Date(item.mintDate).toLocaleDateString()}</strong>
                    </div>
                    
                    <div className="passport-detail">
                      <span>Smart Account</span>
                      <strong title={item.vaultAddress}>
                        {item.vaultAddress.substring(0, 6)}...{item.vaultAddress.slice(-4)}
                      </strong>
                    </div>

                    <button 
                      onClick={() => downloadCertificate(item)}
                      className="contract-link" 
                      style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 0, font: 'inherit', textAlign: 'left' }}
                    >
                      Télécharger le Certificat PDF ↓
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
