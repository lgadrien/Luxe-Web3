"use client";
import React from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import './Home.css';

export default function Home() {
  const router = useRouter();

  const discoverCategories = [
    { name: 'Valises', image: 'https://images.unsplash.com/photo-1553532435-93d532a45f15?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80', slug: 'valise' },
    { name: 'Sacs', image: 'https://images.unsplash.com/photo-1590874103328-eac38a683ce7?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80', slug: 'sac' },
    { name: 'Accessoires', image: '/images/home_accessoires.png', slug: 'accessoire' }
  ];

  const navigateTo = (slug: string) => {
    router.push(`/category/${slug}`);
  };

  return (
    <div className="home">
      {/* Hero Image from Rimowa */}
      <section className="hero">
        <div className="media-placeholder">
          <img src="https://www.rimowa.com/on/demandware.static/-/Library-Sites-RimowaSharedLibrary/default/dw6495318c/images/landing/imagecontainer_fw_mobile/HERO_BANNER_MOB1_12032026.jpg" alt="Rimowa Collection Hero" className="bg-media" />
          <div className="overlay"></div>
        </div>
        <div className="hero-content reveal-up">
          <h1>Engineering Invisible Luxury</h1>
          <p className="subtitle delay-100">L'Alliance de la Haute Ingénierie Web3 et de l'Excellence du Luxe.</p>
          <Link href="/discover" className="btn-primary delay-200">Découvrir l'Histoire</Link>
        </div>
      </section>

      {/* Categories Section */}
      <section className="categories-section">
        <div className="section-header reveal-up">
          <h2>L'Art du Voyage</h2>
          <div className="gold-bar"></div>
        </div>
        
        <div className="grid-container">
          {discoverCategories.map((cat, index) => (
            <div 
              key={cat.slug}
              className={`category-card delay-${(index + 1) * 100} reveal-up`}
              onClick={() => navigateTo(cat.slug)}
            >
              <div className="img-wrapper">
                <img src={cat.image} alt={cat.name} />
                <div className="card-overlay"></div>
              </div>
              <div className="card-content">
                <h3>{cat.name}</h3>
                <span className="btn-text">Explorer</span>
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
