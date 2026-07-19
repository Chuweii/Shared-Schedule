# Email 驗證 — Scenarios

> Phase 4 Slice C 完整 BDD scenario list（Given / When / Then）。每筆
> scenario title 對應一個 `@Test` function；test 名以 camelCase 對映
> （testing.md §2）。代碼前綴：SI = SignInUseCase、VE =
> VerifyEmailOTPUseCase、RV = ResendVerificationCodeUseCase、UC' =
> CompleteSignUpUseCase 改寫、SM = SupabaseAuthSessionClient error
> mapping（純單元）、CINT = 整合、LVM-C = LoginViewModel 增量、EVM =
> EmailVerificationViewModel。

## Usecase — SignInUseCase（5）

> Fake：`FakeAuthSessionClient`（settable errorToThrow、記錄呼叫參數）。

### SI1
**Given** email = "  x@y.com  "（前後空白）、password = "password123"，
fake 設成功
**When** signIn
**Then** 不 throw；fake.signIn called 1 次、email 已 trim 為 "x@y.com"

### SI2
**Given** fake 拋 `AuthSignInError.invalidCredentials`
**When** signIn
**Then** throws `SignInError.invalidCredentials`

### SI3
**Given** fake 拋 `AuthSignInError.emailNotConfirmed`
**When** signIn
**Then** throws `SignInError.emailNotConfirmed`

### SI4
**Given** fake 拋 `AuthSignInError.network`
**When** signIn
**Then** throws `SignInError.network`

### SI5
**Given** fake 拋 `AuthSignInError.generic`
**When** signIn
**Then** throws `SignInError.generic`

## Usecase — VerifyEmailOTPUseCase（7）

> Fakes：`FakeAuthSessionClient` + `FakeUserProfileRepository`（Slice A
> 既有）。

### VE1
**Given** code = "123456"、displayName = "  小明  "，fake client 與
fake repo 皆設成功
**When** verify
**Then** 不 throw；client.verifySignUpOTP called 1 次；repo.create
called 1 次帶 trim 後的 "小明"

### VE2
**Given** code = "123456"、displayName = nil（延後驗證路徑）
**When** verify
**Then** 不 throw；client.verifySignUpOTP called；repo.create **未被
呼叫**

### VE3
**Given** code = "12345"（僅 5 碼）
**When** verify
**Then** throws `.invalidCodeFormat`；client **未被呼叫**

### VE4
**Given** code = "12345a"（含非數字）
**When** verify
**Then** throws `.invalidCodeFormat`；client **未被呼叫**

### VE5
**Given** fake client 拋 `VerifyOTPClientError.invalidOrExpiredCode`
**When** verify
**Then** throws `.invalidOrExpiredCode`；repo.create **未被呼叫**

### VE6
**Given** fake client 拋 `VerifyOTPClientError.rateLimited`
**When** verify
**Then** throws `.rateLimited`

### VE7
**Given** 驗證成功；fake repo.create 拋 `.persistenceFailure`
**When** verify
**Then** 不 throw（建檔 best-effort、非致命；`.alreadyExists` 同樣
吞掉——同一 `@Test(arguments:)` 覆蓋兩個 error）

## Usecase — ResendVerificationCodeUseCase（3）

### RV1
**Given** email = "  x@y.com  "，fake 設成功
**When** resend
**Then** 不 throw；client.resendSignUpConfirmation called 1 次、email
已 trim

### RV2
**Given** fake 拋 `ResendConfirmationError.rateLimited`
**When** resend
**Then** throws `.rateLimited`

### RV3
**Given** fake 拋 `ResendConfirmationError.network`
**When** resend
**Then** throws `.network`

## Usecase — CompleteSignUpUseCase 改寫（5）

> 移除 `userProfileRepository` 依賴與 `.partialFailure`；Slice A 的
> UC1/UC6/UC7 改寫或刪除，UC2-UC5 預檢不變（列出僅為文件完整，
> 既有測試沿用）。

### UC1'
**Given** 三欄有效，fake authSignUpClient 設成功
**When** completeSignUp
**Then** 不 throw；client.signUp called 1 次、**displayName 以參數傳
入**（進 metadata）；不再有 profile repo 互動

### UC2（沿用）displayName 全 whitespace → `.invalidDisplayName`、client 未呼叫
### UC3（沿用）password < 6 → `.invalidPassword`、client 未呼叫
### UC4（沿用）email 全 whitespace → `.invalidEmail`、client 未呼叫
### UC5（沿用）client 拋 `.userAlreadyExists` → `.userAlreadyExists`

> UC6（partialFailure）、UC7（alreadyExists 視為成功）**刪除**——
> 建檔已移到 VerifyEmailOTPUseCase（VE7）。

## Infrastructure — SupabaseAuthSessionClient error mapping（7，純單元）

> 不打網路：以 JSON 解出 `AuthError.APIError` fixture 餵 static
> mapper。Slice A 時代的 `LoginViewModelTests.describe_*` 遷移至此，
> `LoginViewModel.describe` 刪除。

### SM1
**Given** APIError code 400、msg "Invalid login credentials"
**When** mapSignInError
**Then** `.invalidCredentials`

### SM2
**Given** APIError code 400、msg "Email not confirmed"
**When** mapSignInError
**Then** `.emailNotConfirmed`（大小寫不敏感比對）

### SM3
**Given** URLError(.notConnectedToInternet)
**When** mapSignInError
**Then** `.network`

### SM4
**Given** 任意其他 error
**When** mapSignInError
**Then** `.generic`

### SM5
**Given** APIError code 403、msg "Token has expired or is invalid"
**When** mapVerifyError
**Then** `.invalidOrExpiredCode`（401 同；`@Test(arguments:)`）

### SM6
**Given** APIError code 429
**When** mapVerifyError
**Then** `.rateLimited`

### SM7
**Given** APIError code 429
**When** mapResendError
**Then** `.rateLimited`

## Infrastructure 整合測試（4，local Supabase + Mailpit）

> 沿用 `@Suite(.tags(.integration), .serialized)` +
> `requireLocalStack()`。新 helper `MailpitClient.waitForLatestOTP(to:)`
> 輪詢 `http://127.0.0.1:54324/api/v1/`。

### CINT1
**Given** fresh email 走 signUp（confirmations 開啟，無 session）
**When** 從 Mailpit 取 6 碼 → `verifySignUpOTP(email, token)`
**Then** 不 throw；`auth.session` 有效、user id 對齊

### CINT2
**Given** fresh email 已 signUp、尚未驗證
**When** `signIn(email, password)`
**Then** throws `AuthSignInError.emailNotConfirmed`（釘住 400 + msg
字串比對，R1）

### CINT3
**Given** fresh email 已 signUp
**When** `verifySignUpOTP(email, "000000")`（錯誤碼）
**Then** throws `VerifyOTPClientError.invalidOrExpiredCode`

### CINT4
**Given** fresh email 已 signUp（信箱已有 1 封）
**When** `resendSignUpConfirmation(email)` 後輪詢 Mailpit
**Then** 該信箱信件數增加為 2

## ViewModel — LoginViewModel 增量（4）

> Fakes：`FakeSignInUseCase`、`FakeResendVerificationCodeUseCase`、
> 既有 `FakeCompleteSignUpUseCase`。

### LVM-C1
**Given** email/password 有效，fakeSignIn 設成功
**When** viewModel.signIn()
**Then** error == nil；isLoading 結束為 false；fake.callCount == 1

### LVM-C2
**Given** fakeSignIn 拋 `.emailNotConfirmed`
**When** viewModel.signIn()
**Then** error == `.emailNotConfirmed`（View 顯示
`loginErrorEmailNotConfirmed`）；pendingVerification 仍為 nil

### LVM-C3
**Given** 三欄有效，fakeCompleteSignUp 設成功
**When** viewModel.signUp()
**Then** 不再直接進 app：pendingVerification == (email, displayName)

### LVM-C4
**Given** error == `.emailNotConfirmed`，fakeResend 設成功
**When** viewModel.proceedToVerification()
**Then** fakeResend called 1 次；pendingVerification == (email,
displayName: nil)；error 清空

### LVM-C5（2026-07-19 二次 UX 修訂新增）
**Given** email/password 有效，fakeSignIn 設成功
**When** viewModel.signIn()
**Then** didSignIn == true（LoginView 據此以 onChange 通知 RootView
顯示「歡迎回來」toast（共用 `.toast()` modifier、自動消失）——呈現
為 View 層接線，無對應 VM test；signIn 失敗時 didSignIn 維持
false，見 LVM-C2 補充斷言）

## ViewModel — EmailVerificationViewModel（8）

> Fakes：`FakeVerifyEmailOTPUseCase`、
> `FakeResendVerificationCodeUseCase`、既有 `FakeCurrentUserProvider`。

### EVM1
**Given** code = "123456"、displayName = "小明"，fakeVerify 設成功
**When** verify()
**Then** error == nil；fakeVerify called 1 次；
currentUserProvider.updateCachedDisplayName called 帶 "小明"；
isVerified == true（View 據此切換為成功畫面；「開始使用」按鈕為
View 層接線 → RootView dismiss cover，無對應 VM test。2026-07-19
UX 修訂）

### EVM2
**Given** code = ""
**When** verify()
**Then** error == `.emptyCode`；fakeVerify **未被呼叫**

### EVM3
**Given** fakeVerify 拋 `.invalidCodeFormat`
**When** verify()
**Then** error == `.invalidCodeFormat`

### EVM4
**Given** fakeVerify 拋 `.invalidOrExpiredCode`
**When** verify()
**Then** error == `.invalidOrExpiredCode`；isVerified == false

### EVM5
**Given** fakeVerify 拋 `.rateLimited`
**When** verify()
**Then** error == `.rateLimited`

### EVM6
**Given** resendSecondsRemaining == 0，fakeResend 設成功
**When** resend()
**Then** fakeResend called 1 次；resendSecondsRemaining == 60（倒數
timer 本身不測，見 testing.md「不用 Thread.sleep」）

### EVM7
**Given** resendSecondsRemaining = 30（冷卻中，直接設值）
**When** resend()
**Then** fakeResend **未被呼叫**

### EVM8
**Given** displayName = nil（延後驗證路徑），fakeVerify 設成功
**When** verify()
**Then** error == nil；updateCachedDisplayName **未被呼叫**

## Test 數量（Slice C）

| 層 | 數量 |
|---|---|
| Usecase SignIn (SI) | 5 |
| Usecase VerifyEmailOTP (VE) | 7 |
| Usecase Resend (RV) | 3 |
| Usecase CompleteSignUp 改寫 (UC') | 5（新寫 1、沿用 4、刪 2） |
| Infrastructure mapping (SM) | 7 |
| Infrastructure 整合 (CINT) | 4 |
| ViewModel LoginViewModel (LVM-C) | 5 |
| ViewModel EmailVerification (EVM) | 8 |
| **Slice C 合計** | **44** |
