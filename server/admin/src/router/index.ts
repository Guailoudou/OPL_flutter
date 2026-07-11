import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'Dashboard',
    component: () => import('@/views/Dashboard.vue')
  },
  {
    path: '/presets',
    name: 'Presets',
    component: () => import('@/views/Presets.vue')
  },
  {
    path: '/notices',
    name: 'Notices',
    component: () => import('@/views/Notices.vue')
  },
  {
    path: '/sponsors',
    name: 'Sponsors',
    component: () => import('@/views/Sponsors.vue')
  },
  {
    path: '/releases',
    name: 'Releases',
    component: () => import('@/views/Releases.vue')
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router
