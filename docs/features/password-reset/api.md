# 忘記密碼 — API & Config

> Phase 4 Slice D backend contract。同 Slice C：**無 migration、無新
> RPC**——GoTrue 內建 endpoint ＋ config 模板覆寫。

## config.toml 變更

```toml
[auth.email.template.recovery]
subject = "Shared Schedule 密碼重設驗證碼"
content_path = "./supabase/templates/recovery.html"
```

- 新檔 `supabase/templates/recovery.html`：內容含 `{{ .Token }}`。
  GoTrue 預設 recovery 信只有 `{{ .ConfirmationURL }}` 連結，必須
  覆寫（同 Slice C confirmation 模板，基準目錄 = 專案根、已實證）。
- 沿用：`otp_length = 6`、`otp_expiry = 3600`、`max_frequency = "1s"`。
- config 變更需 `supabase stop && supabase start`。
- 雲端上線：Dashboard 的 Reset password 模板同樣要放 `{{ .Token }}`
  （Phase 2 處理，同 Slice C 注意事項）。

## GoTrue endpoints（SDK 2.5.1 對應）

| 動作 | SDK 呼叫 | endpoint |
|---|---|---|
| 請求重設（寄驗證碼） | `resetPasswordForEmail(_:)` | `POST /auth/v1/recover` |
| 驗證 recovery OTP | `verifyOTP(email:token:type: .recovery)` | `POST /auth/v1/verify` |
| 設定新密碼 | `update(user: UserAttributes(password:))` | `PUT /auth/v1/user` |

行為重點：

- `/recover` 對**不存在的帳號回成功且不寄信**（enumeration 保護）
  ——UI 一律顯示「已寄送」。
- `verifyOTP(.recovery)` 成功即存 session 並發 **`.signedIn`**（SDK
  2.5.1 沒有 `.passwordRecovery` 事件）→ RootView 會切
  authenticated，因此重設流程的 fullScreenCover 必須掛在 RootView
  auth-state `Group` 外層，撐過切換直到第 3 步完成。
- **重寄**：SDK 2.5.1 `resend(email:type:)` 只有 `.signup` /
  `.emailChange`——recovery 的重寄 = 再呼叫一次
  `resetPasswordForEmail`（受 `max_frequency` 節流，429）。
- `update(user:)` 需要有效 session（第 2 步之後才可能）；新密碼與
  舊密碼相同 → 422 "New password should be different from the old
  password."。

## 錯誤映射（Infrastructure adapter）

`App/Infrastructure/Supabase/Auth/SupabaseAuthPasswordResetClient.swift`。
同 Slice C：SDK 2.5.1 無 ErrorCode enum，字串/狀態碼比對，DINT2/
DINT3 釘住。

### mapRequestError → `PasswordResetRequestError`

| 條件 | mapped |
|---|---|
| `URLError` | `.network` |
| 429 | `.rateLimited` |
| 其他 | `.generic` |

### mapVerifyError → `VerifyOTPClientError`（**沿用 Slice C 既有 enum**）

與 `SupabaseAuthSessionClient.mapVerifyError` 相同語意（401/403 →
`.invalidOrExpiredCode`、429 → `.rateLimited`）；直接重用該 static
mapper，不複製。

### mapUpdateError → `UpdatePasswordClientError`

| 條件 | mapped |
|---|---|
| `URLError` | `.network` |
| `apiError.weakPassword != nil` | `.weakPassword` |
| 422 且 msg 含 "different from the old password"（case-insensitive） | `.samePassword` |
| 其他 | `.generic` |

## seed.sql / migrations 影響

- **無**。DINT 測試用 `signUpFreshUserConfirmed` 動態建 user，改完
  密碼的 user 不影響 seed A/B/C。

## Mailpit

同 Slice C（`docs/features/email-verification/api.md`）：
`MailpitClient.waitForLatestOTP(to:)` 取碼。recovery 信與
confirmation 信同信箱，fresh user 流程中 recovery 是較新一封，
`waitForMessageIDs` 回新→舊排序取第一封即可（DINT1 在 signOut 後才
請求重設，此時信箱裡 confirmation 已存在——用
`waitForMessageIDs(atLeast: 2)` 確保 recovery 信已到再取最新）。
