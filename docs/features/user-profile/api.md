# 使用者檔案 — API & DB

> Phase 4 Slice A backend contract：DB schema、RLS policy、RPC、DTO、
> error code mapping。實際 SQL 在
> `supabase/migrations/<ts>_add_user_profiles.sql` 跟
> `supabase/migrations/<ts>_extend_get_bookings_for_owner.sql`。

## DB Schema

```sql
CREATE TABLE user_profiles (
  user_id      UUID PRIMARY KEY
               REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL CHECK (
    char_length(display_name) BETWEEN 1 AND 50
  ),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 欄位設計理由

- `user_id PK` 同時 FK 到 `auth.users`：1-on-1 對應。`ON DELETE CASCADE`
  讓未來 account-deletion slice 拆 auth.users 時自動帶走 profile。
- `display_name TEXT` 不限字元集，純 length 1-50 CHECK。中日英 emoji
  混用 OK；過早 strict 反而踩到合法用戶。
- `updated_at` 為了未來 settings view 編輯用；本 slice 不寫 trigger
  自動維護 timestamp，update 流程要 client 端自行 set（settings slice
  再加 trigger 也可）。
- 不存 email：email 是 `auth.users` 的 source of truth、JOIN 取即可、
  避免 sync 問題。

## RLS

```sql
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self_select" ON user_profiles
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "self_update" ON user_profiles
  FOR UPDATE USING (user_id = auth.uid());

-- INSERT / DELETE 沒有 policy，全走 RPC
```

### 為什麼 INSERT 走 RPC 而不是直接 PostgREST + INSERT policy

- 集中 server-side validation：length 限制統一在 RPC 內、避免 client
  漏檢。
- `unique_violation` 捕捉重命名為清晰 `ALREADY_EXISTS` 錯誤碼，比依
  賴 PostgREST 回 PostgrestError 23505 對 client 更明確。
- 統一 mutation pattern：跟 `book_slot` / `cancel_booking` /
  `redeem_invitation` / `create_user_profile` 全走 SECURITY DEFINER RPC、
  audit story 一致。

### 為什麼 owner 讀別人的 displayName 不需要新 policy

owner 不直接 SELECT user_profiles——透過 `get_bookings_for_owner` RPC
（SECURITY DEFINER）內部 LEFT JOIN user_profiles，bypass RLS 拿
display_name 後一併回給 owner。直接 PostgREST `user_profiles?select=*`
仍只能撈到自己的 row、不破 self-only RLS。

## RPC：create_user_profile

```sql
create_user_profile(target_display_name TEXT)
  RETURNS TABLE(user_id UUID, display_name TEXT,
                created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ)
  SECURITY DEFINER
```

### 檢查順序（嚴格）

1. `auth.uid() IS NULL` → `RAISE EXCEPTION 'AUTH_REQUIRED'`
2. `btrim(target_display_name)` 後 length 不在 1-50 → `INVALID_DISPLAY_NAME`
3. INSERT；UNIQUE(user_id) 衝突由 plpgsql `EXCEPTION WHEN
   unique_violation` 捕捉、重 `RAISE EXCEPTION 'ALREADY_EXISTS'`

`GRANT EXECUTE TO authenticated`。

### 為什麼 RPC 收完整 displayName string 而非已驗 VO

ComputedSlot 同樣 pattern：server 不信 client，所有 invariants 都重驗
一次。Domain VO `UserProfile.init` 抓到的是「我們 client 不該送進
RPC」的 fast-fail；RPC 內的檢查是「網路上送進來的東西要再 sanity」。

## RPC：get_bookings_for_owner（v2）

Slice 1.5 既有版本 return 8 欄；Slice A 加 `student_display_name TEXT`
為第 5 欄：

```sql
get_bookings_for_owner(target_schedule_id UUID)
  RETURNS TABLE(
    id                   UUID,
    schedule_id          UUID,
    student_id           UUID,
    student_email        TEXT,
    student_display_name TEXT,        -- 新增 (Slice A)
    starts_at            TIMESTAMPTZ,
    ends_at              TIMESTAMPTZ,
    duration_seconds     INTEGER,
    created_at           TIMESTAMPTZ
  )
  SECURITY DEFINER
```

### 為什麼 DROP + CREATE

Postgres 不允許就地改 function return type。整個 function body 加一行
`LEFT JOIN user_profiles up ON up.user_id = b.student_id` + return
`up.display_name`。

### 為什麼 LEFT JOIN 而非 INNER

Profile row 不存在的學生（legacy / partial signup）仍要回 booking
row、`student_display_name` 為 NULL；client 端 fallback 到 email。

### 對既有 Slice 1.5 client 是否 backward-compatible

是。PostgREST 回 JSON、`OwnerBookingDTO` 用預設 JSONDecoder（不 strict
fail extra keys），多回一個欄位舊 client 會 silently ignore。但本 PR
裡 DTO 同步加 `studentDisplayName: String?`、不留下「未讀資料」的灰
色地帶。

## DTO

```swift
// App/Infrastructure/Supabase/DTOs/UserProfileDTO.swift
struct UserProfileDTO: Codable, Sendable {
    let userId: UUID
    let displayName: String
    let createdAt: String         // ISO 8601 from TIMESTAMPTZ
    let updatedAt: String
}

// App/Infrastructure/Supabase/DTOs/OwnerBookingDTO.swift（修改）
struct OwnerBookingDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let studentId: UUID
    let studentEmail: String
    let studentDisplayName: String?    // 新增 (Slice A) — nullable
    let startsAt: String
    let endsAt: String
    let durationSeconds: Int
    let createdAt: String
}
```

PostgrestClient 的 encoder/decoder 在 `SupabaseClientProvider` 配
`.convertToSnakeCase` / `.convertFromSnakeCase`，camelCase ↔
snake_case 自動轉換。

## Error Code Mapping

`App/Infrastructure/Supabase/Mappers/UserProfileMapper.swift`：substring
match `PostgrestError.localizedDescription`，與
`SupabaseInvitationRepository` / `SupabaseBookingRepository` 同 pattern。

| RPC 'CODE' (create_user_profile) | Domain error |
|---|---|
| `INVALID_DISPLAY_NAME` | `.invalidDisplayName` |
| `ALREADY_EXISTS` | `.alreadyExists` |
| 其他 | `.persistenceFailure` |

> Fetch path 不 throw RPC error（fetch 是純 PostgREST GET）；任何
> network / decode 失敗統一 `.persistenceFailure`，row 不存在回 `nil`
> 而非 throw。

## Seed 影響

`supabase/seed.sql` 在 3 個既有 user INSERT 各別之後加：

```sql
INSERT INTO user_profiles (user_id, display_name)
VALUES
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Test Teacher A'),
  ('b2c3d4e5-f6a7-8901-bcde-f23456789012', 'Test Teacher B'),
  ('c3d4e5f6-a7b8-9012-cdef-345678901234', 'Test Student C')
ON CONFLICT (user_id) DO NOTHING;
```

display_name 跟 `raw_user_meta_data.display_name` 對齊。`ON CONFLICT
DO NOTHING` 讓 seed 重跑 idempotent。

## 整合 / 既有測試影響

- `SupabaseIntegrationTests.swift` AuthCurrentUserProvider sub-suite 既
  有 2 條 assert `displayName == email` 必須改成 assert `displayName
  == seed display_name`（Test Teacher A / Test Teacher B）。
- Slice 1.5 BINT8 `ownerFetchAll_returnsBookingsWithStudentEmail` 改
  名 / 加 assertion 驗 `studentDisplayName == "Test Student C"`。
- 加 BINT8b 驗 partial-signup user 的 fallback 行為（`studentDisplayName
  == nil`、`studentEmail` 仍正確）。
