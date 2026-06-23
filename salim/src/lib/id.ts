// 간단한 고유 id 생성 (로컬 전용이라 충돌 위험 낮음)
export function uid(): string {
  return (
    Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4)
  );
}
