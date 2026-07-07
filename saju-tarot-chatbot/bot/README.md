# 나의 사주 선생님 — 텔레그램 봇

만세력 기반으로 정확히 계산한 사주 데이터(원국·십성·지장간·통근/투출·신강신약·격국·신살·대운/세운/월운·오늘 일진)를 근거로, Claude가 "왜 그런지"를 짚어가며 설명해주는 개인 사주 선생님 봇.

- 계산은 전부 기존 웹앱 엔진(`src/lib/saju.ts`, `src/lib/fortune.ts`)을 재사용 — AI가 간지를 지어내지 않고, 프로그램이 계산한 값만 근거로 해석합니다.
- 서머타임·표준시 경선(1954~1961 UTC+8:30)·출생지 경도 보정, 야자시/조자시, 음력·윤달까지 웹앱과 동일하게 처리됩니다.

## 준비물

1. **텔레그램 봇 토큰**: 텔레그램에서 [@BotFather](https://t.me/BotFather) → `/newbot` → 토큰 복사
2. **Anthropic API 키**: console.anthropic.com

## 실행

```bash
cd saju-tarot-chatbot
npm install

TELEGRAM_BOT_TOKEN="123456:ABC-..." \
ANTHROPIC_API_KEY="sk-ant-..." \
npm run bot
```

롱폴링 방식이라 웹훅·공개 서버가 필요 없습니다. 노트북, 라즈베리파이, 아무 VPS에서나 켜두면 됩니다.

## Railway 배포

이 저장소는 여러 앱이 섞인 모노레포라서, Railway 프로젝트 설정에서 **Root Directory를 `saju-tarot-chatbot`으로 지정**해야 합니다.

1. [railway.app](https://railway.app) → New Project → **Deploy from GitHub repo** → 이 저장소(`miziixx/myapps`) 선택
2. 생성된 서비스 → **Settings**
   - **Root Directory**: `saju-tarot-chatbot`
   - **Start Command**: `npm run bot` (저장소 안 `railway.json`에도 이미 지정되어 있음)
   - **Networking**: 아무 것도 켤 필요 없음 (롱폴링 방식이라 공개 도메인/포트 불필요)
3. **Variables** 탭에서 환경변수 등록 (아래 표 참고). 최소 `TELEGRAM_BOT_TOKEN`, `ANTHROPIC_API_KEY`.
4. **중요 — 데이터 영속성**: Railway 컨테이너 파일시스템은 재배포할 때마다 초기화됩니다. `bot/data/users.json`(사주 등록 정보·대화 기록)을 계속 유지하려면:
   - 서비스 → **Volumes** → 볼륨 추가, 마운트 경로를 예: `/data` 로 지정
   - 환경변수에 `BOT_DATA_DIR=/data` 추가
   - 이렇게 안 하면 재배포할 때마다 사용자가 `/start`부터 다시 등록해야 합니다.
5. 배포 후 **Deploy Logs**에서 `사주 선생님 봇 시작 (롱폴링)` 로그가 뜨는지 확인 → 텔레그램에서 `/start` 테스트.

## 환경변수

| 변수 | 필수 | 설명 |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | ✅ | BotFather 토큰 |
| `ANTHROPIC_API_KEY` | ✅ | Claude API 키 |
| `BOT_MODEL` | — | 기본 `claude-opus-4-8` (가장 깊은 해석). 비용을 아끼려면 `claude-sonnet-5` |
| `TELEGRAM_ALLOWED_USER_IDS` | — | 쉼표 구분 텔레그램 사용자 ID. 지정하면 그 사람만 사용 가능 (개인 봇 보호). 내 ID는 [@userinfobot](https://t.me/userinfobot) 으로 확인 |
| `BOT_DATA_DIR` | — | 프로필/대화 저장 위치 (기본 `bot/data/`) |

## 사용법

1. `/start` → 안내
2. 생년월일시 등록 (한 줄, 형식 자유):
   - `1993-03-15 14:30 여 서울`
   - `음력 1990년 5월 2일 07시 20분 남 부산`
   - `1988.7.15 시간모름 남`
3. 그냥 물어보기:
   - "나 왜 신약사주야?"
   - "오늘 일진이 왜 이렇게 흘러가?"
   - "내 격국이 왜 그렇게 잡히는지 설명해줘"
   - "이번 달 흐름에서 조심할 건?"

명령어: `/saju` 원국 요약(API 호출 없음) · `/today` 오늘 일진 상세 풀이 · `/birth` 재등록 안내 · `/reset` 대화 초기화 · `/delete` 데이터 전체 삭제

## 저장/개인정보

- 프로필(생년월일시)과 최근 대화 40턴이 `bot/data/users.json` 에 저장됩니다 (git 미포함).
- `/delete` 로 언제든 완전 삭제할 수 있습니다.
