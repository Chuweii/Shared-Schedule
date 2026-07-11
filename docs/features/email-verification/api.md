# Email 驗證 — API & Config

> Phase 4 Slice C backend contract。本 slice **無 migration、無新
> RPC**——全部是 GoTrue 內建 endpoint ＋ `supabase/config.toml` 設定
> 變更。

## config.toml 變更

```toml
[auth.email]
enable_confirmations = true    # 原 false；未驗證帳號登入回 400

[auth.email.template.confirmation]
subject = "Shared Schedule 驗證碼"
content_path = "./supabase/templates/confirmation.html"
```

- 新檔 `supabase/templates/confirmation.html`：內容含 `{{ .Token }}`
  （6 位數字 OTP）。**必須覆寫模板**——GoTrue 預設 confirmation 信
  只有 `{{ .ConfirmationURL }}` 連結、沒有 token。
- `content_path` 基準目錄以 `supabase start` 實證為準（CLI 文件兩種
  寫法都出現過）。
- 其餘沿用預設：`otp_length = 6`、`otp_expiry = 3600`、
  `max_frequency = "1s"`（兩次寄信最小間隔）。
- config 變更需 `supabase stop && supabase start` 才生效。

### 雲端上線注意（Phase 2 / production）

- Hosted 專案的模板要在 Dashboard（Auth → Email Templates）重設一次，
  同樣把 `{{ .Token }}` 放進 Confirm signup 模板。
- 無自訂 SMTP 時 hosted 內建寄信額度極低（≈2 封/小時）——production
  前要接 SMTP provider。`[auth.rate_limit] email_sent` 僅在自訂 SMTP
  時生效。

## GoTrue endpoints（SDK 2.5.1 對應）

| 動作 | SDK 呼叫 | endpoint |
|---|---|---|
| 註冊（觸發驗證信） | `signUp(email:password:data:)` | `POST /auth/v1/signup` |
| 驗證 OTP | `verifyOTP(email:token:type: .signup)` | `POST /auth/v1/verify` |
| 重寄驗證信 | `resend(email:type: .signup)` | `POST /auth/v1/resend` |

行為重點：

- `enable_confirmations = true` 時 `signUp` 回 `AuthResponse.user`
  （**無 session**）；驗證成功的 `verifyOTP` 存 session 並發
  `.signedIn` 事件（RootView 既有 `observeAuthState` 直接吃到）。
- `signUp` 的 `data` 帶 `["display_name": .string(displayName)]` →
  `auth.users.raw_user_meta_data`，與 seed 使用者形狀一致；本 slice
  僅留底，不從 metadata 讀回。
- **已註冊 email 重複 signUp（本地實證 2026-07-06）**：已驗證 email
  → 422 `user_already_exists`（`.userAlreadyExists` 路徑照常）；未驗
  證 email 於 `max_frequency` 內重複 → 429
  `over_email_send_rate_limit`。本地 GoTrue 未啟用 enumeration 混淆；
  雲端行為 Phase 2 重驗。

## 錯誤映射（Infrastructure adapter）

`App/Infrastructure/Supabase/Auth/SupabaseAuthSessionClient.swift`。
**SDK 2.5.1 的 `AuthError.APIError` 只有 `msg: String?` +
`code: Int?`（HTTP status），沒有 ErrorCode enum** → 必須字串比對，
整合測試 CINT2/CINT3 釘住，SDK 升級時會紅。

### mapSignInError → `AuthSignInError`

| 條件 | mapped |
|---|---|
| `URLError` | `.network` |
| 400 且 msg 含 "email not confirmed"（case-insensitive） | `.emailNotConfirmed` |
| 400 其他 | `.invalidCredentials` |
| 其他 | `.generic` |

> 順序重要：先比 msg 再 fallback 到 400 → invalidCredentials。

### mapVerifyError → `VerifyOTPClientError`

| 條件 | mapped |
|---|---|
| `URLError` | `.network` |
| 401 / 403（"Token has expired or is invalid"） | `.invalidOrExpiredCode` |
| 429 | `.rateLimited` |
| 其他 | `.generic` |

### mapResendError → `ResendConfirmationError`

| 條件 | mapped |
|---|---|
| `URLError` | `.network` |
| 429 | `.rateLimited` |
| 其他 | `.generic` |

## user_profiles 建立時機變更

- 原（Slice A）：`CompleteSignUpUseCase` = signUp → `create_user_profile`
  RPC。
- 新（Slice C）：signUp 當下**無 session、RPC 必失敗** → 建檔移到
  `VerifyEmailOTPUseCase`（verifyOTP 成功、session 成立後）。
- 建檔 best-effort：`.alreadyExists`（重試 race）與其他失敗都不阻斷
  ——使用者已驗證成功、`.signedIn` 已切畫面；fallback = email 顯示
  ＋ Settings `update_user_profile` upsert RPC 補救。
- `CompleteSignUpError.partialFailure` 移除（狀態不再可能）。

## seed.sql / migrations 影響

- **無**。seed 使用者 A/B/C 直接 `email_confirmed_at = now()`，不受
  confirmations 開啟影響。

## 既有整合測試影響（與 config 翻轉同 commit 修復）

所有「runtime `signUp` 後直接以登入身分操作」的測試會壞（signUp 不
再回 session）：

| 測試 | 修法 |
|---|---|
| UserProfiles 的 `signUpFreshUser` helper（UINT1/UINT3/PINT1-3） | 改用共用 `IntegrationTestSupport.signUpFreshUserConfirmed` |
| Accounts 的 `signUpFreshUser`（AINT1） | 同上 |
| Auth-DN1（fresh user fallback） | 同上 |
| BINT8b（無 profile 學生 booking） | 同上 |

`signUpFreshUserConfirmed(prefix:)` = signUp → `MailpitClient.
waitForLatestOTP(to:)` 取碼 → `verifyOTP(.signup)` → 回 (email,
userID)，結束時為已登入狀態（與舊 helper 行為對齊）。

## Mailpit（本地測試信箱）

- CLI 已以 Mailpit 取代 Inbucket（config 區段名 `[inbucket]` 沿用舊
  名）；web UI `http://localhost:54324`。
- 測試用 REST API：
  - `GET /api/v1/search?query=to:"{email}"` → 依時間新→舊列訊息
  - `GET /api/v1/message/{ID}` → 內文（`Text` 欄位 regex `[0-9]{6}`
    取 OTP）
- helper：`Shared ScheduleTests/TestHelpers/MailpitClient.swift`，
  輪詢 timeout 預設 10 秒。
