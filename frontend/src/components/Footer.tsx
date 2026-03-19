import React from 'react';
import Link from 'next/link';
import './Footer.css';

export default function Footer() {
  return (
    <footer className="footer">
      <div className="footer-content">
        <div className="footer-links">
          <h4>Service Client</h4>
          <Link href="#">Contact</Link>
          <Link href="#">Garantie à Vie</Link>
          <Link href="#">Passeport Numérique</Link>
        </div>
        <div className="footer-brand">
          <h3>RIMOWA</h3>
          <p>L'alliance de la Haute Ingénierie Web3 et de l'Excellence du Luxe.</p>
        </div>
      </div>
    </footer>
  );
}
