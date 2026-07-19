# Email 驗證 — Spec

> Phase 4 Slice C of Shared-Schedule
> 註冊後輸入信中 6 碼 OTP 完成 email 驗證；未驗證帳號不能登入。
> 順勢重構 SignIn 技術債（LoginViewModel 不再直接持 AuthClient）。

## Why

目前 `supabase/config.toml` 的 `enable_confirmations = false`，註冊即
自動確認——任何人可以拿不存在的 email 註冊成功。上架前必須擋掉：

1. **信箱所有權**：預約課程的通知、未來的密碼重設都寄 email；沒驗證
   過的信箱等於這些功能全是空談。
2. **帳號品質**：假 email 帳號會污染 user_profiles 與未來的
   discovery。

同時處理已記錄的技術債：`LoginViewModel.signIn()` 直接 `import Auth`
持 `AuthClient`（Slice A 時標記「做 SignIn Usecase 時再 refactor」）。
本 slice 新增 `emailNotConfirmed` 錯誤處理本來就要動 signIn 錯誤映
射，正是引入 `SignInUseCase` + `AuthSessionClientProtocol` 的時機。

## What

### 驗證機制（產品決策，2026-07-06 定案）

- **OTP 6 碼**：註冊後 Supabase 寄驗證信，信中含 6 位數字驗證碼，
  使用者在 app 內輸入。不走 deep link（免 URL scheme、免動 Xcode
  專案設定、整合測試可全自動）。
- **未驗證不能登入**：`enable_confirmations = true` 後 GoTrue 伺服器
  端直接擋（400 "Email not confirmed"）；app 轉為明確錯誤訊息＋
  「重寄驗證碼並前往驗證」入口。
- 驗證碼設定沿用 config 預設：`otp_length = 6`、`otp_expiry = 3600`
  （1 小時）。

### 新增的概念

- **`AuthSessionClientProtocol`**（Usecase 層 client 抽象，照
  `AuthSignUpClientProtocol` 模式）：`signIn` / `verifySignUpOTP` /
  `resendSignUpConfirmation`，typed error enums。Supabase adapter 在
  Infrastructure。
- **`SignInUseCase`**：登入走 Usecase；`LoginViewModel` 移除
  `import Auth`。
- **`VerifyEmailOTPUseCase`**：驗 6 碼格式 → `verifyOTP(.signup)` →
  session 成立後 best-effort 建 `user_profiles`（見下）。
- **`ResendVerificationCodeUseCase`**：重寄驗證信。
- **`EmailVerificationView(Model)`**：驗證碼輸入畫面。

### user_profiles 建立時機（重要變更）

`enable_confirmations = true` 後 `signUp` 不再回 session →
`CompleteSignUpUseCase` 原本「註冊當下建 profile」會失敗（RPC 需要
`auth.uid()`）。改為：

- `CompleteSignUpUseCase` 只做「註冊＋觸發驗證信」；displayName 改塞
  進 signUp metadata（`raw_user_meta_data.display_name`）伺服器留底。
- **驗證成功後**（session 已存在）由 `VerifyEmailOTPUseCase` 建
  profile。建檔失敗為**非致命**（`.signedIn` 已切畫面；email
  fallback ＋ Settings 改名可補救）→ `partialFailure` 錯誤整組移除。
- **延後驗證補救路徑**：註冊後殺 app、之後從登入錯誤入口重寄再驗證
  （記憶體已無 displayName）→ 以 `displayName: nil` 驗證、跳過建檔；
  `SupabaseAuthCurrentUserProvider` 既有 email fallback，使用者可在
  Settings 補名字。

### 使用者可以做的事（增量）

- 註冊後進入「輸入驗證碼」畫面：輸入信中 6 碼 → 自動登入進 app，
  displayName 生效。
- 驗證畫面可「重新發送驗證碼」（60 秒冷卻倒數）。
- 未驗證帳號登入 → 看到「Email 尚未驗證」錯誤＋「重寄驗證碼」按鈕
  → 前往驗證畫面完成驗證。

## 不做的事（Out of Scope）

- **Password reset / 忘記密碼** → Slice D（`docs/features/password-reset/`）
- **Deep link / Universal link 驗證**（產品決策採 OTP）
- **Email 變更的重新驗證**（`double_confirm_changes` 已開但 app 無
  改 email 功能）
- **Production SMTP / 雲端專案模板設定** → Phase 2 雲端上線時處理
  （本 slice 限 local；模板覆寫記在 api.md，雲端 dashboard 要重做
  一次）
- **supabase-swift SDK 升級**（2.5.1 → 新版 AuthError 形狀、PKCE 預
  設都會變）→ 另開 chore

## 已知風險與明文行為

- **R1 錯誤判斷靠字串比對**：SDK 2.5.1 無 `ErrorCode` enum，
  「email not confirmed」= HTTP 400 + msg 字串比對；以整合測試
  CINT2 釘住，SDK 升級時測試會抓到。
- **R7 重複註冊行為（2026-07-06 本地實證）**：與原假設不同，本地
  GoTrue **沒有**啟用 enumeration 混淆——已驗證 email 重複註冊回
  422 `user_already_exists`（既有 `.userExists` 錯誤路徑照常生效）；
  未驗證 email 在 `max_frequency` 內重複註冊回 429。雲端專案若開啟
  混淆設定行為會不同，Phase 2 上雲時重驗。
- **驗證成功後建檔的競態**：`.signedIn` 事件可能先於 profile insert
  完成 hydrate → ViewModel 於成功後呼叫
  `updateCachedDisplayName(_:)` 補快取；最壞情況該 session 顯示
  email、重啟後正確。

## Permissions

| 角色 | 可做 | 不可做 |
|---|---|---|
| Anonymous（已註冊未驗證） | `verifyOTP(type: .signup)` 換 session；`resend(type: .signup)` 重寄 | 登入（GoTrue 400 擋）；任何需要 session 的操作 |
| 驗證成功的新 user | 同一般 authenticated user；`create_user_profile` RPC 建自己的 profile | — |

權限執行位置：驗證與否為 **GoTrue 伺服器端權威**（`email_confirmed_at`）；
app 端只做 UX 映射。Usecase 層 fail-fast 預檢（6 碼格式、email 非空）
非權威。

## User Flow

### Sign-up → 驗證

```
LoginView sign-up mode 三欄填完按「註冊」
  → CompleteSignUpUseCase.completeSignUp(email, password, displayName)
    → 預檢（同 Slice A）
    → authSignUpClient.signUp(email, password, displayName→metadata)
      → 成功（無 session）→ GoTrue 寄驗證信
  → LoginViewModel.pendingVerification = (email, displayName)
  → LoginView 以 onChange 將值交給 RootView（handoff 後清回 nil）
  → RootView 以 fullScreenCover 呈現 EmailVerificationView
    （cover 掛在 auth-state Group 外層、同忘記密碼模式——成功畫面
    要活過 .signedIn 造成的 LoginView 子樹拆除；2026-07-19 UX 修訂）
    → 輸入 6 碼按「驗證」
    → VerifyEmailOTPUseCase.verify(email, code, displayName)
      → 格式檢查 ^[0-9]{6}$
      → authSessionClient.verifySignUpOTP(email, token)
        → 成功 → session 成立、.signedIn 發出
      → userProfileRepository.create(displayName)（best-effort）
    → viewModel 呼叫 updateCachedDisplayName(displayName)、isVerified = true
  → RootView 背後切 ContentView；cover 顯示成功畫面
    （checkmark＋「驗證成功」＋「開始使用」）
  → 按「開始使用」→ cover dismiss → 使用者已在 ContentView
```

### 一般登入成功（2026-07-19 二次 UX 修訂）

```
LoginView 登入成功 → LoginViewModel.didSignIn = true
  → LoginView onChange 通知 RootView
  → RootView 切 ContentView（crossfade）＋底部彈出
    「歡迎回來」toast（共用 .toast() modifier、約 1.5 秒自動消失）
  → 只有手動登入觸發；session 恢復／OTP 驗證／密碼重設不彈
    （後兩者已有各自成功畫面）
```

### 未驗證登入 → 補驗證

```
LoginView sign-in mode 輸入未驗證帳號
  → SignInUseCase.signIn(email, password)
    → authSessionClient.signIn → 400 "Email not confirmed"
    → throws SignInError.emailNotConfirmed
  → View 顯示「Email 尚未驗證」＋「重寄驗證碼」按鈕
    → 點按 → ResendVerificationCodeUseCase.resend(email)
    → pendingVerification = (email, displayName: nil)
  → EmailVerificationView（同上，跳過建檔）
  → 進 app 後 displayName fallback 為 email，Settings 可改名
```

## Scenario 總表

完整 Given/When/Then 見 `scenarios.md`。

| 代碼 | 層 | 數量 |
|---|---|---|
| SI | Usecase — SignInUseCase | 5 |
| VE | Usecase — VerifyEmailOTPUseCase | 7 |
| RV | Usecase — ResendVerificationCodeUseCase | 3 |
| UC' | Usecase — CompleteSignUpUseCase 改寫 | 5 |
| SM | Infrastructure — error mapping（純單元） | 7 |
| CINT | Infrastructure — 整合（local Supabase + Mailpit） | 4 |
| LVM-C | ViewModel — LoginViewModel 增量 | 4 |
| EVM | ViewModel — EmailVerificationViewModel | 8 |
| **合計** | | **43** |
