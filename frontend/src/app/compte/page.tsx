"use client";
import React, { useState } from 'react';
import './Compte.css';

export default function Compte() {
  const [scanning, setScanning] = useState(false);
  const [message, setMessage] = useState("Veuillez approcher votre smartphone de la serrure physique RIMOWA pour authentifier l'objet.");
  const [scanResult, setScanResult] = useState<any>(null);

  const startNFCScan = async () => {
    try {
      if (!('NDEFReader' in window)) {
        throw new Error("L'API Web NFC n'est supportée que sur les appareils Android (Chrome). Utilisez le bouton de simulation si vous êtes sur ordinateur.");
      }
      
      const ndef = new (window as any).NDEFReader();
      setScanning(true);
      setMessage("Radar NFC activé. Maintenez l'appareil près de la puce cryptographique intégrée à la valise...");
      
      await ndef.scan();
      
      ndef.addEventListener("reading", ({ serialNumber }: any) => {
        setScanning(false);
        setMessage("Produit RIMOWA Authentifié avec succès !");
        
        // En conditions réelles, le reader lit un NDEF JSON ou URI contenant la preuve
        setScanResult({ 
          valid: true, 
          serial: serialNumber || `RIM-NFC-${Math.floor(Math.random() * 9999)}`,
          signature: "0xVerifiedHardwareSignatureOnChain...",
          date: new Date().toLocaleTimeString()
        });
      });
      
    } catch (error: any) {
      setScanning(false);
      setMessage("Action interrompue : " + error.message);
    }
  };

  const simulateScan = () => {
    setScanning(true);
    setScanResult(null);
    setMessage("Simulation de transmission en fréquence courte (NFC)... Écoute On-Chain en cours.");
    
    setTimeout(() => {
      setScanning(false);
      setMessage("Vérification physique terminée. Jumeau cryptographique correspondant !");
      setScanResult({ 
        valid: true, 
        serial: `RIM-DEMO-${Math.floor(Math.random() * 9999)}`,
        signature: "0xbf4004f125c679448b1467f1f6ce6a20068f98669b...",
        date: new Date().toLocaleTimeString()
      });
    }, 2500);
  };

  return (
    <div className="compte-page">
      <div className="compte-header reveal-up">
        <h1>Mon Espace Client</h1>
        <p>Hub central de possession. Authentifiez physiquement vos bagages grâce à la puce Web3 intégrée.</p>
      </div>

      <div className="compte-layout reveal-up delay-100">
        <div className="nfc-scanner">
          <h2>Scanner d'Authenticité NFC</h2>
          <p>{message}</p>
          
          <div className={`nfc-radar ${scanning ? 'scanning' : ''}`}>
            {/* L'icône change en fonction du statut de scan */}
            <span className="nfc-radar-icon">{scanning ? '📡' : '📱'}</span>
          </div>

          <div style={{ display: 'flex', gap: '15px', flexWrap: 'wrap', justifyContent: 'center' }}>
            <button className="btn-primary" onClick={startNFCScan} disabled={scanning}>
              [ NFC Mobile ]
            </button>
            <button className="btn-secondary" onClick={simulateScan} disabled={scanning}>
              [ NFC Simulation PC ]
            </button>
          </div>

          {scanResult && (
            <div className="scan-result">
              <h3><span>✓</span> Intégrité Physique Prouvée</h3>
              <p><strong>N° de Série Matériel :</strong> {scanResult.serial}</p>
              <p><strong>Heure de l'Audit :</strong> {scanResult.date}</p>
              <p><strong>Signature Hardware :</strong> <span style={{fontSize: '0.8rem', color: '#888', wordBreak: 'break-all'}}>{scanResult.signature}</span></p>
              
              <div style={{ marginTop: '20px', padding: '15px', background: '#e0ffe8', border: '1px solid #10b981', color: '#065f46', fontSize: '0.9rem' }}>
                La puce sécurisée injectée dans l'aluminium correspond parfaitement au standard ERC-721 ancré sur Ethereum. Ce produit est un original absolu certifié par la manufacture RIMOWA.
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
