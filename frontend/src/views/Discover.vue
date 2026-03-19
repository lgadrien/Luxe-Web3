<template>
  <div class="discover-page">
    <div class="header-spacing"></div>

    <!-- Hero Section -->
    <section class="discover-hero reveal-up">
      <div class="hero-content">
        <span class="eyebrow">HÉRITAGE & INNOVATION</span>
        <h1>L'Art de Voyager depuis 1898</h1>
        <p>L'histoire de Rimowa est celle d'une réinvention perpétuelle. Des ateliers familiaux de Cologne aux premières valises en aluminium inspirées de l'aéronautique.</p>
      </div>
      <div class="scroll-indicator">
        <span>DÉCOUVRIR</span>
        <div class="line"></div>
      </div>
    </section>

    <!-- The Aluminum Revolution Section -->
    <section class="heritage-dark section-padding">
      <div class="container reveal-up">
        <div class="split-content">
          <div class="text-block">
            <h2 class="cinzel text-gold">1937 : Une Révolution de Feu</h2>
            <p>Suite à un incendie dévastateur en 1937, tout fut détruit dans l'usine de Cologne, sauf un seul composant : l'aluminium. C'est à ce moment précis qu'est née une icône.</p>
            <p>S'inspirant de l'avion Junkers F13, Rimowa fut la première marque au monde à utiliser cet alliage léger et robuste, introduisant les rainures devenues célèbres à travers le globe.</p>
          </div>
          <div class="image-block glass">
            <img src="https://www.rimowa.com/on/demandware.static/-/Library-Sites-RimowaSharedLibrary/default/dw40922d2e/images/landing/sidebyside_fw_1x1/SECTION1_STILL_NS5_2.jpg" alt="Rimowa Heritage Aluminum" />
          </div>
        </div>
      </div>
    </section>

    <!-- Craftsmanship Section -->
    <section class="marble-section section-padding">
      <div class="container text-center reveal-up">
        <span class="eyebrow">CONCEPTION DE PRÉCISION</span>
        <h2 class="cinzel mb-4">La Science du Luxe Invisible</h2>
        <div class="craft-grid mt-6">
          <div class="craft-item">
            <span class="number">205</span>
            <h3>Composants Individuels</h3>
            <p>Chaque valise est un chef-d'œuvre d'ingénierie composé de plus de 200 pièces de haute précision.</p>
          </div>
          <div class="craft-item">
            <span class="number">90</span>
            <h3>Processus de Fabrication</h3>
            <p>Une alliance unique entre la robotique de pointe et le savoir-faire artisanal de nos maîtres maroquiniers.</p>
          </div>
          <div class="craft-item">
            <span class="number">∞</span>
            <h3>Garantie à Vie</h3>
            <p>Notre engagement envers la durabilité signifie que votre compagnon de route est conçu pour durer toute une vie.</p>
          </div>
        </div>
      </div>
    </section>

    <!-- Web3 Innovation Section -->
    <section class="web3-legacy section-padding">
      <div class="container reveal-up">
        <div class="split-content reverse">
          <div class="text-block">
            <h2 class="cinzel text-gold">Le Passeport Numérique : L'Avenir du Luxe</h2>
            <p>En intégrant la puce NFC sécurisée et la technologie Blockchain (Base Sepolia), Rimowa dote chaque bagage d'un jumeau numérique infalsifiable.</p>
            <p>Stocké de manière perpétuelle sur le réseau Arweave, ce passeport garantit l'origine, certifie la propriété et offre un accès exclusif à des services de conciergerie VIP et à des événements privés réservés à la communauté Rimowa.</p>
            <button class="btn-primary mt-4">Découvrir le Web3</button>
          </div>
          <div class="image-block alum-textured">
             <div class="tech-overlay">
                <div class="pulse"></div>
                <span>NFC CONNECTED</span>
             </div>
          </div>
        </div>
      </div>
    </section>

    <!-- CTA Finale -->
    <section class="final-cta section-padding reveal-up text-center">
      <h2 class="cinzel mb-4">Commencez Votre Voyage</h2>
      <p class="mb-6">Explorez la collection qui définit le futur de la mobilité.</p>
      <router-link to="/category/valise" class="btn-secondary">Parcourir la Boutique</router-link>
    </section>
  </div>
</template>

<style scoped>
.discover-page {
  background-color: var(--color-cream);
  min-height: 100vh;
}

.header-spacing {
  height: 80px;
}

.section-padding {
  padding: 8rem 2rem;
}

.container {
  max-width: 1400px;
  margin: 0 auto;
}

/* Hero */
.discover-hero {
  height: 85vh;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  text-align: center;
  background: linear-gradient(rgba(244, 241, 235, 0.4), rgba(244, 241, 235, 0.4)), url('https://images.unsplash.com/photo-1596700818274-1ed2877a5ea0.jpg');
  background-size: cover;
  background-position: center;
  position: relative;
  overflow: hidden;
}

.hero-content h1 {
  font-size: 4.5rem;
  letter-spacing: 0.3rem;
  text-transform: uppercase;
  margin: 1.5rem 0;
  color: var(--color-charcoal);
  max-width: 1000px;
}

.hero-content p {
  font-size: 1.2rem;
  max-width: 600px;
  margin: 0 auto;
  line-height: 1.8;
  color: #555;
}

.scroll-indicator {
  position: absolute;
  bottom: 2rem;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  font-size: 0.75rem;
  letter-spacing: 0.2rem;
  color: #666;
}

.scroll-indicator .line {
  width: 1px;
  height: 60px;
  background: #666;
  margin-top: 1rem;
  animation: line-slide 2s infinite ease-in-out;
}

@keyframes line-slide {
  0% { transform: scaleY(0); transform-origin: top; }
  50% { transform: scaleY(1); transform-origin: top; }
  50.1% { transform: scaleY(1); transform-origin: bottom; }
  100% { transform: scaleY(0); transform-origin: bottom; }
}

/* Sections */
.heritage-dark {
  background-color: var(--color-charcoal);
  color: white;
}

.split-content {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 6rem;
  align-items: center;
}

.split-content.reverse {
  direction: rtl;
}

.split-content.reverse .text-block {
  direction: ltr;
}

.text-block h2 {
  font-size: 2.5rem;
  margin-bottom: 2rem;
}

.text-block p {
  font-size: 1.1rem;
  line-height: 1.8;
  margin-bottom: 1.5rem;
  opacity: 0.9;
}

.image-block {
  height: 600px;
  overflow: hidden;
  box-shadow: 0 30px 60px rgba(0,0,0,0.1);
}

.image-block img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 1.5s ease;
}

.image-block:hover img {
  transform: scale(1.05);
}

/* Craft Grid */
.craft-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 4rem;
  margin-top: 6rem;
}

.craft-item .number {
  font-family: 'Cinzel', serif;
  font-size: 4rem;
  color: var(--color-gold);
  display: block;
  margin-bottom: 1rem;
}

.craft-item h3 {
  font-size: 1.4rem;
  letter-spacing: 0.1rem;
  text-transform: uppercase;
  margin-bottom: 1.5rem;
}

.craft-item p {
  color: #666;
  line-height: 1.6;
}

/* Special Textures */
.alum-textured {
  background: linear-gradient(to right, #e0e0e0, #f5f5f5, #e0e0e0);
  background-size: 20px 100%;
  display: flex;
  justify-content: center;
  align-items: center;
  position: relative;
  background-image: 
    repeating-linear-gradient(90deg, 
      transparent, transparent 15px, 
      rgba(0,0,0,0.02) 15px, rgba(0,0,0,0.02) 16px
    );
}

.tech-overlay {
  background: rgba(255,255,255,0.8);
  backdrop-filter: blur(10px);
  padding: 3rem;
  border-radius: 50%;
  text-align: center;
  border: 1px solid var(--color-gold);
}

.pulse {
  width: 40px;
  height: 40px;
  background: var(--color-gold);
  border-radius: 50%;
  margin: 0 auto 1.5rem;
  position: relative;
}

.pulse::after {
  content: '';
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  border: 2px solid var(--color-gold);
  border-radius: 50%;
  animation: pulse-ring 2s infinite ease-out;
}

@keyframes pulse-ring {
  0% { transform: scale(1); opacity: 1; }
  100% { transform: scale(2.5); opacity: 0; }
}

.tech-overlay span {
  display: block;
  font-size: 0.8rem;
  letter-spacing: 0.3rem;
  color: var(--color-charcoal);
  font-weight: bold;
}

.text-gold {
  color: var(--color-gold);
}

@media (max-width: 1024px) {
  .split-content {
    grid-template-columns: 1fr;
    gap: 4rem;
  }
  .image-block {
    height: 400px;
  }
  .hero-content h1 {
    font-size: 3rem;
  }
}
</style>
