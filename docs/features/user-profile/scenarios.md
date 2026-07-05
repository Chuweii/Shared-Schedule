# 使用者檔案 — Scenarios

> Phase 4 Slice A 完整 BDD scenario list（Given / When / Then）。每筆
> scenario title 對應一個 `@Test` function；test 名以 camelCase 對映
> （testing.md §2）。代碼前綴：UD = UserProfile Domain、UC =
> CompleteSignUpUseCase、UINT = UserProfile Infrastructure 整合、LVM =
> LoginViewModel signup 增量、Auth-DN = SupabaseAuthCurrentUserProvider
> displayName 增量。Booking 既有 BINT8 改寫 + 加 BINT8b 也列在末段。

## Domain — UserProfile（4）

### UD1
**Given** displayName = "小明"（trim 後 length 2）
**When** 建立 UserProfile
**Then** 建立成功、displayName trim 後保留為 "小明"

### UD2
**Given** displayName = ""
**When** 建立 UserProfile
**Then** throws `.invalidDisplayName`

### UD3
**Given** displayName = "   "（全 whitespace）
**When** 建立 UserProfile
**Then** throws `.invalidDisplayName`（trim 後空）

### UD4
**Given** displayName = 51 個字
**When** 建立 UserProfile
**Then** throws `.invalidDisplayName`

## Usecase — CompleteSignUpUseCase（7）

> Fakes：`FakeAuthClient`（最小 wrapper：`signUp(email,password) async
> throws`）+ `FakeUserProfileRepository`。

### UC1
**Given** email = "x@y.com"、password = "password123"、displayName = "小明"，
fakeAuth 設成功、fakeRepo.create 設成功
**When** completeSignUp
**Then** usecase 不 throw；fakeAuth.signUp called 1 次；fakeRepo.create
called 1 次帶 "小明"

### UC2
**Given** displayName = "   "（pre-flight 抓到）
**When** completeSignUp
**Then** throws `.invalidDisplayName`；fakeAuth.signUp **未被呼叫**

### UC3
**Given** password = "12345"（length < 6）
**When** completeSignUp
**Then** throws `.invalidPassword`；fakeAuth.signUp **未被呼叫**

### UC4
**Given** email 全 whitespace
**When** completeSignUp
**Then** throws `.invalidEmail`；fakeAuth.signUp **未被呼叫**

### UC5
**Given** fakeAuth.signUp 拋 AuthError code 422（user already exists）
**When** completeSignUp
**Then** throws `.userAlreadyExists`；fakeRepo.create **未被呼叫**

### UC6
**Given** fakeAuth.signUp 成功；fakeRepo.create 拋 `.persistenceFailure`
**When** completeSignUp
**Then** throws `.partialFailure`

### UC7
**Given** fakeAuth.signUp 成功；fakeRepo.create 拋 `.alreadyExists`
（重試 race）
**When** completeSignUp
**Then** usecase 視為成功（不 throw）

## Infrastructure 整合測試（5，打 local Supabase）

> 沿用 `@Suite(.serialized)` + `requireLocalStack()` + `signIn(email:)`。

### UINT1
**Given** 動態用 fresh email 走 authClient.signUp 建立 user 並 sign in
（避開 seed user 已有 profile 的 ALREADY_EXISTS）
**When** SupabaseUserProfileRepository.create("小明")
**Then** 回 UserProfile（userID 對齊 auth.uid()、displayName == "小明"）；
DB 多一筆 row

### UINT2
**Given** 已 sign in seed user (test-teacher@example.com)，profile 已被 seed
backfill
**When** SupabaseUserProfileRepository.create("Anything")
**Then** RPC 回 `ALREADY_EXISTS` → mapper → throws `.alreadyExists`

### UINT3
**Given** 已 sign in seed user
**When** SupabaseUserProfileRepository.create with 51 個字 displayName
**Then** RPC 回 `INVALID_DISPLAY_NAME` → mapper → throws
`.invalidDisplayName`

### UINT4
**Given** user A 已 sign in
**When** SupabaseUserProfileRepository.fetch(userID: user B 的 id)
**Then** 回 nil（self_select RLS 擋）

### UINT5
**Given** user A 已 sign in
**When** SupabaseUserProfileRepository.fetch(userID: user A 的 id)
**Then** 回 UserProfile（自己看自己 OK）

## Booking 整合測試更新（2）

### BINT8'（既有 BINT8 改）
**Given** user C 已 book 一筆未來 slot；user C 的 profile 由 seed
backfill 為 "Test Student C"
**When** user A（owner）呼叫 `fetchAllForOwner`
**Then** OwnerBooking.studentDisplayName == "Test Student C"；studentEmail
== "test-student-c@example.com"

### BINT8b（新）
**Given** 動態 sign-up 一個 fresh user but **不**走 profile create；該
user 加入某 schedule 後 book 一筆 slot
**When** schedule owner 呼叫 fetchAllForOwner
**Then** OwnerBooking.studentDisplayName == nil；studentEmail 為新 user
的 email

## ViewModel — LoginViewModel signup 增量（4）

> Fakes：`FakeCompleteSignUpUseCase`（settable resultToReturn /
> errorToThrow）。LoginViewModel init 多一個 useCase 參數（optional
> default = real wired-up）。
>
> **2026-07 語言設定功能修訂**（見 `docs/features/language-settings/`）：
> ViewModel 不再自行解析 localized 字串（`String(localized:)` 不跟隨
> App 內語言切換），改為暴露 `error: LoginError?` enum；由 View 對應
> `LocalizedStringKey` 顯示。以下 Then 的「顯示 localized『…』」皆指
> View 層對應後的使用者可見結果。

### LVM1
**Given** email / password / displayName 三欄全有效；fakeUseCase 設 success
**When** viewModel.signUp()
**Then** error == nil；isLoading 結束時為 false；useCase.callCount == 1

### LVM2
**Given** displayName 留空
**When** viewModel.signUp()
**Then** error == `.emptyDisplayName`（View 顯示 localized「請輸入顯示
名稱」）；useCase **未被呼叫**

### LVM3
**Given** fakeUseCase 拋 `.userAlreadyExists`
**When** viewModel.signUp()
**Then** error == `.userExists`（View 顯示 localized「此 email 已被註冊」，
既有 loginErrorUserExists key）

### LVM4
**Given** fakeUseCase 拋 `.partialFailure`
**When** viewModel.signUp()
**Then** error == `.partialFailure`（View 顯示 localized「註冊失敗，請
重啟 app 再試」，`signUpErrorPartialFailure`）

> 既有 `describe()` static tests 同步改為斷言 enum case。

## SupabaseAuthCurrentUserProvider 整合測試更新（2 改 + 1 加）

### Auth-DN-既有1（原 realSignInUpdatesProvider，assertion 改）
**Given** 真的 sign in user A，profile seed 為 "Test Teacher A"
**When** provider.update(from: authUser)
**Then** provider.currentUser.displayName == **"Test Teacher A"**（不再 == email）

### Auth-DN-既有2（原 consecutiveSignIns，assertion 改）
**Given** sign in user A → sign in user B
**When** provider.update sequentially
**Then** provider.currentUser.displayName == **"Test Teacher B"**

### Auth-DN1（新）
**Given** 動態 sign-up fresh user，但**不**走 profile create
**When** provider.update(from: authUser)
**Then** provider.currentUser.displayName == fresh email（fallback path）

## Test 數量（Slice A）

| 層 | 數量 |
|---|---|
| Domain (UD) | 4 |
| Usecase CompleteSignUp (UC) | 7 |
| Infrastructure UserProfiles (UINT) | 5 |
| Infrastructure Booking 增量 (BINT8'/BINT8b) | 2 |
| Infrastructure Auth 增量 (Auth-DN) | 3 |
| ViewModel LoginViewModel signup (LVM) | 4 |
| **Slice A 合計** | **25** |
