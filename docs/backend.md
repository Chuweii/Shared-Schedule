# Backend — Supabase

> Loaded by Claude when touching Supabase, writing migrations, designing
> RLS, integrating the Swift SDK, or handling secrets. See `CLAUDE.md` §3
> routing.

---

## 1. Integration Status

> **Current status: `Not started`**
>
> Update this badge as the integration progresses:
> `Not started` → `Local dev` → `Staging` → `Production`.

---

## 2. Division of Labor

### What Claude can do end-to-end

- Design table schemas and write SQL migrations
- Author Row Level Security (RLS) policies
- Write Edge Functions (Deno / TypeScript)
- Integrate `supabase-swift` and wrap it inside `App/Infrastructure/Supabase/`
- Design auth flows (Sign in with Apple, email magic link)
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

Xcode build configurations + `.xcconfig` files:

```
// Debug.xcconfig (local dev — gitignored)
SUPABASE_URL = http://localhost:54321
SUPABASE_ANON_KEY = local-anon-key

// Staging.xcconfig (gitignored)
SUPABASE_URL = https://xxx-staging.supabase.co
SUPABASE_ANON_KEY = staging-anon-key

// Release.xcconfig (gitignored)
SUPABASE_URL = https://xxx-prod.supabase.co
SUPABASE_ANON_KEY = prod-anon-key
```

App reads `Bundle.main.infoDictionary["SUPABASE_URL"]` at runtime.
**Production keys never appear in development or test flows.**

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

- **Sign in with Apple** (first — App Store requires it when offering
  any third-party login)
- **Google Sign-in** (second — Supabase OAuth built-in)
- **Facebook Sign-in** (third — Meta review process can be slow, do
  last)
- All three go through **Supabase Auth** — the app never handles
  tokens or OAuth flows directly.
- Identity is per-user, but role (teacher / student) is
  **per-Membership**, not stored on the auth user. See
  `docs/architecture.md` §3.

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
