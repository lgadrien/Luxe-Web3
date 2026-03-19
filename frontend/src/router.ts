import { createRouter, createWebHistory } from 'vue-router'
import Home from './views/Home.vue'

const routes = [
  { path: '/', component: Home },
  { path: '/category/:slug', component: () => import('./views/Category.vue') },
  { path: '/product/:id', component: () => import('./views/ProductDetail.vue') },
  { path: '/discover', component: () => import('./views/Discover.vue') }
]

export const router = createRouter({
  history: createWebHistory(),
  routes
})
