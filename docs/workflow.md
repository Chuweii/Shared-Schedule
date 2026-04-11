# Spec-Driven Development Workflow

> Loaded by Claude when starting a new feature, translating a spec, or
> implementing from a description / Figma. See `CLAUDE.md` §3 routing.
>
> **Critical**: feature docs (`spec.md`, `scenarios.md`, `api.md`) and plan
> files are written in **Traditional Chinese (zh-Hant)**. This document
> itself is in English; the *artifacts it tells you to produce* are in
> Chinese.

---

## 0. Rule

New features MUST follow this three-stage flow:

```
Stage 1 — Plan (inside plan mode)
Stage 2 — Feature Doc (Chinese)
Stage 3 — TDD Implementation (UI first, then test-first logic)
```

Skipping stages — especially jumping from a feature request straight to
writing code — is **not allowed**.

---

## Stage 1 — Plan (inside plan mode)

The moment Claude receives a feature request (a text description, a Figma
link, or 「幫我做 X」 / 「我想加 Y」), it MUST **immediately call the
`EnterPlanMode` tool** before doing anything else. No file writes, no edits,
no production code, **no feature docs**, until the plan is approved via
`ExitPlanMode`.

Plan mode is non-negotiable for two reasons:

- The harness physically blocks edits while in plan mode, so the workflow
  cannot be skipped by accident.
- Plan mode forces a structured, reviewable artifact instead of ad-hoc
  drafting.

Inside plan mode, Claude does all of the following before exiting:

### 1a. Draft the spec (Given / When / Then)

The plan file is written in **Traditional Chinese**. Use **Given / When /
Then** (Gherkin-style) for every scenario.

- Give every scenario a unique, descriptive title
- Write from the **user's perspective** — no API names, no ViewModel state,
  no class names
- Cover both **success and failure** scenarios
- Be readable by non-engineers (PM, designer, the user themselves)

```gherkin
Scenario: 學生輸入有效 email 並成功收到驗證碼
  Given 學生在 email 驗證頁
  When 輸入「test@test.com」並按「發送驗證碼」
  Then 顯示「驗證碼已寄出」toast
  And 驗證碼輸入欄位變為可填寫狀態
```

❌ Don't:

```gherkin
# 洩漏技術細節
Scenario: AuthRepository.sendVerificationCode 回傳 403
  When ViewModel 呼叫 sendVerificationCode
  Then verifyEmailError 被設為 .registeredEmail
```

### 1b. Map each scenario to its implementation

For every scenario above, the plan MUST include:

- Which files will be created or changed (path level)
- Which Repository method / Supabase table / Edge Function the scenario
  hits — or「mock data — backend not ready」
- Which test case the scenario produces
- Any open questions blocking implementation

### 1c. Propose phasing (if scope is large)

If the feature touches more than ~6 scenarios or multiple screens, propose
a phased breakdown (Phase 1 / Phase 2 / …) inside the plan and ask the
user which phase to commit to first.

### 1d. Submit via `ExitPlanMode`

Submit the **whole package** — spec + scenario→implementation mapping +
open questions + phasing — for user approval in one shot. Do not partially
exit plan mode to start writing code.

### 1e. Exit criteria

Claude MUST NOT call `ExitPlanMode` until the user has **explicitly
approved** the plan. Action phrases like 「開始寫吧」 / 「寫文件」 / 「動手」
are NOT implicit approval — if in doubt, ask.

---

## Stage 2 — Feature Doc (Chinese)

Only after the plan is approved may Claude write project files. The first
thing written is the feature doc, under `docs/features/<feature-name>/`.
Folder name is **kebab-case English** (e.g. `booking-flow/`,
`teacher-onboarding/`); file *contents* are **Traditional Chinese**.

```
docs/features/<feature-name>/
├── spec.md         Why / What / User Flow / Permissions / Scenarios summary
├── scenarios.md    完整 Given/When/Then scenarios（從 plan file 搬進來並重整）
└── api.md          (optional) backend 設計：tables / endpoints / RLS / DTOs
```

### Plan file vs feature doc

- **Plan file** (`~/.claude/plans/xxx.md`) is a **mid-conversation working
  draft**. Random name, lives in your home directory, not in the repo.
  Contains discussion artifacts: open questions, alternatives considered,
  rejected ideas. Lifespan = the plan-mode conversation.
- **Feature doc** (`docs/features/<name>/`) is the **permanent product
  spec**. Lives in the repo, gets committed, is read by future sessions
  and human reviewers, drives TDD test names.

> **Plan file is a whiteboard. Feature doc is the meeting notes.**

In Stage 2, take the relevant content from the plan file, **reorganize**
it into the feature doc format, and drop the discussion residue. Once the
feature doc exists, the plan file's job is done.

### `spec.md` rules

- Sections: **Why / What / User Flow / Permissions / Scenarios 摘要**
- Scenarios section is a **summary table** linking to `scenarios.md` —
  never inline the full Gherkin (it bloats the file)
- Technical Notes (gotchas, decisions, links to external systems) live at
  the bottom

### `scenarios.md` rules

- The canonical spec. Every scenario has a unique title and Given / When /
  Then body.
- **Test function names MUST mirror scenario titles** so a reader can grep
  from doc to test in either direction.
- This is the file TDD reads from in Stage 3.

### `api.md` rules (only when backend is involved)

- 涉及的 Supabase 資料表 / migration 檔
- API endpoints / RPC functions / Edge Functions
- Request / response shape (DTO 對應到哪些 Domain 型別)
- RLS policy 設計
- See `docs/backend.md` for general Supabase rules.

### Doc must match the plan

The doc content must match the plan that was approved. If something needs
to change, **go back to plan mode** — don't edit silently.

---

## Stage 3 — TDD Implementation

Implement **one screen at a time, end-to-end**. Do not pre-build shared
components for screens you haven't reached yet.

For each screen:

1. **UI first** — build the SwiftUI `View` with placeholder state, so the
   user can sanity-check the visuals immediately. Use `#Preview` heavily.
2. **Then TDD the ViewModel** (and Domain / Usecase code it depends on):
   - **Red**: write the failing test for one scenario from `scenarios.md`
     (see `docs/testing.md` for the exact format)
   - **Green**: write the minimum code to pass
   - **Refactor**: clean up while tests stay green
3. Move to the next scenario. Repeat until the screen is complete.
4. Move to the next screen.

**Why UI first**: the user can sanity-check the design without waiting for
logic. **Why TDD per scenario**: scenario titles map 1:1 to test names, so
progress is visible in the test output.

---

## Collaboration rules

- **The user opens the new module / file ahead of time** if needed and
  tells Claude the path.
- If the **backend API exists**, the user provides the shape. If not,
  Claude implements and tests against **mock data** until the real API
  lands.
- When in doubt, **ask the user** — never guess product behavior.
- **Spec / scenarios stay free of technical detail.** Technical detail
  belongs in the plan, the code, the test names, and `api.md`.

---

## Quick checklist before writing any production code

- [ ] Called `EnterPlanMode` the moment the feature request arrived
- [ ] Spec drafted in plan file (Chinese, Given/When/Then)
- [ ] Each scenario mapped to files / API / test cases
- [ ] Phasing proposed if scope is large
- [ ] Plan **explicitly approved** by the user via `ExitPlanMode`
- [ ] Feature doc (`spec.md` + `scenarios.md` [+ `api.md`]) written in
      Chinese under `docs/features/<feature-name>/`, matches the plan
- [ ] First failing test is in place

If any box is unchecked, **stop and go back**.
