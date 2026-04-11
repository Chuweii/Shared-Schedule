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

## 3. Local-first workflow

- `supabase start` brings up the local stack (Postgres, Auth, Storage,
  Realtime, Studio)
- Migrations live under `supabase/migrations/` (created when the first
  migration is written)
- Seed data lives in `supabase/seed.sql`
- Schema-change flow: write migration SQL → verify locally → review → push

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

- **Sign in with Apple** (App Store requires it whenever any third-party
  login is offered)
- **Email magic link** as a fallback
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
