<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { allProducts } from '../data/products'

const route = useRoute()
const router = useRouter()
const categoryName = computed(() => route.params.slug as string)

const products = computed(() => {
  return allProducts[categoryName.value.toLowerCase()] || []
})

const formatCategoryTitle = (slug: string) => {
  const titles: Record<string, string> = {
    valise: 'Valises',
    sac: 'Sacs & Bagages',
    accessoire: 'Accessoires'
  }
  return titles[slug.toLowerCase()] || slug
}

const goToProduct = (id: number) => {
  router.push(`/product/${id}`)
}
</script>

<template>
  <div class="category-page">
    <div class="header-spacing"></div>

    <div class="page-title reveal-up">
      <h1 class="title-text">{{ formatCategoryTitle(categoryName) }}</h1>
      <div class="gold-bar"></div>
    </div>

    <div class="product-grid">
      <div 
        v-for="(product, index) in products" 
        :key="product.id"
        class="product-card"
        :class="`delay-${(index % 4 + 1) * 100} reveal-up`"
        @click="goToProduct(product.id)"
      >
        <div class="product-image">
          <img :src="product.images[0]" :alt="product.name" class="main-img" />
          <img :src="product.images[1]" :alt="product.name + ' detail'" class="hover-img" />
          <div class="quick-view">Découvrir</div>
        </div>
        <div class="product-info">
          <h3>{{ product.name }}</h3>
          <p class="desc">{{ product.description }}</p>
          <p class="price">{{ product.price }} €</p>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.category-page {
  padding: 0 4rem 6rem;
  max-width: 1600px;
  margin: 0 auto;
}

.header-spacing {
  height: 120px;
}

.page-title {
  text-align: center;
  margin-bottom: 5rem;
}

.title-text {
  font-size: 3rem;
  letter-spacing: 0.3rem;
  text-transform: uppercase;
}

.gold-bar {
  width: 60px;
  height: 2px;
  background-color: var(--color-gold);
  margin: 1.5rem auto 0;
}

.product-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 3rem 2rem;
}

.product-card {
  cursor: pointer;
  background: white;
  padding: 1rem;
  box-shadow: 0 5px 20px rgba(0,0,0,0.03);
  transition: transform 0.4s ease, box-shadow 0.4s ease;
  border-radius: 4px;
}

.product-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 15px 30px rgba(0,0,0,0.08);
}

.product-image {
  position: relative;
  overflow: hidden;
  height: 380px;
  background: var(--color-gray);
  margin-bottom: 1.5rem;
  border-radius: 2px;
}

.product-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: opacity 0.6s ease, transform 0.6s ease;
  position: absolute;
  top: 0; left: 0;
}

.hover-img {
  opacity: 0;
}

.product-card:hover .main-img {
  opacity: 0;
}

.product-card:hover .hover-img {
  opacity: 1;
  transform: scale(1.05);
}

.quick-view {
  position: absolute;
  bottom: -50px;
  left: 0; right: 0;
  background: rgba(253, 251, 247, 0.9);
  color: var(--color-charcoal);
  text-align: center;
  padding: 1rem;
  text-transform: uppercase;
  letter-spacing: 0.1rem;
  font-size: 0.8rem;
  transition: bottom 0.4s ease;
}

.product-card:hover .quick-view {
  bottom: 0;
}

.product-info {
  text-align: center;
}

.product-info h3 {
  font-size: 1.1rem;
  letter-spacing: 0.1rem;
  margin-bottom: 0.5rem;
  text-transform: uppercase;
}

.desc {
  font-size: 0.85rem;
  color: #666;
  margin-bottom: 1rem;
  letter-spacing: 0.05rem;
}

.price {
  font-size: 1rem;
  font-weight: 500;
  color: var(--color-gold);
}
</style>
