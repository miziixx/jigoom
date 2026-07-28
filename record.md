# 변경 이력 (record)

---

## 2026-06-22 — 대시보드 멀티기기 동기화 버그 수정

### 발단
아이폰에서 대시보드(isthistodo.vercel.app) 접속 시 할 일이 전혀 보이지 않고 초기화 상태(SEED 샘플 데이터)로 표시됨. 갤럭시·맥북·패드는 정상.

---

### 원인 1 — 신규 기기 SEED 데이터 서버 오염 버그
**파일:** `dashboard/index.html`

처음 접속하는 기기(localStorage 비어있음)에서 로그인 시 `syncOnLoad()`가 로컬 SEED 샘플 데이터를 서버 데이터와 병합해 업로드하던 문제.

**수정:** `localTs === 0`이면 `freshDevice`로 판단, 서버 데이터만 그대로 사용하고 로컬 SEED는 무시.

```js
var freshDevice = (localTs === 0);
if(serverNewer){
  state.tasks = freshDevice ? sTasks.slice() : mergeByKey(sTasks, state.tasks, byId);
  // ... 나머지 필드도 동일
}
```

---

### 원인 2 — 서비스워커 캐시로 인해 수정사항 미적용
**파일:** `dashboard/sw.js`

서비스워커가 `cache-first` 전략이라 코드 수정 후에도 기존 캐시를 계속 서빙.  
→ `CACHE` 버전명을 올릴 때마다 전 기기에 최신 코드 강제 적용.

| 버전 | 변경 내용 |
|------|----------|
| `dash-v21` | SEED 오염 버그 수정 배포 |
| `dash-v22` | 관리 시트 계정·로그아웃 추가 |
| `dash-v23` | 동기화 에러 원인 표시·재시도 로직 |
| `dash-v24` | SELECT * 변경 |

---

### 원인 3 — 모바일에서 동기화 에러가 보이지 않음
**파일:** `dashboard/index.html`

동기화 실패 시 표시되는 `syncStatus`가 사이드바(`.side`) 안에 있고, 모바일에서 사이드바가 `display:none`이라 에러를 전혀 알 수 없었음.

**수정:** 모바일 화면 상단 고정 배너(`#mobSync`) 추가.  
- 동기화 실패 시 상단에 에러 내용 + **[재시도]** 버튼 표시
- 오프라인 시에도 표시

```css
.mob-sync { display:none; position:fixed; top:0; left:0; right:0; z-index:800; }
.mob-sync.err { display:block; background:#FFF6E9; color:#C77B22; }
.mob-sync.off { display:block; background:#F5F5F5; color:var(--dim); }
```

---

### 원인 4 — 모바일에서 로그아웃 버튼 없음
**파일:** `dashboard/index.html`

로그아웃 버튼이 사이드바 안에만 있어 모바일에서 접근 불가.

**수정:** 관리 시트(더보기 → 관리·테마)에 계정 섹션 추가.
- 현재 로그인된 이메일 표시 (기기 간 계정 불일치 확인용)
- 로그아웃 버튼

---

### 원인 5 — 동기화 실패 시 에러 내용 소멸 + 재시도 없음
**파일:** `dashboard/index.html`

`syncOnLoad()`의 `catch(e)`에서 에러 `e`를 버리고 있었고,  
`scheduleRetry()`는 `pushToServer`(로컬→서버)만 재시도하고 `syncOnLoad`(서버→로컬 데이터 로드)는 재시도하지 않았음.

**수정:**
- `syncErrDetail` 변수로 에러 코드·메시지 보존 및 UI 표시
- `scheduleSyncRetry()` 추가 — `syncOnLoad` 실패 시 2s·4s·8s·16s·30s 간격 자동 재시도
- `console.error('[syncOnLoad]', e)` 로깅 추가
- `setSync()` 중복 상태 무시 버그 수정 (에러 메시지가 달라도 업데이트 안 하던 것)
- 네트워크 복귀 시 `syncOnLoad`도 재시도

---

### 원인 6 — Supabase DB 컬럼 누락
**에러:** `42703 column user_data.projects does not exist`  
이후: `PGRST204 Could not find the 'theme' column in the schema cache`

`user_data` 테이블이 초기 버전(tasks, cats만 있는 구조)으로 생성된 후,  
앱 코드에 추가된 `projects`, `routines`, `memos`, `diary`, `theme` 컬럼이  
DB에는 반영되지 않은 상태였음.

다른 기기(갤럭시·맥북·패드)는 서비스워커가 이 컬럼을 쿼리하지 않는 **구버전 코드**를 캐시하고 있어 정상 동작했고, 아이폰만 새 코드를 받아 에러 발생.

**코드 수정:** 명시적 컬럼 나열 → `select("*")`로 변경해 없는 컬럼이 있어도 에러 안 나도록.

```js
// 변경 전
sb.from("user_data").select("tasks,cats,projects,routines,memos,diary,theme,updated_at")
// 변경 후
sb.from("user_data").select("*")
```

**DB 수정:** Supabase SQL Editor에서 아래 실행:

```sql
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS projects JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS routines JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS memos    JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS diary    JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS theme    TEXT  NOT NULL DEFAULT 'mint';
```

**스키마 캐시 갱신:**
```sql
SELECT pg_notify('pgrst', 'reload schema');
```

---

### 커밋 목록

| 커밋 | 내용 |
|------|------|
| `9b55695` | 신규 기기 SEED 데이터 서버 오염 버그 수정 (freshDevice) |
| `be5e119` | SW 캐시 v21 + 모바일 동기화 에러 배너 추가 |
| `fe1557b` | 관리 시트 계정·로그아웃 추가 (SW v22) |
| `655befc` | 에러 원인 표시 + syncOnLoad 재시도 로직 (SW v23) |
| `65c6573` | SELECT * 변경으로 누락 컬럼 에러 방지 (SW v24) |

---

## 이전 이력 (dashboard)

| 커밋 | 내용 |
|------|------|
| `081fd20` | 일기·메모 화면 추가 (Supabase 저장) |
| `b0be3d5` | 동기화 안정성·접근성·CDN 폴백 보강 |
| `18e5743` | 받은함 빠른메모 안드로이드 홈위젯 + 대시보드 큐 연동 |
| `1afe74e` | 보안 보강 + 모바일 탭 아이콘 통일 |
| `3083166` | 요약 위젯 + 달력 마감표시 + 검색 + 데이터 백업 |
| `89e8b10` | 루틴 절차형 구분 + 프로젝트 템플릿 마감 자동배분 |
| `6555461` | 블로그 글쓰기 루틴 템플릿 + 프로젝트 템플릿 순서번호 |
| `ef76b58` | 프로젝트 카드 세로깨짐 수정 + 템플릿 제공 |
| `eb06b1f` | 프로젝트/루틴 상세 화면 |
| `656b439` | 모바일 하단탭 더보기 메뉴로 전체 화면 접근 |
| `fb5920e` | 타임라인 독립 메뉴 + 항목 버킷 이동 |
| `fe4dce0` | 사이드바 아이콘 레일 + 빠른입력 메인 상단 이동 |
| `de83b52` | 메뉴 재구성·관리 통합·요약/통계/프로젝트/루틴 + 테마 서버저장 |

## 이전 이력 (nemo 앱)

| 커밋 | 내용 |
|------|------|
| `9c94496` | 위젯 입력창 UI 개선 (nemo2test), accent dot·툴바 구조 변경 |
| `ffc0f60` | brain·graph 화면 및 wiki 캡처·OCR·검색 서비스 추가 (nemo2test) |
| `6f5b3e0` | n-gram 기반 LocalSearchService로 검색 교체 |
| `416ee76` | [[위키링크]] 기능 추가 |
| `d4283f3` | 관련 메모 추천 섹션 추가 |
| `81476c3` | ! 단독 입력 시 일정 달력 뜨는 버그 수정 |
| `0e979bf` | 꾹 누르기 드래그와 텍스트선택 시트 충돌 수정 |
| `3b46c4e` | logroom Warm Editorial Paper 테마 리디자인 |
