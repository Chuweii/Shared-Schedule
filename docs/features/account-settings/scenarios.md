# 帳號設定 — Scenarios

> Phase 4 Slice B 完整 BDD scenario list（Given / When / Then）。每筆
> scenario title 對應一個 `@Test` function；test 名以 camelCase 對映
> （testing.md §2）。代碼前綴：UPD = UpdateDisplayName Usecase、
> DEL = DeleteAccount Usecase、PINT = profile-update Infrastructure 整合、
> AINT = account-delete Infrastructure 整合、SVM = SettingsViewModel。

## Usecase — UpdateDisplayNameUseCase（4）

> Fakes：`FakeUserProfileRepository`（既有，加 `update`；settable
> updateResult / updateError + 記 callCount + 收到的 displayName）。

### UPD1
**Given** displayName = "小華"（trim 後 length 2），fakeRepo.update 設成功
**When** updateDisplayName("小華")
**Then** 回更新後 UserProfile；fakeRepo.update called 1 次帶 trimmed "小華"

### UPD2
**Given** displayName = "   "（全 whitespace，pre-flight 抓到）
**When** updateDisplayName
**Then** throws `.invalidDisplayName`；fakeRepo.update **未被呼叫**

### UPD3
**Given** displayName = 51 個字（pre-flight 抓到）
**When** updateDisplayName
**Then** throws `.invalidDisplayName`；fakeRepo.update **未被呼叫**

### UPD4
**Given** fakeRepo.update 拋 `UserProfileError.persistenceFailure`
**When** updateDisplayName("小華")
**Then** throws `.persistenceFailure`

## Usecase — DeleteAccountUseCase（2）

> Fake：`FakeAccountRepository`（settable deleteError + 記 callCount）。

### DEL1
**Given** fakeRepo.deleteAccount 設成功
**When** deleteAccount()
**Then** usecase 不 throw；fakeRepo.deleteAccount called 1 次

### DEL2
**Given** fakeRepo.deleteAccount 拋 `.persistenceFailure`（或 `.network`）
**When** deleteAccount()
**Then** 分別透傳 `.persistenceFailure` / `.network`

## Infrastructure 整合測試（打 local Supabase，5）

> 沿用 `@Suite(.serialized)` + `requireLocalStack()` + 動態 sign-up helper。

### PINT1
**Given** 動態用 fresh email sign-up 並建立 profile（先 create("初名")）
**When** SupabaseUserProfileRepository.update("新名")
**Then** 回 UserProfile（displayName == "新名"）；DB row display_name 更新、
updated_at 變新

### PINT2
**Given** 動態用 fresh email sign-up 但 **skip** profile create（legacy /
partial-signup 狀態）
**When** SupabaseUserProfileRepository.update("初設")
**Then** upsert 建立 row；回 UserProfile（displayName == "初設"）

### PINT3
**Given** 已 sign in user
**When** SupabaseUserProfileRepository.update with 51 個字 displayName
**Then** RPC 回 `INVALID_DISPLAY_NAME` → mapper → throws `.invalidDisplayName`

### AINT1（**驗核心技術假設**）
**Given** 動態用 fresh email sign-up，建立 profile + 一個自己 owner 的
schedule（owner schedule 證明 `owner_id` FK 是 ON DELETE CASCADE——若為
RESTRICT，deleteAccount 會被 FK 擋而 throw）
**When** SupabaseAccountRepository.deleteAccount()
**Then** 不 throw；用同一 email / password 重新 sign in **失敗**（`auth.users`
row 確實消失，連帶 owned 資料經 CASCADE 清除）

> 補充：SECURITY DEFINER RPC 對 `auth.users` 的 DELETE 權限 + CASCADE
> 級聯（before 1/1/1 → after 0/0/0）已於 migration 階段以 psql 模擬
> authenticated JWT context 直接手測通過。

### AINT2
**Given** 無 active session（已 signOut）
**When** SupabaseAccountRepository.deleteAccount()
**Then** throws `DeleteAccountError`（RPC 需要 auth.uid()、無 session 不通）

## ViewModel — SettingsViewModel（5）

> Fakes：`FakeUpdateDisplayNameUseCase`、`FakeDeleteAccountUseCase`
> （settable result / error + callCount）+ `FakeCurrentUserProvider`
> （回固定 displayName）。

### SVM1
**Given** currentUser.displayName == "小明"
**When** SettingsViewModel 初始化
**Then** viewModel.displayName == "小明"

### SVM2
**Given** displayName 編輯為 "小華"；fakeUseCase 設 success
**When** saveDisplayName()
**Then** didSaveDisplayName == true；displayNameError == nil；
useCase.callCount == 1

### SVM3
**Given** displayName 編輯為 "   "（空白）
**When** saveDisplayName()
**Then** displayNameError 設為 localized「請輸入顯示名稱」；useCase **未被呼叫**

### SVM4
**Given** fakeUseCase 拋 `.persistenceFailure`
**When** saveDisplayName()
**Then** displayNameError 設為 localized「儲存失敗，請稍後再試」

### SVM5
**Given** fakeDeleteUseCase 設 success（再測一次設 error）
**When** deleteAccount()
**Then** 成功時回傳 true、deleteError == nil；失敗時回傳 false、
deleteError 設為 localized「刪除失敗，請稍後再試」

> View tests 不寫（依現行慣例，SwiftUI view 透過手動預覽 + e2e 驗）。

## Test 數量（Slice B）

| 層 | 數量 |
|---|---|
| Usecase UpdateDisplayName (UPD) | 4 |
| Usecase DeleteAccount (DEL) | 2 |
| Infrastructure profile-update (PINT) | 3 |
| Infrastructure account-delete (AINT) | 2 |
| ViewModel SettingsViewModel (SVM) | 5 |
| **Slice B 合計** | **16** |
