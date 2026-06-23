import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// base: './' → 정적 호스팅·Capacitor(파일 프로토콜) 모두에서 상대경로로 동작
export default defineConfig({
  base: "./",
  plugins: [react()],
  server: {
    host: true, // 같은 네트워크의 휴대폰에서 접속해 테스트
  },
});
