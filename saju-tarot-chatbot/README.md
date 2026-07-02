# 인사이트 오라클 · 사주/타로 리딩 챗봇 (MVP 1단계)

"100% 적중"을 내세우지 않는다. 대신:
- **계산**: `lunar-javascript`(만세력)로 사주 원국(연/월/일/시주, 오행, 십성)을 실제로 정확히 계산한다.
- **해석**: 계산된 사실만 LLM(`claude-sonnet-5`)에 넘기고, 근거·경향·주의점을 구분해 밀도 있게 풀이하게 한다. 단정적 예언 표현은 시스템 프롬프트에서 금지한다.

## 스택
Vite + React + TypeScript + zustand + react-router-dom, Vercel 서버리스 함수(`api/reading.ts`)에서 Anthropic API 호출.

## 로컬 실행

```bash
npm install
cp .env.example .env   # ANTHROPIC_API_KEY 채우기
```

`api/`(서버리스 함수)까지 함께 로컬에서 띄우려면 Vercel CLI가 필요하다.

```bash
npm i -g vercel   # 최초 1회
vercel dev
```

프론트엔드만 빠르게 볼 때는 `npm run dev`로도 되지만, 이 경우 `/api/reading` 호출은 실패한다(서버리스 함수가 뜨지 않음).

## 빌드

```bash
npm run build
```

## 배포 (Vercel)
1. Vercel 프로젝트를 이 폴더(`saju-tarot-chatbot/`)를 루트로 연결한다.
2. 프로젝트 환경변수에 `ANTHROPIC_API_KEY`를 추가한다(클라이언트에는 절대 노출되지 않고 서버리스 함수에서만 사용됨).
3. `vercel.json`이 이미 `framework: vite`, `outputDirectory: dist`로 설정되어 있어 별도 설정 없이 배포된다.

## 현재 범위 (MVP 1~2단계)
- 사주: 입력(양/음력, 시간 모름), 원국 계산, 오행/십성, **대운·세운·월운**(성별 따라 순/역행, 입춘·절기 기준)
- 해석 포커스 선택: 전반 / 직업·돈 / 연애·관계 / 건강·컨디션 (포커스별 필수 항목을 프롬프트로 강제)
- 타로: 1장 / 3장(과거·현재·미래) / 5장(상황·장애물·조언·주변·전개), 정·역방향, 자리(포지션) 의미 기반 **카드 조합 해석**
- 사주+타로 통합 리딩(사주=장기, 타로=단기, 충돌 시 구분), 후속 질문(챗봇형 대화), 결과 저장(localStorage)

다음 단계로 미룸(3단계): 리딩 비교, 즐겨찾기, PDF 저장, 공유 이미지, 결제/구독, 카드 애니메이션 등 웹앱 고도화.
