export default defineNuxtConfig({
  compatibilityDate: '2026-11-17',
  devtools: { enabled: true },
  modules: ['@nuxt/eslint'],
  runtimeConfig: {
    public: {
      apiBase: 'http://localhost:8080',
    },
  },
})
