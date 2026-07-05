# 帳號設定 — API & DB

> Phase 4 Slice B backend contract：RPC、DTO、error code mapping。
> 實際 SQL 在
> `supabase/migrations/<ts>_add_update_user_profile.sql` 跟
> `supabase/migrations/<ts>_add_delete_account.sql`。
> 本 slice **不新增 table、不改 RLS、不改 seed**——只加兩個 RPC。

## RPC：update_user_profile

```sql
update_user_profile(target_display_name TEXT)
  RETURNS TABLE(user_id UUID, display_name TEXT,
                created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ)
  SECURITY DEFINER
```

### 檢查順序（嚴格）

1. `auth.uid() IS NULL` → `RAISE EXCEPTION 'AUTH_REQUIRED'`
2. `btrim(target_display_name)` 後 length 不在 1-50 → `INVALID_DISPLAY_NAME`
3. `INSERT ... ON CONFLICT (user_id) DO UPDATE SET display_name, updated_at`
   （upsert）
4. `RETURN QUERY SELECT` 回更新後的 row

`GRANT EXECUTE TO authenticated`。

### 為什麼是 upsert 而不是純 UPDATE

legacy（Phase 4 之前）與 partial-signup（Slice A auth 成功但 profile
create 失敗）的使用者沒有 profile row。settings 編輯若用純 UPDATE 會
silently no-op。upsert 讓「第一次在 settings 設定 displayName」就補建
row，避免「先 create 再 update」兩段分支邏輯。

### 與 create_user_profile 的分工

| RPC | 使用場景 | unique 衝突行為 |
|---|---|---|
| `create_user_profile` | sign-up（要求全新 profile） | `unique_violation` → `ALREADY_EXISTS`（retry race 視為成功） |
| `update_user_profile` | settings 編輯（upsert） | `ON CONFLICT DO UPDATE`，無衝突錯誤 |

兩者並存：signup 路徑保持 create 的「全新」語意（partial-failure retry
偵測靠 `ALREADY_EXISTS`）；settings 路徑用 upsert 的「設成這個值」語意。

### updated_at 維護

upsert 時顯式 `SET updated_at = now()`。Slice A 的 `api.md` 提到「本
slice 不寫 trigger 自動維護 timestamp」——本 slice 沿用該決策，由 RPC
顯式更新即可。

## RPC：delete_account

```sql
delete_account()
  RETURNS VOID
  SECURITY DEFINER
```

### 檢查順序

1. `auth.uid() IS NULL` → `RAISE EXCEPTION 'AUTH_REQUIRED'`
2. `DELETE FROM auth.users WHERE id = auth.uid()`

`GRANT EXECUTE TO authenticated`。

### 核心技術假設

SECURITY DEFINER function 由 `postgres`（superuser，migration 的執行
role）擁有，因此以 postgres 權限執行，對 `auth.users` 有 DELETE 權限。
這是 Supabase 社群常見的 self-service delete pattern。

### 為什麼免逐表刪除 / 免 cascade audit

所有指向 `auth.users(id)` 的 FK 全為 `ON DELETE CASCADE`：

| Table | FK column | ON DELETE |
|---|---|---|
| `schedules` | `owner_id` | CASCADE |
| `memberships` | `user_id` | CASCADE |
| `bookings` | `student_id` | CASCADE |
| `user_profiles` | `user_id` | CASCADE |

刪 `auth.users` row 自動級聯清除以上全部，無需手動逐表刪除。`auth`
schema 內部（sessions / refresh_tokens / identities）亦有 CASCADE FK，
session 同步失效。

### 回退方案（若 RPC 路徑不可行）

若整合測試 AINT1 顯示 SECURITY DEFINER RPC 對 `auth.users` 的 DELETE
被拒，改用 Edge Function（`supabase/functions/delete-account/`）+
service_role 的 Admin API（`auth.admin.deleteUser`）。Domain / Usecase /
View 層不變，只換 `SupabaseAccountRepository` 的實作（改成呼叫
`functions.invoke` 而非 `rpc`）。

## DTO

`update_user_profile` 重用 Slice A 既有的 `UserProfileDTO`（return
signature 相同）：

```swift
// App/Infrastructure/Supabase/DTOs/UserProfileDTO.swift（既有，不改）
struct UserProfileDTO: Codable, Sendable {
    let userId: UUID
    let displayName: String
    let createdAt: String
    let updatedAt: String
}
```

`delete_account` 回 VOID，無 DTO。

## Error Code Mapping

### update_user_profile

`UserProfileMapper.mapUpdateError`（新；與 `mapCreateError` 同 substring
match pattern，但 update 路徑不會有 `ALREADY_EXISTS`）：

| RPC 'CODE' | Domain error |
|---|---|
| `INVALID_DISPLAY_NAME` | `.invalidDisplayName` |
| 其他 | `.persistenceFailure` |

### delete_account

`SupabaseAccountRepository` 內部 map（無共用 mapper、薄邏輯）：

| 來源 | Domain error |
|---|---|
| `URLError` | `.network` |
| `PostgrestError` 含 `AUTH_REQUIRED` | `.notAuthenticated`（兜底） |
| 其他 | `.persistenceFailure` |

## 整合 / 既有測試影響

- `SupabaseIntegrationTests.swift` 新增 profile-update（PINT1-3）與
  account-delete（AINT1-2）測試；沿用既有 `@Suite(.serialized)` +
  `requireLocalStack()` + 動態 sign-up helper。
- 無既有測試需要改寫（不動 table / RLS / seed / 既有 RPC）。
