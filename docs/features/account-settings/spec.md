# 帳號設定 — Spec

> Phase 4 Slice B of Shared-Schedule
> 使用者在 Settings 檢視 / 編輯自己的顯示名稱、登出、刪除帳號

## Why

Slice A 讓使用者能註冊並擁有 `user_profiles.display_name`，但留下兩個
缺口：

1. **沒有編輯入口**：註冊時填的 displayName 一旦填錯就無法修改。Slice A
   已鋪好 `user_profiles` 的 `self_update` RLS policy
   （`20260510044011_add_user_profiles.sql:34-35`），但沒有對應的 RPC 或
   UI——本 slice 補完。
2. **沒有刪除帳號**：App Store Review Guideline 5.1.1(v) 規定——凡支援
   帳號建立的 app 必須讓使用者在 app 內發起帳號刪除。目前完全沒有，
   上架會被拒。

同時把目前掛在 `ThemeSettingsView`（主題預覽 view）上的「登出」整理進
新的帳號區，讓 `ThemeSettingsView` 退回純主題職責。

## What

### 新增的概念

- **Account**（Domain aggregate）：只有一個刪除命令、無狀態。
  `AccountRepositoryProtocol.deleteAccount()` + `DeleteAccountError`。
- **`UserProfileRepositoryProtocol.update(displayName:)`**：透過
  `update_user_profile` SECURITY DEFINER RPC upsert 自己的 displayName。
- **`update_user_profile` RPC**：upsert 語意（無 profile 的 legacy /
  partial-signup 使用者第一次設定即補建 row）。
- **`delete_account` RPC**：`DELETE FROM auth.users WHERE id = auth.uid()`，
  所有 app 資料經既有 `ON DELETE CASCADE` FK 自動清除。
- **`SettingsView` / `AccountSettingsView` / `SettingsViewModel`**：新的
  Settings 容器與帳號區。

### 使用者可以做的事（增量）

- 進入 Settings（齒輪）→ 帳號區顯示目前的顯示名稱。
- 編輯顯示名稱 → 按「儲存」→ 名稱更新（1-50 chars、trim 後不可空）。
- 在帳號區登出。
- 刪除帳號：點「刪除帳號」→ confirmation dialog →「刪除」→ 帳號連同
  其所有課表 / 預約 / 成員資格 / profile 一併刪除 → 自動回到登入畫面。

## 不做的事（Out of Scope）

Slice B **不含**以下項目：

- **Email verification on production / Password reset** → 獨立 Slice
- **Privacy manifest**（`PrivacyInfo.xcprivacy`） → 獨立 Slice
- **跨裝置 / 即時同步他人看到的 displayName**：owner row 顯示的是「別人的」
  displayName、由該人自己編輯後落庫；不做 realtime 推播
- **刪除帳號前的「你仍有學生預約」攔阻**：刪帳號即全 CASCADE 清除
- **打字確認 / 重新登入 re-authenticate**：MVP 純 confirmation dialog
- **Avatar / 頭像、email 變更、displayName 改名歷史 / audit** → Phase 4+

## Permissions

| 角色 | 可做 | 不可做 |
|---|---|---|
| 任何 authenticated user | 透過 `update_user_profile` RPC upsert 自己的 displayName；透過 `delete_account` RPC 刪除自己的帳號 | 改 / 刪別人的 profile 或帳號（RPC 用 auth.uid() 鎖定 caller） |
| Anonymous | 無；兩個 RPC 都要 session（auth.uid() 非 NULL） | 任何操作 |

權限執行位置：
- **Domain 層**：`UserProfile.init` 擋 length invariant；不做 authorization
- **Usecase 層**：`UpdateDisplayNameUseCase` 做 fail-fast 預檢（length /
  非空）；`DeleteAccountUseCase` 純 delegate
- **Backend RPC**：`update_user_profile` / `delete_account` 都
  `SECURITY DEFINER` + `auth.uid()` 鎖定 caller

## User Flow

### 編輯顯示名稱

```
ScheduleListView 齒輪 → Settings sheet → SettingsView → AccountSettingsView
  ↓ 編輯 displayName TextField，按「儲存」
SettingsViewModel.saveDisplayName()
  → UpdateDisplayNameUseCase.updateDisplayName(newName)
    → 預檢：trim 後非空、length <= 50 → 否則 .invalidDisplayName
    → userProfileRepo.update(displayName:)
      → update_user_profile RPC：auth → length → upsert
      → 回更新後 UserProfile
  ↓ 成功
  → currentUserProvider.updateCachedDisplayName(newName)
    （更新 app 全域的 currentUser 快取，讓重開 Settings 立即顯示新名，
     不必等下次 sign-in）
顯示「已更新」輕量回饋；失敗顯示 inline error
```

### 刪除帳號

```
AccountSettingsView「刪除帳號」按鈕
  ↓ 點擊
.confirmationDialog「此動作將永久刪除你的帳號與所有課表、預約，無法復原。」
  ↓ 確認「刪除」
SettingsViewModel.deleteAccount()
  → DeleteAccountUseCase.deleteAccount()
    → accountRepo.deleteAccount()
      → delete_account RPC：auth → DELETE FROM auth.users WHERE id = auth.uid()
      → schedules / memberships / bookings / user_profiles 經 CASCADE 清除
  ↓ 成功（回 true）
View 觸發 onAccountDeleted → RootView teardown（signOut + 清 keychain +
  userProvider.clear() + authState = .unauthenticated）→ 回登入畫面
```

### 登出（從帳號區）

沿用既有 `RootView.signOut` 機制，只是入口從 `ThemeSettingsView` 移到
`AccountSettingsView` 的帳號區。

## Technical Notes

- **核心技術假設**：`delete_account` 用 SECURITY DEFINER RPC（owner =
  postgres）直接刪 `auth.users`，免 Edge Function。由整合測試 AINT1 把關；
  若被拒則回退 Edge Function + service_role admin API。詳見 `api.md`。
- **teardown 重用**：刪帳號後 server session 已失效，本地 signOut 會
  401（SDK 忽略），既有 `RootView.signOut` 的防禦性清 keychain 正好涵蓋。
- **upsert 與 create 並存**：`create_user_profile` 限 signup（要求全新、
  `ALREADY_EXISTS` = retry race）；`update_user_profile` 限 settings 編輯
  （upsert）。分工見 `api.md`。
