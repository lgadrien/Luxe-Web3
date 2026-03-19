"use client";
import React, { useState, useMemo } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { getProductById } from '@/data/products';
import { ethers } from 'ethers';
import '../ProductDetail.css';

export default function ProductDetail() {
  const router = useRouter();
  const params = useParams();
  const productId = Number(Array.isArray(params.id) ? params.id[0] : params.id);
  
  const product = useMemo(() => getProductById(productId), [productId]);

  const [showCheckoutModal, setShowCheckoutModal] = useState(false);
  const [checkoutStep, setCheckoutStep] = useState(0);
  const [email, setEmail] = useState('');

  const startCheckout = () => {
    setShowCheckoutModal(true);
    setCheckoutStep(1);
  };

  const closeModal = () => {
    setShowCheckoutModal(false);
    setCheckoutStep(0);
    setEmail('');
  };

  const handleDemande = async () => {
    if (checkoutStep === 1) {
      if (!email || !email.includes('@')) {
        alert("Veuillez saisir une adresse email valide.");
        return;
      }

      setCheckoutStep(2); // Affichage du spinner 
      
      try {
        const randomSerial = `RIM-DEMO-${Math.floor(Math.random() * 9999)}`;
        const fakeCid = "QmTestFrontendIntegrationRealTime123";

        // L'appel se fait sur notre propre backend, INVISIBLE pour l'utilisateur. 
        // Zero MetaMask pop-up. Zero interaction.
        const response = await fetch('/api/mint-passport', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            email,
            serialNumber: randomSerial,
            cid: fakeCid
          })
        });

        const data = await response.json();

        if (!response.ok) {
          throw new Error(data.error);
        }

        console.log("Succès absolu ! Hash:", data.txHash);
        
        // On affiche l'écran de succès
        setCheckoutStep(3);
        
      } catch (error: any) {
        console.error("Erreur invisible de paiement:", error);
        alert("Erreur de la transaction silencieuse: " + (error.message || error));
        setCheckoutStep(1);
      }
    }
  };

  if (!product) return <div className="product-detail"><div className="header-spacing"></div><p>Produit introuvable.</p></div>;

  return (
    <div className="product-detail">
      <div className="header-spacing"></div>
      <div className="breadcrumb reveal-up">
        Boutique / Collection / <strong>{product.name}</strong>
      </div>

      <div className="product-layout">
        {/* Galerie */}
        <div className="product-gallery reveal-up delay-100">
          <div className="gallery-grid">
            {product.images.map((img, idx) => (
              <img key={idx} src={img} alt={`${product.name} Vue ${idx + 1}`} />
            ))}
          </div>
        </div>

        {/* Specs & Action */}
        <div className="product-actions reveal-up delay-200">
          <h1>{product.name}</h1>
          <p className="price">{product.price} €</p>
          
          <div className="gold-bar"></div>

          <p className="description">
            {product.description} &mdash; L'alliance parfaite de la technologie et du design. 
            Équipée de la technologie Blockchain invisible, chaque valise ou accessoire intègre un passeport numérique infalsifiable (Jumeau Numérique 3D et Certificat On-Chain).
          </p>

          <ul className="specs">
            <li><strong>Matière:</strong> Haute Performance</li>
            <li><strong>Garantie:</strong> À vie</li>
            <li><strong>Authenticité:</strong> Puce NFC Cryptographique avec Compteur Monotone</li>
          </ul>

          <button className="btn-primary w-full" onClick={startCheckout}>
            Commander & Générer le Passeport
          </button>
        </div>
      </div>

      {/* Modal "Demande" Paiement & Web3 */}
      {showCheckoutModal && (
        <div className="modal-overlay">
          <div className="modal">
            <button className="close-btn" onClick={closeModal}>✕</button>
            
            {checkoutStep === 1 && (
              <div className="step">
                <h2>Caisse Web3 Expérientielle</h2>
                <p>La technologie s'efface totalement pour laisser place au luxe. Saisissez votre email. Votre Passeport Numérique et votre Jumeau 3D Blockchain seront générés automatiquement sans MetaMask, sans phrase de récupération, ni frais de gas.</p>
                <input 
                  type="email" 
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="votre.email@luxe.com" 
                  className="input-modern mt-6" 
                />
                <button className="btn-primary" onClick={handleDemande}>Valider l'achat silencieux</button>
              </div>
            )}

            {checkoutStep === 2 && (
              <div className="step loading-step">
                <div className="spinner"></div>
                <h2>Abstraction de Compte en cours...</h2>
                <p>Génération de votre Smart Account (ERC-4337)...<br/>Ancrage sur Base Sepolia...</p>
              </div>
            )}

            {checkoutStep === 3 && (
              <div className="step success-step">
                <div className="icon-success">✓</div>
                <h2>Passeport Numérique Créé !</h2>
                <p>
                  Félicitations. Votre paiement est validé et votre Jumeau Numérique 3D est stocké de manière perpétuelle sur Arweave. 
                  À la réception de la valise, un scan NFC confirmera l'authenticité absolue.
                </p>
                <button className="btn-secondary" onClick={closeModal}>Retour à la boutique</button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
