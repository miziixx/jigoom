import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";

// 개발 중에만: 집안일↔살림백과 데이터 링크 무결성 검사 (프로덕션 번들엔 미포함)
if (import.meta.env.DEV) {
  import("./data/validate").then(({ validateLinks }) => {
    const problems = validateLinks();
    if (problems.length) {
      console.warn("[데이터 링크 검증] 문제 발견:\n" + problems.join("\n"));
    } else {
      console.info("[데이터 링크 검증] 통과 — 끊긴 연결 없음");
    }
  });
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
