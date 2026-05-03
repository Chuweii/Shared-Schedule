# Backend — Supabase

> Loaded by Claude when touching Supabase, writing migrations, designing
> RLS, integrating the Swift SDK, or handling secrets. See `CLAUDE.md` §3
> routing.

---

## 1. Integration Status

> **Current status: `Local dev`**
>
> Update this badge as the integration progresses:
> `Not started` → `Local dev` → `Staging` → `Production`.
>
> What "Local dev" means here: `supabase start` stack is the source of
> truth; `Debug.xcconfig` points at it; integration tests exercise it.
> No cloud project exists yet.

---

## 2. Division of Labor

### What Claude can do end-to-end

- Design table schemas and write SQL migrations
- Author Row Level Security (RLS) policies
- Write Edge Functions (Deno / TypeScript)
- Integrate `supabase-swift` and wrap it inside `App/Infrastructure/Supabase/`
- Design auth flows (currently email + password — see §6)
- Write seed data and run the local Supabase stack to verify migrations

### What the human owner must do (one-time)

1. Sign up at [supabase.com](https://supabase.com) and create the project
   (requires real email + password)
2. Copy **Project URL**, **anon key**, and **service role key** from the
   dashboard and hand them to Claude
3. Install the CLI: `brew install supabase/tap/supabase`, then run
   `supabase login` once
4. Final review and `supabase db push` for any migration touching
   production data

---

## 3. Environment separation

Three environments, each with its own Supabase instance:

| Environment | What it connects to | Purpose |
|---|---|---|
| **Local** | `supabase start` on your Mac (`localhost:54321`) | Daily development + TDD integration tests |
| **Staging** | Cloud project 1 (`xxx-staging.supabase.co`) | Cross-device testing, demos, CI |
| **Production** | Cloud project 2 (`xxx-prod.supabase.co`) | App Store release, real users |

### How the app switches environments

Xcode build configurations + `.xcconfig` files. Three configs live under
`Config/` at the repo root:

| File | Status | Wired to build config | Values |
|---|---|---|---|
| `Config/Debug.xcconfig` | Committed | `Debug` | Local stack — `http://127.0.0.1:54321` + publishable key |
| `Config/Staging.xcconfig` | Committed | _not yet wired_ | Placeholder; fill in when the staging cloud project exists, then add a `Staging` build configuration that points at this file |
| `Config/Release.xcconfig` | Committed | `Release` | Placeholder; fill in before App Store submission |

xcconfig defines `SUPABASE_URL` and `SUPABASE_ANON_KEY` build settings.
`Info.plist` (at repo root) has matching `$(SUPABASE_URL)` /
`$(SUPABASE_ANON_KEY)` substitutions, so each build configuration's
values land in the produced `Info.plist`. The merge keeps Xcode's
`GENERATE_INFOPLIST_FILE = YES` auto-generated bundle keys.

`SupabaseClientProvider` reads the values from
`Bundle.main.object(forInfoDictionaryKey:)` and `fatalError`s loudly if
either key is missing or still contains `PLACEHOLDER` — so an accidental
Release archive against an unconfigured `Release.xcconfig` will fail at
launch instead of pointing at the wrong host.

Anon (publishable) keys are designed to be public; RLS policies enforce
all access. **Service role keys must NEVER appear in xcconfig** — they
live only on the developer machine and inside Edge Functions.

xcconfig comment quirk: `//` is the comment marker, so URLs need an
empty-expansion `$()` between the slashes — `http:/$()/host` evaluates
to `http://host`. `http:$()//host` does NOT work.

### Which tests connect to what

| Test layer | Connects to | Why |
|---|---|---|
| Domain / UseCase / VM tests | **Nothing** — `InMemoryScheduleRepository` | Pure logic, no I/O. These 66+ tests stay fast and offline forever. |
| Infrastructure integration tests | **Local stack** (`supabase start`) | Verify migrations, RLS policies, DTO mapping against real Postgres. |
| UI manual testing / demo | **Staging** (cloud) | Persistent data, multi-device, shareable with reviewers. |

### Setup timeline

**Now (one-time, before Phase 2):**
1. Install Docker Desktop (local stack needs it)
2. `brew install supabase/tap/supabase`
3. `supabase login`
4. Create Supabase account + **staging** project → hand over keys
5. Add `supabase-swift` package in Xcode

**Later (before App Store submission):**
6. Create **production** project → hand over keys
7. Review + `supabase db push` to production

### Local-first workflow

- `supabase start` brings up the full local stack (Postgres, Auth,
  Storage, Realtime, Studio dashboard at `localhost:54323`)
- `supabase db reset` wipes and re-runs all migrations + seed data
- Migrations live under `supabase/migrations/`
- Seed data lives in `supabase/seed.sql`
- Schema-change flow: write migration → verify locally → review →
  push to staging → verify → push to production

---

## 4. Swift integration rules

- Use the `supabase-swift` package
- Wrap `SupabaseClient` inside `App/Infrastructure/Supabase/`
- The `Supabase` import **must not appear** anywhere outside
  `App/Infrastructure/`
- Repository implementations live in
  `App/Infrastructure/Supabase/Repositories/`
- DTOs (Codable structs matching Supabase response shapes) live in
  `App/Infrastructure/Supabase/DTOs/`
- Mappers (DTO ↔ Domain) live in `App/Infrastructure/Supabase/Mappers/`

---

## 5. Secrets

- **Project URL + anon key** → `Secrets.xcconfig` (gitignored, loaded at
  build time)
- **Service role key** → **never** bundled in the app; lives only on the
  developer machine and inside Edge Functions
- Add `Secrets.xcconfig` to `.gitignore` **before** committing it

---

## 6. Auth

### Current state — email + password only

The app currently uses **Supabase Auth's email + password provider**
exclusively (`AuthClient.signIn(email:password:)` /
`signUp(email:password:)`). Implemented in
`App/Presentation/Auth/LoginView.swift` and `LoginViewModel.swift`,
gated by `RootView`.

This is App Store compliant on its own (rule 4.8 only kicks in once
*any* third-party social login is offered).

### Deferred — social logins

The original plan called for Sign in with Apple → Google → Facebook in
that order. All three are **deferred**. Add them only when one of these
triggers:

- A real user-acquisition need surfaces (e.g. friction at sign-up
  becomes measurable)
- An existing user requests OAuth login from a specific provider
- Phase 4 (App Store readiness) — re-evaluate once the MVP is shipping

If/when re-introducing social logins, the order is non-negotiable
because of App Store rule 4.8: **Sign in with Apple must be added
before, or at the same time as, Google or Facebook.** Adding Google
without Apple = guaranteed rejection.

When that day comes:
- **Apple** uses `ASAuthorizationAppleIDProvider` + `signInWithIdToken`
  on `AuthClient`. Requires Apple Developer team configuration (Service
  ID + key in dev portal) and the "Sign in with Apple" capability on
  the app target.
- **Google** uses `signInWithOAuth(provider: .google)` — needs the
  Google client ID configured in the Supabase dashboard and a reverse
  client ID URL scheme in `Info.plist`.
- **Facebook** — same OAuth pattern via Supabase. Meta's app review can
  take weeks; allow lead time before any submission deadline.

Email + password should be retained alongside any social login for two
reasons: (a) it is the only path that works in CI / UI tests without a
real Apple ID, and (b) some users prefer it.

### Identity model (unchanged)

All auth providers (current and future) go through **Supabase Auth** —
the app never handles tokens or OAuth flows directly. Identity is
per-user, but role (teacher / student) is **per-Membership**, not
stored on the auth user. See `docs/architecture.md` §3.

---

## 7. RLS principles

- A teacher can read/write only their own `Schedule` rows
- A student can read `Schedule` rows for which they hold an active
  `Membership`
- `Booking` visibility:
  - **Own bookings**: always visible
  - **Other students' bookings**: time slot only — **no name, no email,
    no PII**
- All write paths must go through RLS-enforced policies
- **Service role usage from the app is forbidden.** If a flow needs
  elevated privileges, route it through an Edge Function.

---

## 8. Per-feature backend docs

When a feature touches the backend, create a Chinese-language
`docs/features/<feature-name>/api.md` describing:

- 涉及的資料表 / migration 檔
- API endpoints / RPC functions / Edge Functions
- Request / response shape (DTO 對應到哪些 Domain 型別)
- RLS policy 設計
- 需要的 seed data

This file is the source of truth for backend work on that feature, and
its scenarios should be cross-referenced from `scenarios.md`.
