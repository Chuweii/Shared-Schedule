# 忘記密碼 — Scenarios

> Phase 4 Slice D 完整 BDD scenario list（Given / When / Then）。每筆
> scenario title 對應一個 `@Test` function；test 名以 camelCase 對映
> （testing.md §2）。代碼前綴：RP = RequestPasswordResetUseCase、VR =
> VerifyRecoveryOTPUseCase、UP = UpdatePasswordUseCase、PM =
> SupabaseAuthPasswordResetClient error mapping（純單元）、DINT =
> 整合、FVM = ForgotPasswordViewModel。

## Usecase — RequestPasswordResetUseCase（3）

> Fake：`FakeAuthPasswordResetClient`（settable errorToThrow、記錄呼
> 叫參數）。

### RP1
**Given** email = "  x@y.com  "（前後空白），fake 設成功
**When** request
**Then** 不 throw；client called 1 次、email 已 trim

### RP2
**Given** email 全 whitespace（pre-flight）
**When** request
**Then** throws `.emptyEmail`；client **未被呼叫**

### RP3
**Given** fake 拋 `.rateLimited`
**When** request
**Then** throws `.rateLimited`（`.network` 同理；`@Test(arguments:)`
覆蓋兩者）

## Usecase — VerifyRecoveryOTPUseCase（4）

### VR1
**Given** code = "123456"，fake 設成功
**When** verify
**Then** 不 throw；client.verifyRecoveryOTP called 1 次、email 已 trim

### VR2
**Given** code = "12345"（僅 5 碼）
**When** verify
**Then** throws `.invalidCodeFormat`；client **未被呼叫**

### VR3
**Given** code = "12345a"（含非數字）
**When** verify
**Then** throws `.invalidCodeFormat`；client **未被呼叫**

### VR4
**Given** fake 拋 `.invalidOrExpiredCode`
**When** verify
**Then** throws `.invalidOrExpiredCode`（`.rateLimited`/`.network`
同理；`@Test(arguments:)`）

## Usecase — UpdatePasswordUseCase（5）

### UP1
**Given** newPassword = "newpassword456"，fake 設成功
**When** update
**Then** 不 throw；client.updatePassword called 1 次

### UP2
**Given** newPassword = "12345"（< 6，pre-flight）
**When** update
**Then** throws `.shortPassword`；client **未被呼叫**

### UP3
**Given** fake 拋 `.samePassword`
**When** update
**Then** throws `.samePassword`

### UP4
**Given** fake 拋 `.weakPassword`
**When** update
**Then** throws `.weakPassword`

### UP5
**Given** fake 拋 `.network`
**When** update
**Then** throws `.network`

## Infrastructure — SupabaseAuthPasswordResetClient error mapping（4，純單元）

> JSON 解出 `AuthError.APIError` fixture 餵 static mapper，同 Slice C
> SM 模式。

### PM1
**Given** APIError code 429
**When** mapRequestError
**Then** `.rateLimited`

### PM2
**Given** APIError code 403、msg "Token has expired or is invalid"
**When** mapVerifyError
**Then** `.invalidOrExpiredCode`（401 同；`@Test(arguments:)`）

### PM3
**Given** APIError code 422、msg "New password should be different from the old password."
**When** mapUpdateError
**Then** `.samePassword`

### PM4
**Given** APIError 含 weak_password（422）
**When** mapUpdateError
**Then** `.weakPassword`

## Infrastructure 整合測試（3，local Supabase + Mailpit）

> 用 `signUpFreshUserConfirmed` 建 fresh user，不動 seed A/B/C（其他
> 測試依賴 `password123` 登入）。

### DINT1（happy path）
**Given** fresh confirmed user，sign out 後 `requestPasswordReset`
**When** Mailpit 取 6 碼 → `verifyRecoveryOTP` → `updatePassword("newpassword456")`
**Then** sign out 後用新密碼登入成功；用舊密碼登入 throws

### DINT2
**Given** fresh confirmed user 已請求重設
**When** `verifyRecoveryOTP(email, 錯誤碼)`
**Then** throws `.invalidOrExpiredCode`

### DINT3
**Given** fresh confirmed user 已透過 recovery OTP 取得 session
**When** `updatePassword` 設成與原密碼相同
**Then** throws `.samePassword`（釘住 422 映射）

## ViewModel — ForgotPasswordViewModel（9）

> Fakes：`FakeRequestPasswordResetUseCase`、
> `FakeVerifyRecoveryOTPUseCase`、`FakeUpdatePasswordUseCase`。

### FVM1
**Given** step == .enterEmail、email 有效，fakeRequest 設成功
**When** sendCode()
**Then** step == .enterCode；error == nil；fakeRequest called 1 次；
resendSecondsRemaining == 60

### FVM2
**Given** email 留空
**When** sendCode()
**Then** error == `.emptyEmail`；step 仍 == .enterEmail；useCase 未呼叫

### FVM3
**Given** fakeRequest 拋 `.rateLimited`
**When** sendCode()
**Then** error == `.rateLimited`；step 仍 == .enterEmail

### FVM4
**Given** step == .enterCode、code = "123456"，fakeVerify 設成功
**When** verifyCode()
**Then** step == .newPassword；error == nil

### FVM5
**Given** step == .enterCode、code 留空
**When** verifyCode()
**Then** error == `.emptyCode`；useCase 未呼叫

### FVM6
**Given** fakeVerify 拋 `.invalidOrExpiredCode`
**When** verifyCode()
**Then** error == `.invalidOrExpiredCode`；step 仍 == .enterCode

### FVM7
**Given** step == .newPassword、newPassword = "newpassword456"，
fakeUpdate 設成功
**When** submitNewPassword()
**Then** step == .done（成功畫面）；error == nil；onComplete **未被
呼叫**（2026-07-19 UX 修訂：停在成功畫面等使用者按「開始使用」）

### FVM8
**Given** fakeUpdate 拋 `.samePassword`
**When** submitNewPassword()
**Then** error == `.samePassword`；step 仍 == .newPassword；
onComplete 未被呼叫

### FVM9
**Given** step == .enterCode、resendSecondsRemaining = 30（冷卻中）
**When** resendCode()
**Then** fakeRequest **未被呼叫**（冷卻 0 時 resendCode 行為 = 再次
sendCode 但不改 step，fakeRequest called 1 次並重啟冷卻——同測試
內驗證兩段）

### FVM10（2026-07-19 UX 修訂新增）
**Given** step == .done（成功畫面）
**When** finish()
**Then** onComplete 被呼叫 1 次

## Test 數量（Slice D）

| 層 | 數量 |
|---|---|
| Usecase RequestPasswordReset (RP) | 3 |
| Usecase VerifyRecoveryOTP (VR) | 4 |
| Usecase UpdatePassword (UP) | 5 |
| Infrastructure mapping (PM) | 4 |
| Infrastructure 整合 (DINT) | 3 |
| ViewModel ForgotPassword (FVM) | 10 |
| **Slice D 合計** | **29** |
