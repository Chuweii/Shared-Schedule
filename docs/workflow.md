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
Stage 3 — TDD Implementation (tests first, then polished UI)
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

For every scenario above, the plan MUST cover **three groups** of
questions. Missing any group is a reason to stay in plan mode.

#### Domain modeling

This is where the feature's business rules are pinned down. Don't skip it
— Domain is grown just-in-time per feature, so the plan is the place
every new piece of the Domain first gets designed.

- **Aggregate**: which aggregate does this scenario live in? Is it a new
  aggregate or an extension of an existing one?
- **Root + internals**: what is the aggregate root, and which Entities /
  Value Objects live inside it?
- **Invariants**: what rules MUST always be true for this aggregate to
  be in a valid state? (e.g. 「同一 Schedule 的 AvailabilityWindow 不能
  重疊」, 「只有 owner 可以修改」.) Every invariant typically becomes
  one success scenario **and** one failure scenario.
- **Open product questions**: anything that is a business decision, not
  a technical decision — minimum durations, cross-midnight behavior,
  edge cases. Ask the user; never guess.

> **Glossary (short form — full explanation lives in `docs/architecture.md`)**
> - *Aggregate*: a cluster of Domain objects that change together, with
>   one **root** as the only legal entry point. External code never
>   bypasses the root to touch internals.
> - *Invariant*: a rule that MUST always hold after any operation on the
>   aggregate. The root's methods exist to enforce these rules.

#### Files & boundaries

- Which files will be created or changed (path level), split by layer
  (`Domain/` / `Usecase/` / `Infrastructure/` / `Presentation/`)
- Which Usecase(s) orchestrate the scenario
- Which ViewModel owns the screen state and intent handling

#### Data flow

- Which Repository method / Supabase table / Edge Function the scenario
  hits — or「mock data — backend not ready」(see `docs/backend.md`)
- Which test case the scenario produces (test function name mirrors
  scenario title; see `docs/testing.md`)
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

Implement **one feature slice at a time, end-to-end**. A slice is
Domain → Usecase → ViewModel → View. Do not pre-build shared components
for slices you haven't reached yet.

For each slice, the **strict order** is:

1. **TDD the Domain** (if the slice introduces new aggregate behavior):
   - **Red**: write the failing test for one scenario from `scenarios.md`
     (see `docs/testing.md` for the exact format)
   - **Green**: write the minimum code to pass
   - **Refactor**: clean up while tests stay green
2. **TDD the Usecase** (same red → green → refactor rhythm, one scenario
   at a time)
3. **TDD the ViewModel** (same rhythm). Every scenario in `scenarios.md`
   maps 1:1 to a `@Test` function name.
4. **Build the polished SwiftUI `View`** against the now-stable
   ViewModel state. Use `#Preview` heavily. Because the VM is green, the
   View can be final-quality on first pass — no placeholder bindings,
   no guessed state shapes, no rework when logic lands.
5. **Run the app end-to-end** in the simulator to sanity-check visuals
   and interactions against the approved spec.
6. Move to the next slice.

**Why tests before UI**: designing UI against a real, stable ViewModel
state produces higher-polish first passes than designing against
placeholder data. The VM's exact properties, error shapes, and async
behavior are known before the first `Text(...)` is written, so the View
can be bound correctly on day one.

**Exception — with a design reference**: if the feature ships with a
Figma / Sketch / design spec, you MAY prototype the View early (with
placeholder state) to validate the design against the spec before
starting TDD. The polished final View still comes after the VM is
green. For **design-free greenfield features** (the default in this
repo today), no early UI prototyping — go straight to Domain TDD.

**Why TDD per scenario**: scenario titles in `scenarios.md` map 1:1 to
test function names, so progress is visible in the test output and any
reader can grep from doc to test in either direction.

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
