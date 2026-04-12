# CLAUDE.md — Shared-Schedule

> Authoritative project guide for Claude Code (and humans) on Shared-Schedule.
> Read this file at the start of every session. When this file conflicts with
> older code or older docs, **this file wins**.

---

## 1. Project Snapshot

**Shared-Schedule** is an iOS app that lets independent teachers (fitness
coaches, music tutors, private tutors) publish their availability so students
can self-book lessons.

| | |
|---|---|
| **Goal** | Ship to the App Store. Quality bar is store-ready, not weekend prototype. |
| **Tech stack** | SwiftUI · Swift Testing · Supabase |
| **Deployment target** | iOS 26.0 (modern APIs like `@Observable`, Swift Testing, String Catalogs are all in scope) |
| **Localization** | zh-Hant (default) + en + ja |
| **Current stage** | Foundation. Color/theme design system complete. No business logic, no backend, no tests yet. |

**Roadmap — product scope** (known but mostly unimplemented — Domain
modeling and Supabase schema should leave room for these):

- **MVP**: teacher-owned schedules with availability rules and calendar
  view, invite links, student self-booking, read-only visibility of
  other students' booked slots (time only, no PII)
- **Mid-term**: comments on bookings / schedules, schedule import, friends
- **Long-term**: course discovery, teacher discovery

**Roadmap — development phases** (order in which we actually build):

1. **Phase 1 — Mock MVP features.** Build MVP features end-to-end
   against in-memory repositories and a fake `CurrentUserProvider`. No
   Supabase, no auth. Goal: prove the workflow and stabilize Domain
   design before investing in backend integration.
   - Feature 1: Schedule aggregate + manual AvailabilityWindow ✅
   - Feature 2: AvailabilityRule + monthly calendar view ← current
   - (additional mock features as needed before Phase 2)
2. **Phase 2 — Backend + Auth integration.** User does Supabase project
   setup and hands over keys. Claude writes `supabase init`, the first
   migration + RLS for `schedules`, `SupabaseScheduleRepository`,
   `SupabaseAuthCurrentUserProvider`, and a login flow (Sign in with Apple
   first, then Google, then Facebook — all via Supabase Auth). Feature 1
   is migrated from mock to real (swap two Infrastructure classes, no
   Domain/ViewModel/test changes).
3. **Phase 3 — Remaining MVP features on real backend.** Invitation /
   Membership → Student booking → visibility of other students' booked
   slots. Every new feature lives on real Supabase + real auth + real
   RLS from day one, no mock-to-real migrations.
4. **Phase 4 — App Store readiness.** Run through `docs/conventions.md`
   §7 checklist, write privacy manifest, ship.

---

## 2. How to Use This Document

Every session, Claude MUST:

1. Read this entire file
2. Read §4 Golden Rules — they override anything else
3. When a task matches the routing table in §3, `Read` the relevant
   `docs/*.md` file **before** writing code
4. Scan §6 DO NOT before committing or refactoring

`docs/*.md` files are **not** auto-imported (no `@import`). They are loaded
on demand via the `Read` tool to keep the context budget tight.

**Voice convention**

- `MUST` / `NEVER` / `ALWAYS` — hard rules. Breaking them blocks review.
- `SHOULD` / `PREFER` — strong defaults; deviation needs justification.

---

## 3. Routing Table — "I want to do X → read Y"

| Task | Required reading |
|---|---|
| Start a new feature (any size) | `docs/workflow.md` |
| Understand DDD layering, MVVM, directory structure | `docs/architecture.md` |
| Write any test (Domain, Usecase, Infrastructure, ViewModel) | `docs/testing.md` |
| Touch backend / Supabase / RLS / migrations | `docs/backend.md` |
| File naming, commits, color usage, App Store checklist | `docs/conventions.md` |

Project layout at a glance:

```
Shared-Schedule/
├── App/
│   ├── Domain/             pure Swift, framework-free
│   ├── Usecase/            application layer
│   ├── Infrastructure/     (to be created) Supabase, Keychain, etc.
│   ├── Presentation/       SwiftUI Views + ViewModels
│   └── Resources/          design system, localizations
├── Shared ScheduleTests/   mirrors App/ structure
├── supabase/               (to be created) migrations, seed, functions
├── docs/                   project guides (this file + the routing table)
│   └── features/           per-feature spec / scenarios / api (Chinese)
└── CLAUDE.md               you are here
```

---

## 4. Golden Rules

These rules MUST be satisfied on every change. Each is intentionally short —
the docs in §3 explain *how*.

0. **MUST** enter plan mode immediately upon receiving a feature request by
   calling the `EnterPlanMode` tool. **NEVER** write production code, feature
   docs, migrations, or any project files until the user has explicitly
   approved the plan and Claude has exited via `ExitPlanMode`. Action phrases
   like 「開始寫」 / 「動手」 / "go ahead" are NOT implicit approval — if in
   doubt, ask. See `docs/workflow.md`.

1. **MUST** follow DDD layering: `Domain → Usecase → Infrastructure →
   Presentation`. The Domain layer is framework-free — no `import SwiftUI`,
   no `import Combine`, no `import Supabase`. See `docs/architecture.md`.

2. **MUST** put Repository protocols in `Domain/` and implementations in
   `Infrastructure/` (dependency inversion). DTOs (Supabase response shapes)
   stay inside Infrastructure; map DTO ↔ Domain at the boundary.

3. **MUST** use the Swift `@Observable` macro for new ViewModels.
   **NEVER** use `ObservableObject` + `@Published` in new code.

4. **MUST** use **Swift Testing** (`import Testing`, `@Test`, `#expect`) for
   all new tests, in **Given / When / Then** BDD style. **NEVER** use XCTest.
   See `docs/testing.md`.

5. **MUST** test-first (TDD red → green → refactor) for Domain, Usecase,
   Infrastructure, and ViewModel logic. **Build the SwiftUI View *after*
   the ViewModel is test-green**, not before; pure layout work (view
   composition, `#Preview`, styling, local `@State`) does not require
   tests. See `docs/workflow.md` Stage 3.

6. **MUST** wrap `SupabaseClient` inside `App/Infrastructure/Supabase/`.
   The `Supabase` import must not appear anywhere else in the codebase.
   See `docs/backend.md`.

7. **MUST** always go through `SemanticColor`. **NEVER** reference primitive
   colors (`Color.gray700`, etc.) directly from a `View`.

8. **MUST** prefix commits with `feature` / `fix` / `chore` / `refactor` /
   `test` / `docs`. **NEVER** `--no-verify`. **NEVER** force-push to `main`.
   **NEVER** create a commit unless the user has explicitly asked.

9. **MAY** add new Swift source files (`.swift`) to the Xcode project as
   part of feature work — creating them inside appropriate targets is
   fine. **NEVER** add a Swift package dependency, change build settings,
   modify deployment target, modify signing / capabilities, edit resource
   build phases, or touch secrets without explicit user approval. When
   uncertain whether a change counts as "adding a source file" vs
   "editing project settings", **ask first**.

10. **NEVER** "match the surrounding style" if that style violates these
    rules. Flag the inconsistency to the user instead.

---

## 5. Working Languages

| Artifact | Language |
|---|---|
| `CLAUDE.md` and everything under `docs/` (architecture / testing / backend / conventions / workflow) | **English** |
| Feature docs under `docs/features/<feature-name>/` (`spec.md`, `scenarios.md`, `api.md`) | **Traditional Chinese (zh-Hant)** |
| Plan files under `~/.claude/plans/` | **Traditional Chinese (zh-Hant)** |
| In-conversation discussion with the user | **Traditional Chinese (zh-Hant)** |
| User-facing strings in the app | **zh-Hant (default) + en + ja** via String Catalog |
| Code identifiers, comments, commit messages | **English** |

---

## 6. ❌ DO NOT (consolidated blacklist)

- ❌ Write any file before the user has approved the plan via `ExitPlanMode`
- ❌ `import SwiftUI` / `import Combine` / `import Supabase` inside `App/Domain/`
- ❌ Reference a Repository directly from a ViewModel (must go through Usecase)
- ❌ Let a Supabase DTO type leak out of `App/Infrastructure/`
- ❌ New `ObservableObject` + `@Published` ViewModels
- ❌ XCTest classes — Swift Testing only
- ❌ Tests without Given / When / Then structure (in both name and body)
- ❌ Reference primitive colors directly from a `View`
- ❌ Hard-coded user-facing strings — must go through String Catalog
- ❌ Add a Swift package dependency, change build settings, deployment
  target, signing / capabilities, resource build phases, or commit
  secrets without explicit user approval
- ❌ Add files *other than* Swift source files (`.swift`) to an Xcode
  target without asking — images, JSON, plists, markdown, etc. all
  need user approval
- ❌ "Matching surrounding style" when that style violates the Golden Rules
- ❌ Refactoring code unrelated to the user's request
- ❌ Inventing helpers / abstractions / configuration that weren't asked for
- ❌ `--no-verify`; force-push to `main`; commit without user approval
