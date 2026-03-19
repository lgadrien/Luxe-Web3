"use client";
import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import './Header.css';

export default function Header() {
  const [isScrolled, setIsScrolled] = useState(false);
  const pathname = usePathname();

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 50);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <header className={`header ${isScrolled ? 'header-scrolled' : ''}`}>
      <div className="header-inner">
        <Link href="/" className="brand">RIMOWA</Link>
        <nav className="nav-links">
          <Link href="/category/valise" className={pathname === '/category/valise' ? 'router-link-active' : ''}>Valises</Link>
          <Link href="/category/sac" className={pathname === '/category/sac' ? 'router-link-active' : ''}>Sacs</Link>
          <Link href="/category/accessoire" className={pathname === '/category/accessoire' ? 'router-link-active' : ''}>Accessoires</Link>
          <Link href="/discover" className={pathname === '/discover' ? 'router-link-active' : ''}>Découvrir</Link>
        </nav>
        <div className="header-actions">
          <button className="icon-btn">Recherche</button>
          <button className="icon-btn">Compte</button>
          <button className="icon-btn">Panier</button>
        </div>
      </div>
    </header>
  );
}
