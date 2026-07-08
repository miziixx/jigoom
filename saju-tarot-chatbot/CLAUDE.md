# CLAUDE.md

This file records the current product direction, implementation choices, and safety rules for the Saju Tarot chatbot project. Future Claude/Codex agents should read this before making changes.

## Startup Must-Read

Every Claude Code/Codex session must start by reading:

1. `CLAUDE.md`
2. `docs/record.md`
3. `docs/next_steps.md`

Codex-oriented startup instructions are also mirrored in `AGENTS.md`.

## Mandatory Agent Routine

Claude Code/Codex agents working on this app must treat this file as the shared project memory. Before making changes, read:

- `CLAUDE.md`
- `docs/record.md`
- `docs/next_steps.md`
- Relevant docs under `docs/validation`

When meaningful product, prompt, pricing, privacy, or architecture decisions change, update `docs/record.md` and `docs/next_steps.md` so future Claude Code/Codex sessions continue from the same context.

Claude Code/Codex agents working on this app must use the validation docs in `docs/validation`.

Before changing saju calculation, luck-cycle calculation, lunar/solar conversion, birth-time handling, or evidence serialization:

- Read `docs/validation/saju-calculation-validation.md`.
- Keep changes compatible with the calculation validation checklist.
- Add or update automated tests when the behavior can be verified in code.
- Do not alter calculation behavior casually for UI or copy changes.

Before changing prompts, reading output structure, follow-up chat behavior, evidence display, or safety language:

- Read `docs/validation/reading-quality-validation.md`.
- Preserve the "easy language first, expert evidence retained" structure.
- Check for unsupported claims, fear-based language, deterministic predictions, and high-risk advice.
- Keep medical, legal, investment, marriage, divorce, resignation, and relocation advice as non-deterministic decision support.

After material changes:

- Run `npm test`.
- Run `npm run build`.
- If tests cannot be run, clearly report why.
- If changes affect GitHub/Vercel deployment, commit intentionally and push `main` only when requested or when the user has clearly asked to publish.

## Product Direction

The app should not merely shorten saju readings. The target is:

- Keep calculation accuracy, interpretive depth, and evidence density at an expert level.
- Translate difficult saju concepts into language ordinary users can understand.
- Preserve expert terms and calculation evidence in evidence/detail areas.
- Avoid fear-based, deterministic, or exaggerated language.
- Make the app feel useful even before the AI text finishes generating.

The preferred architecture is hybrid:

1. Show calculated facts and rule-based summaries immediately.
2. Generate deep, polished interpretation text through the API.
3. Keep follow-up chat API-based.
4. Add validation over AI output so unsupported claims can be caught before display.

Current product strategy:

- Prefer one-time paid reports over a monthly subscription for the first release.
- Candidate products are `올해 운세 리포트`, `전체 사주 리포트`, `정밀 궁합 리포트`, `사주+타로 질문 리딩`, `월별 리포트`, and `질문 5개 충전`.
- `올해 운세 리포트` should include 상반기/하반기 and 1월~12월 flow, rather than selling those separately at first.
- PDF save should be bundled into paid reports, not treated as the main standalone product.
- Do not chase a 120-page PDF yet. First prove that a 20~40 page report feels useful, polished, and worth paying for.
- Before charging high prices, validate result quality, PDF quality, user willingness to pay, and whether free/paid differences are obvious.

Latest UX direction:

- Position the app as a `근거 있는 사주 상담 리포트 + 선택 판단 도구`, not a generic AI fortune generator.
- Users distrust AI saju when it gives broad lines like "신중하세요" or "변화를 준비하세요" without decision criteria.
- For serious questions, collect a little more context: concern area, current options, recent 1~3 month reality, and feared outcome.
- Use those inputs to produce: direct question answer, option comparison, uncomfortable but useful diagnosis, repeated pattern, and concrete action plan.
- Keep calculation and evidence deterministic. The counseling layer should translate and prioritize evidence, not invent new fate claims.

## Current Repository State

Repository:

- GitHub repo: `miziixx/myapps`
- App directory: `saju-tarot-chatbot`
- Current deployment target: Vercel production from `main`
- Verified git author email used for commits: `daily.zia@gmail.com`

Key commits already pushed:

- `2614d5e` Improve saju reading output clarity
- `2431ad3` Improve reading progress and visual layout
- `77a0ff3` Trigger Vercel deployment with verified email
- `1a16929` Add reading image zip export and follow-up limit
- `fe28b9a` Improve saju charts exports and yearly reading detail
- `d92697c` Clarify saju chart labels and add keyword cloud
- `26be761` Remove unsupported Anthropic assistant prefill
- `6fce368` Clarify late-night birth calculation basis
- `37580d3` Prioritize question answers and improve compatibility view
- `a8a8991` Expand compatibility analysis factors
- `374031b` Add relationship contexts to compatibility
- `d6c35d1` Clarify daily fortune and strengthen tarot readings
- `ae8c227` Port richer tarot symbolism
- `6023716` Deepen compatibility repair report
- 상담형 사주 리포트 UX 1차: 홈/입력 구조 개편, 상담형 입력 필드, 흔한 말 감지 프롬프트 추가

## Important Files

Core API and prompt:

- `api/reading.ts`
- `src/prompts/systemPrompt.ts`
- `src/lib/readingApi.ts`
- `src/store/useReadingStore.ts`

Saju calculation and evidence:

- `src/lib/saju.ts`
- `src/components/SajuFactsPanel.tsx`
- `src/components/Gauge.tsx`

Result rendering:

- `src/components/ReadingResult.tsx`
- `src/components/KeywordCloud.tsx`
- `src/components/ChatFollowUp.tsx`
- `src/components/ReadingActions.tsx`
- `src/index.css`

Export:

- `src/lib/exportMarkdown.ts`
- `src/lib/shareImage.ts`

Input:

- `src/components/BirthInfoForm.tsx`
- `src/pages/SajuPage.tsx`
- `src/pages/ComboPage.tsx`
- `src/pages/FlowPage.tsx`
- `src/pages/TodayPage.tsx`
- `src/pages/FortunePage.tsx`
- `src/pages/TarotPage.tsx`

Tests:

- `src/prompts/reading.test.ts`
- `src/components/ReadingResult.test.tsx`
- `src/lib/sajuFeatures.test.ts`

## Current Behavior

### Reading Generation

The app uses Claude through `api/reading.ts`.

- Anthropic SDK is used.
- Default model is `claude-sonnet-5` unless `READING_MODEL` is set.
- `ANTHROPIC_API_KEY` must exist in the deployment environment.
- Responses stream as NDJSON so long readings can appear progressively.

Long saju/combo readings use client-side fan-out:

- `src/lib/readingApi.ts` sends two simultaneous streaming calls for new `saju` and `combo` readings.
- Front call writes: `# 첫 점괘`, `# 질문 중심 핵심`, `# 분야별 요약`, `# 타고난 성격과 기질`, `# 직업과 돈`, `# 재물 흐름`, `# 애정과 관계`.
- Back call writes: `# 건강과 컨디션`, `# 인생의 큰 흐름`, `# 올해의 흐름`, `# 지금 해야 할 것과 피해야 할 것`, `# 마지막 점괘`.
- The UI combines front/back text in the original section order.
- Each call still uses the existing continuation logic if it hits `max_tokens` or a stream ends early.
- `sectionGroup` is only a generation instruction. The stored `userMessage`/follow-up history must not keep the front/back-only directive.
- Follow-up, compare, today, and flow calls are not fan-out by default.
- `light` depth is also not fan-out. It is treated as a fast supplement to the API-free instant summary.
- The Anthropic API call must end with a user message. Do not reintroduce assistant prefill messages for continuation.

### Follow-up Chat

Follow-up chat is limited to 5 user questions per reading.

Implemented in:

- `src/components/ChatFollowUp.tsx`
- `src/store/useReadingStore.ts`

Both UI and store-level guards exist.

### Saju Reading Output Structure

The prompt expects major readings to use these sections:

- `# 첫 점괘`
- `# 질문 중심 핵심` when the user entered a question
- `# 분야별 요약`
- `# 타고난 성격과 기질`
- `# 직업과 돈`
- `# 재물 흐름`
- `# 애정과 관계`
- `# 건강과 컨디션`
- `# 인생의 큰 흐름`
- `# 올해의 흐름`
- `# 지금 해야 할 것과 피해야 할 것`
- `# 마지막 점괘`

For most sections, the expected internal structure is:

- `[한 줄 결론]`
- `[쉬운 풀이]`
- `[왜 그렇게 보는지]`
- `[현실에서 나타나는 모습]`
- `[조심할 점]`
- `[활용 방법 / 보완 방법]`
- `[오늘 바로 할 수 있는 행동]`
- `[전문가 근거 보기]`

Expert evidence should be preserved in collapsible/detail areas, not removed.

If the user chose an interest or entered a question, answer that concern early and visibly. The preferred UI is a natural card near the top of the relevant result area, not a buried answer at the bottom.

### Counseling-Oriented Saju Input

The birth form is organized as:

- `1 기본 정보`: data needed for deterministic chart calculation.
- `2 지금 보고 싶은 것`: focus, tone, depth, question, and optional counseling context.

`ContextPicker` includes an optional expandable counseling area:

- concern area
- current situation
- options being considered
- recent 1~3 month reality
- feared outcome

These fields are optional. They do not change saju calculation. They only help the AI answer the user's actual decision more sharply.

Prompt behavior:

- If options are provided, include `[선택지 비교]`.
- If recent reality or feared outcome is provided, include `[듣기 싫어도 봐야 할 부분]`.
- Avoid standalone generic advice such as "신중하게 결정하세요", "무리하지 마세요", "변화를 준비하세요".
- Replace generic advice with concrete criteria: what to check, when to wait, which signal matters, and what action to do today/this week/this month.

### Menu Direction

- `오늘` and `운세` are merged as `오늘 운세`.
- `/today` redirects to `/fortune`.
- `흐름` is displayed as `흐름 캘린더` so users understand it is calendar-like flow information.

### Compatibility

Compatibility should work beyond romantic relationships. Supported relationship contexts include:

- 연인·배우자
- 부모·자식
- 형제·자매
- 가족
- 사장·직원
- 동료·동업자
- 친구

The `앙숙·불편한 사람` option was removed from the user-facing selector because it felt too harsh and made the relationship picker feel crowded.

The compatibility reading should include:

- Relationship summary
- Each person's saju pattern in plain language
- A `관계 보완 리포트` near the top of the result
- Why the relationship pattern happens
- Conflict escalation steps and repair methods
- Separate guidance for `나`, `상대`, and `둘이 같이`
- Real conversation scripts
- Reactions to avoid
- Day-branch/partner-palace analysis
- How each person experiences the other
- Role fit by relationship purpose
- Repeated conflict pattern
- Timing flow
- Specific improvement strategy
- Expert evidence

Do not reduce compatibility to a score. The user disliked the earlier shallow compatibility output.

Important implementation note:

- `computeCompatibility` now returns `repairReport`.
- The score calculation and saju chart calculation should remain deterministic.
- The repair report is a rule-based interpretation layer, so it does not add API cost.
- If compatibility is made deeper later, keep the same direction: practical repair guidance first, expert evidence retained separately.

### Tarot Symbolism

Tarot readings use richer symbolism imported from the sokmaeum-style approach:

- `src/lib/tarotSymbolism.ts`
- Card archetype
- Symbol keywords
- Imagery cues
- Number/stage meaning
- Suit meaning
- Relationship application
- Spread diagnostics such as upright/reversed ratio, major-card ratio, repeated suits, and start-to-last flow axis

When strengthening tarot output, preserve this evidence-rich structure.

### Yearly Flow

The user specifically requested that `올해의 흐름` cover January through December.

Current implementation:

- Monthly flow is computed for `saju`, `combo`, and `flow` readings.
- `api/reading.ts` calls `computeLuckCycles` with `includeMonthlyFlow` for these types.
- The prompt asks the model to write 1월~12월, not just grouped periods.
- `SajuFactsPanel` displays a 1월~12월 flow grid.

The monthly grid should avoid unexplained numbers. It used to translate interaction *counts* into 4 fixed
labels (`잔잔함`/`가벼운 자극`/`변화 있음`/`흔들림 큼`) repeated verbatim across every month and every
user, which read as vague/generic. It now uses `src/lib/monthFlowNarrative.ts`
(`describeMonthFlow`/`describeMonthAction`) to re-parse each month's already-computed `interactions`
strings (via `eventEngine.ts`'s `parseInteraction`/`KIND_NUANCE`/`POSITION_MEANING`, now exported) and
generate a sentence naming the actual relation type (합/충/형/파/해) and which natal pillar it touches
(일간=나 자신, 일지=배우자·가까운 관계, 월지=직업, 시지=자녀 등), so two months with the same
interaction *count* but different content now read differently. `MonthlyFlowChart.tsx`,
`SajuFactsPanel.tsx`'s monthly grid, and `ActionCalendar.tsx` all call this shared module instead of each
keeping their own copy of the bucket logic. The Y-axis 4-tier legend (`TONE_LABELS` in
`MonthlyFlowChart.tsx`) is unrelated and intentionally stays fixed — it labels chart severity levels, not
the per-month sentence. Raw ganzhi/technical evidence strings remain in tooltip/title and evidence areas
only.

`eventEngine.ts`'s "지금 움직이는 분야" (`EventForecastPanel`) had the same issue one level up: the
per-domain `activationNote` was one of only 4 fixed template sentences keyed by activation×balance. It now
appends the domain's first rule-based `natalPatternsFor` sentence (already jargon-free) to that template
so the note also reflects this person's actual ten-god pattern, not just a generic tone. Scoring
(`activation`/`benefit`/`risk`) is unchanged.

### Health Reading

Health should be written only as condition/lifestyle guidance, never diagnosis.

The prompt asks for:

- 체력 흐름
- 스트레스가 몸으로 나타나는 방식
- 생활 리듬상 취약점
- 무리하기 쉬운 패턴
- 회복에 도움이 되는 습관
- 3~5 body/condition keywords, such as 수면 리듬, 목·어깨 긴장, 소화, 체온·순환, 눈 피로, 허리·하체, 호흡·가슴 답답함

Do not write disease predictions or medical conclusions.

### Saju Facts Panel

`SajuFactsPanel` (`src/components/SajuFactsPanel.tsx`) is split into two rendering modes so the reading result page doesn't stack every calculation widget open by default:

- `SajuPillarSnapshot` (named export): renders only the four-pillar box (연주/월주/일주/시주, hanja-first with hangul as supporting text) plus the 일간 note. Always rendered in the "quick glance" zone at the top of `ReadingResult`, outside any collapsed area — never hide this specific piece; see history note below.
- `SajuFactsPanel` (default export) takes a `showPillars?: boolean = true` prop. When rendered inside `ReadingResult`'s collapsed `CalculationEvidenceZone` (`<details className="reading-evidence-zone">`, closed by default, summary "계산 근거 자세히 보기"), it's called with `showPillars={false}` to avoid rendering the pillar box twice. It still contains everything else:
  - Yin/yang and element labels per pillar
  - Ilju trait
  - Gyeokguk box
  - All available sinsal hits (name, position, gloss)
  - Five-element visual summary and bars
  - Yin-yang distribution
  - Strength gauge
  - DaYun timeline
  - 10-year yearly flow if available
  - 1월~12월 monthly flow if available
  - Collapsible calculation details

Important user corrections:

- Do not show only Hangul ganji in the main original chart. The main chart should show Hanja prominently; Hangul explanation should be secondary.
- **History note (read before touching this again):** an earlier session moved the *entire* `SajuFactsPanel` (including the pillar box) into a collapsed bottom section, and the user pushed back that it felt like content had been removed — they specifically like seeing the pillar chart immediately. That change was reverted (see `docs/record.md`, "원국·신살·월별 상단 복구"). The current split (pillar box always visible via `SajuPillarSnapshot`, everything else collapsed) is a deliberate compromise reached after that history was surfaced to the user again in a later "too many elements on the page" request — see `docs/record.md` for the corresponding entry. Do not re-collapse the pillar box without checking with the user first.

### Keyword Cloud

`KeywordCloud` appears right above the follow-up chatbot.

It shows large floating keywords derived from:

- Strongest/weakest five elements
- Strength label
- Gyeokguk
- Sinsal names
- Current year flow
- 1월~12월 monthly flow
- Section names in the AI reading
- Tarot card names for tarot/combo readings

This is intentionally visual and slightly animated.

### Exports

Markdown:

- `src/lib/exportMarkdown.ts`
- Includes calculated facts, AI reading, and follow-up chat.
- Includes name if entered.
- Includes monthly flow details when available.

Image ZIP:

- `src/lib/shareImage.ts`
- Uses `jszip`.
- Exports multiple PNG cards in a `.zip`.
- Includes basic reading info, sections, and follow-up chat.
- `jszip` is dynamically imported only when the user clicks image ZIP export, so it does not bloat the initial app bundle.

PDF:

- Uses browser print through `ReadingActions`.
- Prints visible reading content and chat.
- Actions/buttons/feedback UI are hidden by print CSS.

## Optional Name Input

The birth form supports an optional name:

- Type field: `BirthInfo.displayName?: string`
- Input in `BirthInfoForm` and `ComboPage`
- It is not required.
- It does not affect saju calculation.
- It is used in results/exports and prompt context only.

## Prompt and Style Rules

Core rule:

- Easy language does not mean less information.
- The result should feel like: "The words are easy, but the content is dense."

Avoid:

- Fear language
- Deterministic predictions
- Medical/legal/investment conclusions
- Unsupported claims
- Generic comfort statements
- Removing expert evidence

Prefer:

- 생활 언어 first
- Expert evidence in collapsible/evidence areas
- Concrete behavior advice
- "그럴 가능성이 있습니다" style for uncertain flow
- Clear but non-fatalistic judgment

Terminology translation examples:

- 용신 -> 보완하면 좋은 기운
- 기신 -> 과해지면 부담이 되는 기운
- 목 기운 -> 성장, 시작, 배움, 움직임의 에너지
- 화 기운 -> 표현, 활력, 드러남, 추진력
- 토 기운 -> 안정, 책임, 현실감, 정리
- 금 기운 -> 판단, 기준, 정리, 결단
- 수 기운 -> 생각, 감정, 휴식, 흐름
- 인성 -> 배우고 받아들이고 정리하는 힘
- 식상 -> 표현하고 만들어내고 밖으로 풀어내는 힘
- 재성 -> 돈, 현실 감각, 결과를 만드는 힘
- 관성 -> 책임, 규칙, 직장, 압박, 사회적 역할
- 비겁 -> 자기주장, 경쟁심, 독립성, 주변 사람과의 힘겨루기
- 충 -> 부딪힘, 변화, 흔들림
- 합 -> 끌림, 묶임, 관계 형성
- 형 -> 속으로 쌓이는 압박, 불편한 긴장
- 파 -> 깨짐, 어긋남, 계획 수정
- 해 -> 은근한 방해, 오해, 미묘한 불편함
- 대운 -> 10년 단위의 큰 흐름
- 세운 -> 올해 들어오는 흐름
- 월운 -> 이번 달의 분위기
- 일진 -> 오늘 하루의 흐름

## Accuracy Concerns

The user is concerned about incorrect readings.

Important distinction:

1. Calculated facts:
   - Saju chart
   - Five elements
   - Ten gods
   - Luck cycles
   - Interactions
   - Sinsal

2. AI interpretation:
   - How facts appear in real life
   - Advice
   - Tone and wording

The safest future direction is:

`calculation -> evidence data -> AI interpretation -> validation -> user display`

Recommended next improvement:

- Add an AI output validation layer.
- Detect unsupported saju terms or claims.
- Check whether claimed evidence exists in computed data.
- Re-prompt or flag output if unsupported.
- Keep user-facing disclaimers calm and clear.

## Recommended Next Implementation Steps

1. Add API-free instant reading summary:
   - Basic tendency
   - Five-element summary
   - Strength summary
   - Current year/month summary
   - Sinsal summary

2. Keep the deep AI reading streaming below the instant summary.

3. Add validation layer for AI output:
   - Unsupported terms
   - Unsupported evidence
   - Deterministic/fear language
   - High-risk advice

4. Improve feedback loop:
   - Let users mark "wrong", "too vague", "hard to understand", "good advice".
   - Use accepted feedback as `styleHint` only when user consents.

5. Continue code-splitting:
   - Current build may still warn that the main JS chunk exceeds 500kB.
   - `jszip` has already been moved to a dynamic import in `src/lib/shareImage.ts`.
   - Further wins may come from splitting tarot data, history/export tools, or heavy result-only UI.

## Verification Commands

Use these before committing:

```bash
npm test
npm run build
```

Known current build note:

- Vite warns that some chunks exceed 500kB.
- This is not a build failure.
- It became more noticeable after adding image ZIP export.

## Deployment Notes

Vercel previously blocked deployment when commit author email was invalid:

- Bad email was `ziia@airair.local`
- Correct verified email is `daily.zia@gmail.com`

Before pushing deployment-triggering commits, confirm:

```bash
git config user.email
```

Expected:

```text
daily.zia@gmail.com
```
