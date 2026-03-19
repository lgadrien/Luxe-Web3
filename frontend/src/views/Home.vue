<script setup lang="ts">
import { useRouter } from 'vue-router'

const router = useRouter()

const discoverCategories = [
  { name: 'Valises', image: 'https://images.unsplash.com/photo-1553532435-93d532a45f15?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80', slug: 'valise' },
  { name: 'Sacs', image: 'https://images.unsplash.com/photo-1590874103328-eac38a683ce7?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80', slug: 'sac' },
  { name: 'Accessoires', image: '/images/home_accessoires.png', slug: 'accessoire' }
]

const navigateTo = (slug: string) => {
  router.push(`/category/${slug}`)
}
</script>

<template>
  <div class="home">
    <!-- Hero Image from Rimowa -->
    <section class="hero">
      <div class="media-placeholder">
        <img src="https://www.rimowa.com/on/demandware.static/-/Library-Sites-RimowaSharedLibrary/default/dw6495318c/images/landing/imagecontainer_fw_mobile/HERO_BANNER_MOB1_12032026.jpg" alt="Rimowa Collection Hero" class="bg-media" />
        <div class="overlay"></div>
      </div>
      <div class="hero-content reveal-up">
        <h1>Engineering Invisible Luxury</h1>
        <p class="subtitle delay-100">L'Alliance de la Haute Ingénierie Web3 et de l'Excellence du Luxe.</p>
        <router-link to="/discover" class="btn-primary delay-200">Découvrir l'Histoire</router-link>
      </div>
    </section>

    <!-- Categories Section -->
    <section class="categories-section">
      <div class="section-header reveal-up">
        <h2>L'Art du Voyage</h2>
        <div class="gold-bar"></div>
      </div>
      
      <div class="grid-container">
        <div 
          v-for="(cat, index) in discoverCategories" 
          :key="cat.slug"
          class="category-card"
          :class="`delay-${(index + 1) * 100} reveal-up`"
          @click="navigateTo(cat.slug)"
        >
          <div class="img-wrapper">
            <img :src="cat.image" :alt="cat.name" />
            <div class="card-overlay"></div>
          </div>
          <div class="card-content">
            <h3>{{ cat.name }}</h3>
            <span class="btn-text">Explorer</span>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.hero {
  position: relative;
  height: 100vh;
  width: 100vw;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-cream);
  margin-top: -80px; /* Offset the header */
}

.media-placeholder {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  z-index: -1;
}

.bg-media {
  width: 100%; height: 100%;
  object-fit: cover;
}

.overlay {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  background: linear-gradient(to bottom, rgba(26,26,26,0.3), rgba(26,26,26,0.6));
}

.hero-content {
  text-align: center;
  z-index: 10;
  max-width: 800px;
  padding: 0 2rem;
}

.hero-content h1 {
  font-size: 4.5rem;
  letter-spacing: 0.3rem;
  margin-bottom: 1.5rem;
  text-transform: uppercase;
}

.subtitle {
  font-size: 1.2rem;
  font-weight: 300;
  letter-spacing: 0.1rem;
  margin-bottom: 3rem;
  opacity: 0.9;
}

.categories-section {
  padding: 8rem 2rem;
  max-width: 1400px;
  margin: 0 auto;
}

.section-header {
  text-align: center;
  margin-bottom: 6rem;
}

.section-header h2 {
  font-size: 2.5rem;
  color: var(--color-charcoal);
  letter-spacing: 0.2rem;
  text-transform: uppercase;
}

.gold-bar {
  width: 80px;
  height: 2px;
  background-color: var(--color-gold);
  margin: 2rem auto 0;
}

.grid-container {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2rem;
}

.category-card {
  position: relative;
  height: 600px;
  overflow: hidden;
  cursor: pointer;
  group: hover;
}

.img-wrapper {
  width: 100%;
  height: 100%;
  overflow: hidden;
  position: relative;
}

.category-card img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.8s cubic-bezier(0.25, 0.46, 0.45, 0.94);
}

.card-overlay {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  background: linear-gradient(to top, rgba(26,26,26,0.8) 0%, rgba(26,26,26,0) 50%);
  opacity: 0.7;
  transition: opacity 0.4s;
}

.category-card:hover img {
  transform: scale(1.05);
}

.category-card:hover .card-overlay {
  opacity: 0.9;
}

.card-content {
  position: absolute;
  bottom: 0; left: 0; right: 0;
  padding: 3rem 2rem;
  color: var(--color-cream);
  text-align: center;
}

.card-content h3 {
  font-size: 2rem;
  letter-spacing: 0.15rem;
  margin-bottom: 1rem;
  text-transform: uppercase;
}

.btn-text {
  font-size: 0.8rem;
  text-transform: uppercase;
  letter-spacing: 0.2rem;
  color: var(--color-gold);
  position: relative;
  display: inline-block;
}

.btn-text::after {
  content: '';
  position: absolute;
  bottom: -4px;
  left: 0;
  right: 0;
  height: 1px;
  background-color: var(--color-gold);
  transform: scaleX(0);
  transition: transform 0.3s;
}

.category-card:hover .btn-text::after {
  transform: scaleX(1);
}
</style>
