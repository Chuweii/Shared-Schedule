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
- Write from the **user's perspective** — no API names, no ViewModel
  state, no class names (e.g. 「使用者輸入 email 並按發送」, not
  「ViewModel 呼叫 sendVerificationCode」)
- Cover both **success and failure** scenarios
- Be readable by non-engineers (PM, designer, the user themselves)

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
  a technical decision. Ask the user; never guess.

(For definitions of aggregate / invariant, see `docs/architecture.md` §3.)

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

**Plan file** = mid-conversation working draft (`~/.claude/plans/xxx.md`,
not in repo). **Feature doc** = permanent product spec (`docs/features/`,
committed, drives TDD). Stage 2 reorganizes plan content into the feature
doc format and drops discussion residue.

### File rules

- **`spec.md`**: Why / What / User Flow / Permissions / Scenarios summary
  table (link to `scenarios.md` — never inline full Gherkin). Technical
  Notes at the bottom.
- **`scenarios.md`**: canonical spec with Given / When / Then. Test
  function names MUST mirror scenario titles (grep-able both ways).
- **`api.md`** (optional, only when backend is involved): Supabase
  tables, endpoints, RLS policies, DTO shapes. See `docs/backend.md`.
- **Doc must match the plan.** If something needs to change, go back to
  plan mode — don't edit silently.

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

**Why tests before UI**: the VM's exact properties, error shapes, and
async behavior are known before the first `Text(...)` is written, so the
View can be bound correctly on day one — no placeholder rework.

**Exception**: if the feature ships with a Figma / design spec, you MAY
prototype the View early (placeholder state) to validate fidelity. The
polished final View still comes after the VM is green.

**Why TDD per scenario**: scenario titles map 1:1 to test function names,
so progress is visible in test output and grep works both ways.

---

## Collaboration rules

- If the **backend API exists**, the user provides it. If not, use
  **mock data** until the real API lands.
- When in doubt, **ask the user** — never guess product behavior.
- **Spec / scenarios stay free of technical detail** — that belongs in
  the plan, the code, the test names, and `api.md`.

---

## Requirement changes during implementation

When the user requests a change that differs from the approved plan or
existing scenarios, follow this **strict order**:

1. **Docs first.** Check `spec.md` and `scenarios.md` — update or add
   scenarios to reflect the new requirement. Commit the doc change
   before writing any code.
2. **Tests second.** Write or update `@Test` functions to match the
   updated scenarios. Run tests — they should **fail** (red) because
   the production code still implements the old behavior.
3. **Implementation last.** Write the minimum production code to make
   the new tests pass (green). Fix any regressions in existing tests.

**Never** skip step 1. If the docs don't reflect what the code does,
future sessions will plan against outdated specs. The doc is the source
of truth; the code follows the doc, not the other way around.

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
