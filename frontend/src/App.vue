<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'

const isScrolled = ref(false)

const handleScroll = () => {
  isScrolled.value = window.scrollY > 50
}

onMounted(() => {
  window.addEventListener('scroll', handleScroll)
})

onUnmounted(() => {
  window.removeEventListener('scroll', handleScroll)
})
</script>

<template>
  <div class="app-container">
    <header :class="{ 'header-scrolled': isScrolled }" class="header">
      <div class="header-inner">
        <router-link to="/" class="brand">RIMOWA</router-link>
        <nav class="nav-links">
          <router-link to="/category/valise">Valises</router-link>
          <router-link to="/category/sac">Sacs</router-link>
          <router-link to="/category/accessoire">Accessoires</router-link>
          <router-link to="/discover">Découvrir</router-link>
        </nav>
        <div class="header-actions">
          <button class="icon-btn">Recherche</button>
          <button class="icon-btn">Compte</button>
          <button class="icon-btn">Panier</button>
        </div>
      </div>
    </header>
    
    <main class="main-content">
      <router-view></router-view>
    </main>

    <footer class="footer">
      <div class="footer-content">
        <div class="footer-links">
          <h4>Service Client</h4>
          <a href="#">Contact</a>
          <a href="#">Garantie à Vie</a>
          <a href="#">Passeport Numérique</a>
        </div>
        <div class="footer-brand">
          <h3>RIMOWA</h3>
          <p>L'alliance de la Haute Ingénierie Web3 et de l'Excellence du Luxe.</p>
        </div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.app-container {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
.header {
  position: fixed;
  top: 0;
  width: 100%;
  z-index: 1000;
  padding: 1.5rem 2rem;
  transition: all 0.4s ease;
  background: transparent;
}
.header-scrolled {
  background: rgba(253, 251, 247, 0.95);
  backdrop-filter: blur(10px);
  padding: 1rem 2rem;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
  border-bottom: 1px solid rgba(212, 175, 55, 0.2);
}
.header-inner {
  display: flex;
  justify-content: space-between;
  align-items: center;
  max-width: 1400px;
  margin: 0 auto;
}
.brand {
  font-family: var(--font-brand);
  font-size: 2rem;
  letter-spacing: 0.2rem;
  color: var(--color-charcoal);
  text-decoration: none;
  font-weight: 300;
  text-transform: uppercase;
}
.nav-links {
  display: flex;
  gap: 2.5rem;
}
.nav-links a {
  text-decoration: none;
  color: var(--color-charcoal);
  font-size: 0.95rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.1rem;
  position: relative;
  transition: color 0.3s;
}
.nav-links a::after {
  content: '';
  position: absolute;
  width: 0;
  height: 1px;
  bottom: -4px;
  left: 0;
  background-color: var(--color-gold);
  transition: width 0.3s;
}
.nav-links a:hover::after,
.nav-links a.router-link-active::after {
  width: 100%;
}
.header-actions {
  display: flex;
  gap: 1.5rem;
}
.icon-btn {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--color-charcoal);
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.1rem;
}
.main-content {
  flex-grow: 1;
}
.footer {
  background: var(--color-charcoal);
  color: var(--color-cream);
  padding: 4rem 2rem;
  margin-top: 4rem;
}
.footer-content {
  max-width: 1400px;
  margin: 0 auto;
  display: flex;
  justify-content: space-between;
}
.footer-links h4 {
  color: var(--color-gold);
  margin-bottom: 1.5rem;
  text-transform: uppercase;
  letter-spacing: 0.1rem;
}
.footer-links a {
  display: block;
  color: var(--color-cream);
  text-decoration: none;
  margin-bottom: 0.8rem;
  opacity: 0.8;
  transition: opacity 0.3s;
}
.footer-links a:hover {
  opacity: 1;
  color: var(--color-gold);
}
</style>
