"use client";
import React from 'react';
import Link from 'next/link';
import './Discover.css';

export default function Discover() {
  return (
    <div className="discover-page">
      <div className="header-spacing"></div>

      {/* Hero Section */}
      <section className="discover-hero reveal-up">
        <div className="hero-content">
          <span className="eyebrow">HÉRITAGE & INNOVATION</span>
          <h1>L'Art de Voyager depuis 1898</h1>
          <p>L'histoire de Rimowa est celle d'une réinvention perpétuelle. Des ateliers familiaux de Cologne aux premières valises en aluminium inspirées de l'aéronautique.</p>
        </div>
        <div className="scroll-indicator">
          <span>DÉCOUVRIR</span>
          <div className="line"></div>
        </div>
      </section>

      {/* The Aluminum Revolution Section */}
      <section className="heritage-dark section-padding">
        <div className="container reveal-up">
          <div className="split-content">
            <div className="text-block">
              <h2 className="cinzel text-gold">1937 : Une Révolution de Feu</h2>
              <p>Suite à un incendie dévastateur en 1937, tout fut détruit dans l'usine de Cologne, sauf un seul composant : l'aluminium. C'est à ce moment précis qu'est née une icône.</p>
              <p>S'inspirant de l'avion Junkers F13, Rimowa fut la première marque au monde à utiliser cet alliage léger et robuste, introduisant les rainures devenues célèbres à travers le globe.</p>
            </div>
            <div className="image-block glass">
              <img src="https://www.rimowa.com/on/demandware.static/-/Library-Sites-RimowaSharedLibrary/default/dw40922d2e/images/landing/sidebyside_fw_1x1/SECTION1_STILL_NS5_2.jpg" alt="Rimowa Heritage Aluminum" />
            </div>
          </div>
        </div>
      </section>

      {/* Craftsmanship Section */}
      <section className="marble-section section-padding">
        <div className="container text-center reveal-up">
          <span className="eyebrow">CONCEPTION DE PRÉCISION</span>
          <h2 className="cinzel mb-4">La Science du Luxe Invisible</h2>
          <div className="craft-grid mt-6">
            <div className="craft-item">
              <span className="number">205</span>
              <h3>Composants Individuels</h3>
              <p>Chaque valise est un chef-d'œuvre d'ingénierie composé de plus de 200 pièces de haute précision.</p>
            </div>
            <div className="craft-item">
              <span className="number">90</span>
              <h3>Processus de Fabrication</h3>
              <p>Une alliance unique entre la robotique de pointe et le savoir-faire artisanal de nos maîtres maroquiniers.</p>
            </div>
            <div className="craft-item">
              <span className="number">∞</span>
              <h3>Garantie à Vie</h3>
              <p>Notre engagement envers la durabilité signifie que votre compagnon de route est conçu pour durer toute une vie.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Web3 Innovation Section */}
      <section className="web3-legacy section-padding">
        <div className="container reveal-up">
          <div className="split-content reverse">
            <div className="text-block">
              <h2 className="cinzel text-gold">Le Passeport Numérique : L'Avenir du Luxe</h2>
              <p>En intégrant la puce NFC sécurisée et la technologie Blockchain (Base Sepolia), Rimowa dote chaque bagage d'un jumeau numérique infalsifiable.</p>
              <p>Stocké de manière perpétuelle sur le réseau Arweave, ce passeport garantit l'origine, certifie la propriété et offre un accès exclusif à des services de conciergerie VIP et à des événements privés réservés à la communauté Rimowa.</p>
              <button className="btn-primary mt-4">Découvrir le Web3</button>
            </div>
            <div className="image-block alum-textured">
               <div className="tech-overlay">
                  <div className="pulse"></div>
                  <span>NFC CONNECTED</span>
               </div>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Finale */}
      <section className="final-cta section-padding reveal-up text-center">
        <h2 className="cinzel mb-4">Commencez Votre Voyage</h2>
        <p className="mb-6">Explorez la collection qui définit le futur de la mobilité.</p>
        <Link href="/category/valise" className="btn-secondary">Parcourir la Boutique</Link>
      </section>
    </div>
  );
}
