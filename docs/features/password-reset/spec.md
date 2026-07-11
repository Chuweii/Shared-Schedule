# 忘記密碼 — Spec

> Phase 4 Slice D of Shared-Schedule
> 登入頁「忘記密碼？」入口 → app 內三步（email → 信中 6 碼 → 新密
> 碼）完成重設並直接進入 app。

## Why

email + password 是本 app 唯一登入方式（social login 全數 deferred，
見 `docs/backend.md` §6）。忘記密碼沒有逃生門 = 帳號永久鎖死，只能
走刪帳號重註冊——上架前必須補上。Slice C 已鋪好 OTP 基礎建設
（Mailpit 測試信箱、模板覆寫、`verifyOTP` adapter 模式、OTP 輸入
UX），本 slice 直接沿用同一套機制。

## What

### 產品決策（2026-07-06 定案）

- **App 內三步 OTP**：輸入 email 寄信 → 輸入信中 6 碼（`verifyOTP`
  type `.recovery`，成功即取得 session）→ 設定新密碼
  （`auth.update(user:)`）。不走連結、免 URL scheme。
- 完成第 3 步後**直接進入 app**（session 已存在，不再要求重新登入）。

### 新增的概念

- **`AuthPasswordResetClientProtocol`**（Usecase 層 client 抽象，照
  Slice C `AuthSessionClientProtocol` 模式）：`requestPasswordReset` /
  `verifyRecoveryOTP` / `updatePassword`。Supabase adapter 在
  Infrastructure。
- **三個 Usecase**：`RequestPasswordResetUseCase`、
  `VerifyRecoveryOTPUseCase`、`UpdatePasswordUseCase`。
- **`ForgotPasswordView(Model)`**：單一畫面依 `Step`（enterEmail →
  enterCode → newPassword）切換三段內容。

### 關鍵行為

- **Email enumeration 保護（UX 決策）**：無論帳號存在與否，送出
  email 後一律顯示「已寄送」進入第 2 步——不洩漏帳號是否存在。
  （GoTrue `/recover` 對不存在帳號本就回成功不寄信。）
- **重寄 = 再次 `resetPasswordForEmail`**：SDK 2.5.1 的
  `resend(email:type:)` 沒有 recovery type。60 秒 client-side 冷卻
  （沿用 Slice C UX 模式，實作各自持有、不共用元件）。
- **驗證碼成功即登入**：`verifyOTP(.recovery)` 發 `.signedIn` →
  RootView 會切到 authenticated。因此整個重設流程**掛在 RootView
  外層**（`fullScreenCover` 綁在 auth-state `Group` 之外），跨
  auth-state 切換仍存活，第 3 步設完密碼才 dismiss。
- **第 2 步之後取消**：使用者已透過信箱所有權取得 session → 取消
  = 保持登入狀態直接進 app（密碼未改）。此為明文行為（scenarios
  記錄）。
- **新密碼與舊密碼相同**：GoTrue 422 → 明確錯誤提示。

## 不做的事（Out of Scope）

- **登入狀態下改密碼**（Settings 內 change password）→ 未來 slice；
  `secure_password_change` 相關行為屆時處理
- **密碼強度規則**：沿用現有 minimum_password_length = 6，不另加
- **連結式重設**（產品決策採 OTP）
- **Production SMTP / 雲端模板** → Phase 2 上雲時處理（同 Slice C）

## Permissions

| 角色 | 可做 | 不可做 |
|---|---|---|
| Anonymous | `/recover` 寄重設信（rate limit 內）；`verifyOTP(.recovery)` 換 session | 猜他人 email 是否存在（回應一律成功）|
| 重設中（已過第 2 步，持 session） | `auth.update(user:)` 改自己的密碼 | — |

權限執行位置：GoTrue 伺服器端權威（OTP 驗證、rate limit）；Usecase
層 fail-fast 預檢（email 非空、6 碼格式、新密碼長度）非權威。

## User Flow

```
LoginView（sign-in mode）密碼欄下「忘記密碼？」
  → RootView.isPasswordResetPresented = true（fullScreenCover）
  → Step 1 enterEmail：輸入 email 按「寄送驗證碼」
    → RequestPasswordResetUseCase.request(email)
      → authPasswordResetClient.requestPasswordReset
    → 一律進 Step 2（enumeration 保護）
  → Step 2 enterCode：輸入信中 6 碼按「驗證」
    → VerifyRecoveryOTPUseCase.verify(email, code)
      → verifyOTP(.recovery) → session 成立、.signedIn 發出
        （RootView 背後已切 authenticated；cover 仍蓋在上面）
  → Step 3 newPassword：輸入新密碼按「更新密碼」
    → UpdatePasswordUseCase.update(newPassword)
      → auth.update(user:)
    → onComplete → cover dismiss → 使用者已在 ContentView
```

## Scenario 總表

完整 Given/When/Then 見 `scenarios.md`。

| 代碼 | 層 | 數量 |
|---|---|---|
| RP | Usecase — RequestPasswordResetUseCase | 3 |
| VR | Usecase — VerifyRecoveryOTPUseCase | 4 |
| UP | Usecase — UpdatePasswordUseCase | 5 |
| PM | Infrastructure — error mapping（純單元） | 4 |
| DINT | Infrastructure — 整合（local Supabase + Mailpit） | 3 |
| FVM | ViewModel — ForgotPasswordViewModel | 9 |
| **合計** | | **28** |
