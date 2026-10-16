import { defineConfig } from "vite";

const proxy = { "/api": process.env.VITE_API_PROXY || "http://localhost:8000" };

export default defineConfig({
  server: { port: 5173, proxy },
  preview: { port: 4173, proxy },
  build: { outDir: "dist", sourcemap: false },
});
