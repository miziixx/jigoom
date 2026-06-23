import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

// base: './' → 정적 호스팅·Capacitor(파일 프로토콜) 모두에서 상대경로로 동작
export default defineConfig({
  base: "./",
  plugins: [
    react(),
    // 6-1: PWA(오프라인/설치). 아이콘은 public/icon.svg.
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["icon.svg"],
      manifest: {
        name: "살림 관리",
        short_name: "살림",
        description: "집을 돌보는 살림 동반자 — 집안일·재고·가계부·보관",
        lang: "ko",
        theme_color: "#3b9b4f",
        background_color: "#faf7f2",
        display: "standalone",
        start_url: "./",
        scope: "./",
        icons: [
          { src: "icon.svg", sizes: "any", type: "image/svg+xml", purpose: "any maskable" },
        ],
      },
    }),
  ],
  server: {
    host: true, // 같은 네트워크의 휴대폰에서 접속해 테스트
  },
});
