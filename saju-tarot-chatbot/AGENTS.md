# AGENTS.md

This is the required startup routine for Codex and other coding agents working on `saju-tarot-chatbot`.

## Startup Routine

At the beginning of every new agent session in this app, read these files before planning or editing:

1. `CLAUDE.md`
2. `docs/record.md`
3. `docs/next_steps.md`

Then follow the relevant validation guide before touching sensitive areas:

- Saju calculation, lunar/solar conversion, birth-time handling, luck cycles, evidence data:
  - `docs/validation/saju-calculation-validation.md`
- Prompts, reading structure, follow-up chat, evidence display, safety wording:
  - `docs/validation/reading-quality-validation.md`

## Memory Update Rule

When meaningful work is completed, update the project memory:

- Add completed decisions and implementation notes to `docs/record.md`.
- Add or revise future work in `docs/next_steps.md`.
- Keep `CLAUDE.md` updated when agent behavior, architecture, or high-level product direction changes.

## Safety Rule

Do not change saju calculation logic, source birth data structures, or evidence serialization just to improve UI wording. UI/prompt changes should preserve calculation behavior and expert evidence.

## Git Rule

Only commit files that belong to `saju-tarot-chatbot`. Ignore unrelated dirty files in sibling apps unless the user explicitly asks to work on them.
