<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { getProductById } from '../data/products'

const route = useRoute()
const productId = Number(route.params.id)
const product = computed(() => getProductById(productId))

const showCheckoutModal = ref(false)
const checkoutStep = ref(0)
const email = ref('')

const startCheckout = () => {
  showCheckoutModal.value = true
  checkoutStep.value = 1
}

const handleDemande = () => {
  if (checkoutStep.value === 1 && email.value) {
    checkoutStep.value = 2
    setTimeout(() => {
      checkoutStep.value = 3
    }, 2500)
  }
}

const closeModal = () => {
  showCheckoutModal.value = false
  checkoutStep.value = 0
  email.value = ''
}
</script>

<template>
  <div class="product-detail" v-if="product">
    <div class="header-spacing"></div>
    <div class="breadcrumb reveal-up">
      Boutique / Collection / <strong>{{ product.name }}</strong>
    </div>

    <div class="product-layout">
      <!-- Galerie -->
      <div class="product-gallery reveal-up delay-100">
        <div class="gallery-grid">
          <img v-for="(img, idx) in product.images" :key="idx" :src="img" :alt="`${product.name} Vue ${idx + 1}`" />
        </div>
      </div>

      <!-- Specs & Action -->
      <div class="product-actions reveal-up delay-200">
        <h1>{{ product.name }}</h1>
        <p class="price">{{ product.price }} €</p>
        
        <div class="gold-bar"></div>

        <p class="description">
          {{ product.description }} &mdash; L'alliance parfaite de la technologie et du design. 
          Équipée de la technologie Blockchain invisible, chaque valise ou accessoire intègre un passeport numérique infalsifiable (Jumeau Numérique 3D et Certificat On-Chain).
        </p>

        <ul class="specs">
          <li><strong>Matière:</strong> Haute Performance</li>
          <li><strong>Garantie:</strong> À vie</li>
          <li><strong>Authenticité:</strong> Puce NFC Cryptographique avec Compteur Monotone</li>
        </ul>

        <button class="btn-primary w-full" @click="startCheckout">
          Commander & Générer le Passeport
        </button>
      </div>
    </div>

    <!-- Modal "Demande" Paiement & Web3 -->
    <div v-if="showCheckoutModal" class="modal-overlay">
      <div class="modal">
        <button class="close-btn" @click="closeModal">✕</button>
        
        <div v-if="checkoutStep === 1" class="step">
          <h2>Création de votre Identité Web3</h2>
          <p>La technologie s'efface pour laisser place au luxe. Saisissez votre email pour créer votre Passeport Numérique (sans seed phrase, sans frais de gas).</p>
          <input type="email" v-model="email" placeholder="votre@email.com" class="input-modern" />
          <button class="btn-primary" @click="handleDemande">Valider avec Biométrie / Email</button>
        </div>

        <div v-if="checkoutStep === 2" class="step loading-step">
          <div class="spinner"></div>
          <h2>Abstraction de Compte en cours...</h2>
          <p>Génération de votre Smart Account (ERC-4337)...<br/>Ancrage sur Base Sepolia...</p>
        </div>

        <div v-if="checkoutStep === 3" class="step success-step">
          <div class="icon-success">✓</div>
          <h2>Passeport Numérique Créé !</h2>
          <p>
            Félicitations. Votre paiement est validé et votre Jumeau Numérique 3D est stocké de manière perpétuelle sur Arweave. 
            À la réception de la valise, un scan NFC confirmera l'authenticité absolue.
          </p>
          <button class="btn-secondary" @click="closeModal">Retour à la boutique</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.product-detail {
  padding: 0 4rem 6rem;
  max-width: 1400px;
  margin: 0 auto;
}

.header-spacing {
  height: 100px;
}

.breadcrumb {
  margin: 2rem 0 4rem;
  font-size: 0.9rem;
  letter-spacing: 0.1rem;
  color: #666;
  text-transform: uppercase;
}

.product-layout {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 6rem;
}

.product-gallery {
  display: block;
}

.gallery-grid {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.gallery-grid img {
  width: 100%;
  height: auto;
  object-fit: cover;
  background: white;
  padding: 2rem;
  box-shadow: 0 10px 40px rgba(0,0,0,0.05);
  border-radius: 4px;
}

.product-actions h1 {
  font-size: 3rem;
  letter-spacing: 0.2rem;
  text-transform: uppercase;
  margin-bottom: 1rem;
}

.price {
  font-size: 1.5rem;
  font-weight: 500;
  color: var(--color-gold);
}

.gold-bar {
  width: 50px;
  height: 2px;
  background-color: var(--color-gold);
  margin: 2rem 0;
}

.description {
  font-size: 1.05rem;
  line-height: 1.8;
  color: #444;
  margin-bottom: 3rem;
}

.specs {
  list-style: none;
  margin-bottom: 4rem;
}

.specs li {
  padding: 1rem 0;
  border-bottom: 1px solid rgba(0,0,0,0.05);
  font-size: 0.95rem;
  display: flex;
  justify-content: space-between;
}

.specs li strong {
  font-weight: 500;
  color: var(--color-charcoal);
  text-transform: uppercase;
  letter-spacing: 0.1rem;
  font-size: 0.85rem;
}

.w-full {
  width: 100%;
  text-align: center;
  padding: 1.2rem;
  font-size: 1rem;
}

/* Modal CSS */
.modal-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(26,26,26,0.8);
  backdrop-filter: blur(5px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
}

.modal {
  background: var(--color-cream);
  padding: 4rem;
  max-width: 600px;
  width: 90%;
  position: relative;
  text-align: center;
  box-shadow: 0 20px 60px rgba(0,0,0,0.2);
  border: 1px solid rgba(212, 175, 55, 0.3);
}

.close-btn {
  position: absolute;
  top: 1.5rem; right: 1.5rem;
  background: none; border: none;
  font-size: 1.5rem; cursor: pointer; color: #999;
}

.step h2 {
  font-size: 2rem;
  margin-bottom: 1.5rem;
  color: var(--color-gold);
}

.step p {
  line-height: 1.6;
  margin-bottom: 2rem;
  color: #555;
}

.input-modern {
  width: 100%;
  padding: 1rem;
  border: 1px solid #ddd;
  background: transparent;
  margin-bottom: 2rem;
  font-family: inherit;
  font-size: 1rem;
  outline: none;
  transition: border-color 0.3s;
}

.input-modern:focus {
  border-color: var(--color-gold);
}

/* Spinner */
.loading-step .spinner {
  width: 60px; height: 60px;
  border: 3px solid rgba(212, 175, 55, 0.2);
  border-top-color: var(--color-gold);
  border-radius: 50%;
  animation: spin 1s infinite linear;
  margin: 0 auto 2rem;
}

@keyframes spin { 100% { transform: rotate(360deg); } }

.icon-success {
  font-size: 4rem;
  color: var(--color-gold);
  margin-bottom: 1rem;
}
</style>
