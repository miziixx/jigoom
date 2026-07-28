# 세컨드 브레인 진행 상황 (nemo2test)

> nemo 메모앱을 "내 폰 속 세컨드 브레인"(옵시디언/노션처럼)으로 만드는 작업 기록.
> 모든 신규 기능은 **`isNemo2Test` 플레이버 전용**으로 격리되어 있음 (다른 플레이버는 기존 동작 유지).
> 메인 브랜치: `main` (nemo2test 기준).

---

## ✅ 지금까지 한 것

### 기본 정리 / 버그 수정
- **n-gram 검색 연결**: 단순 contains → `LocalSearchService` (글자 2-gram). 한국어 조사/어미 변형 흡수.
- **`!` 단독 입력 버그 수정**: `!` 뒤에 내용 있고 단어 첫 글자일 때만 일정 피커 뜸. (`input_bar.dart`)
- **꾹 누르기 글자 사라짐 버그 수정**: `memo_tile`의 중복 `LongPressDraggable` 제거. 드래그(이동/합치기)는 `home_screen`것만 사용.
- **카드 UI**: 메모를 둥근 카드로 감쌈(점선 구분선 제거). 배경 투명 처리로 얼룩 제거. (nemo2test 전용)
- **더블탭 → 텍스트 선택 시트** (기존 onLongPress가 드래그와 충돌해서 변경).

### 세컨드 브레인 6대 기능 (전부 nemo2test 전용, 빌드 통과 확인)
1. **자동 백링크** — `lib/services/backlink_service.dart`
   - `linkedBacklinks`: 이 메모를 `[[id:..]]`로 링크한 메모들 (↩ 표시)
   - `unlinkedMentions`: 명시 링크 없이 제목을 언급한 메모들 (◇ 표시)
   - `memo_tile.dart` 하단 `backlinks` 패널에 렌더, 탭하면 이동.
2. **마크다운 내보내기** — `BackupService.exportMarkdown`
   - `[[id:..|제목]]` → 옵시디언 호환 `[[제목]]` 변환.
   - 설정 화면 '마크다운 내보내기' 버튼 (`onExportMarkdown` 콜백).
   - `backup_io.dart` / `backup_web.dart`에 `platformExportText` 추가.
3. **본문 위키링크 + 자동완성** — `input_bar.dart`
   - 입력 중 `[[검색어` → 매칭 메모 후보 표시 → 선택 시 `[[id:..|제목]]` 삽입.
   - `memo_tile.dart` 본문에서 `[[id:..|제목]]` 탭 가능하게 렌더(`_parseInline` group5 확장).
   - `InputBar`에 `allMemos` 전달.
4. **동의어(시맨틱 비슷) 검색** — `LocalSearchService`
   - 한국어 동의어 20개 그룹 사전으로 질의 확장 (운동↔헬스↔워크아웃 등).
   - ⚠️ 진짜 신경망 임베딩 아님 — 사전 기반 확장. (아래 "앞으로" 참고)
5. **데일리 노트** — `home_screen.dart` `_openDailyNote()`
   - 헤더의 today 아이콘(`_DailyNoteBtn`) → 오늘 `#daily` 노트 생성/이동, 템플릿(오늘 한 일/메모/내일 할 일) 포함.
6. **빠른 캡처** — `home_screen.dart` `_handleSharedFiles`
   - nemo2test는 공유 시 확인 다이얼로그 없이 즉시 저장 + '실행취소' 스낵바.

### 인프라
- CI 워크플로우: `.github/workflows/build-apk.yml` (nemo2test debug APK, workflow_dispatch 가능).
- APK 받는 법: GitHub Actions → Build APK 실행 → Artifacts `app-nemo2test-debug`.

---

## 🔜 앞으로 해야 할 것

### 세컨드 브레인 완성도 (우선순위 순)
- [ ] **진짜 시맨틱 검색 (임베딩)**: 현재는 동의어 사전 기반. 온디바이스 임베딩 모델(ONNX/tflite) 또는 임베딩 API로 교체하면 동의어 사전 없이도 의미 검색 가능.
- [ ] **백링크 전용 화면/탭**: 지금은 각 메모 하단 패널만. 전체 그래프 + 백링크 탐색 화면 강화.
- [ ] **그래프 뷰에 `[[링크]]` 반영**: 현재 그래프는 키워드 기반. 명시적 링크를 엣지로 강하게 반영(일부 keyword_service에 가중치 있음 — 확장 필요).
- [ ] **데일리 노트 달력 연동**: 날짜별 데일리 노트 묶어보기, 캘린더에서 바로 진입.
- [ ] **템플릿 시스템**: 데일리 노트 외에 사용자 정의 템플릿(책 리뷰/회의록 등).
- [ ] **본문 링크 자동완성 개선**: 커서 이동만으로도 후보 갱신, 키보드 위 떠있는 오버레이 형태로.

### 판매/상용화 준비 (현재 3.2/10 — 판매 불가 상태)
- [ ] 🔴 **앱 서명 수정**: 릴리즈가 debug 키로 서명됨 (`android/app/build.gradle.kts:62`). 프로덕션 keystore 필요.
- [ ] 🔴 **API 키 암호화 저장**: Claude 키가 SharedPreferences 평문 저장 (`storage_service.dart`). `flutter_secure_storage`로 교체.
- [ ] 🔴 **개인정보 처리방침**: Claude API에 메모 본문 전송 — Play Store 필수.
- [ ] 🔴 **전체 삭제 안전장치**: `clearAll()`이 휴지통/복구 없이 즉시 영구 삭제. 휴지통 또는 다단계 확인.
- [ ] 🟡 **클라우드 백업/동기화**: 현재 로컬(SharedPreferences)만. 앱 삭제 시 데이터 소실 위험.
- [ ] 🟡 **수익화 구조**: IAP/프리미엄 게이팅 전무. 결제 도입 시 필요.

### 디자인 / 접근성
- [ ] **카드 스타일 통일**: nemo2test만 둥근 카드, 나머지 각진 테두리. 공용 카드 컴포넌트.
- [ ] **접근성**: `textScaler.noScaling`이 곳곳에 박혀 시스템 글자 크기 무시됨 → 제거 또는 글자 크기 설정.
- [ ] **대비**: `kDim` 텍스트가 배경 대비 ~3:1 (WCAG 4.5:1 미달).
- [ ] **다크모드**: 시스템 다크모드 연동 없음.

---

## 📁 주요 파일 맵 (이번 작업 기준)
```
lib/
  services/
    backlink_service.dart      # 신규: 백링크 계산
    local_search_service.dart  # 동의어 확장 추가
    backup_service.dart        # exportMarkdown 추가
    backup_io.dart / backup_web.dart  # platformExportText 추가
  screens/
    home_screen.dart           # 데일리노트, 빠른캡처, 헤더 버튼, 마크다운 콜백
    settings_screen.dart       # 마크다운 내보내기 버튼
  widgets/
    memo_tile.dart             # 백링크 패널, 본문 [[링크]] 렌더, 카드 UI
    input_bar.dart             # [[ 자동완성, ! 버그수정
  models/
    memo_actions.dart          # onWikiLinkTap, onNavigateToMemo 콜백
  flavor.dart                  # isNemo2Test 판별
```

## ⚠️ 참고
- `claude/amazing-planck-sicfx7` 브랜치는 **완전히 다른 아키텍처(새 앱 리라이트)** — main과 합치면 충돌 수백개. 따로 둠. (제거 요청했으나 원격 삭제 권한 없어 GitHub 웹에서 직접 삭제 필요)
- 로컬 환경에 flutter 없음 → 빌드 검증은 GitHub Actions(`build-apk.yml`)로만 가능.
