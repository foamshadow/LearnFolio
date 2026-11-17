<script setup lang="ts">
const config = useRuntimeConfig()
</script>

<template>
  <main>
    <h1>LearnFolio</h1>
    <p>API base: <code>{{ config.public.apiBase }}</code></p>
  </main>
</template>
