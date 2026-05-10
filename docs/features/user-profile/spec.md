# 使用者檔案 — Spec

> Phase 4 Slice A of Shared-Schedule
> 新用戶 sign-up 收 displayName、user_profiles 表存它、owner row 顯示
> 它（fallback 到 email）

## Why

Slice 1.5 老師進自己 schedule 看到 booking row 是「09:00 — 10:00 ........
test-student-c@example.com」——email 直接 surface 在 UI 偏粗糙、不像
能上架的私人課場景。Slice A 補兩件事讓「老師看小明預約 10 點的課」
真正在 UI 出現：

1. **sign-up 收 displayName**：目前 LoginView 已有 sign-up 切換但只
   收 email + password；新用戶就算成功註冊也沒有可顯示的人話名稱。
2. **displayName 真生效**：目前 `User.displayName` 在
   `SupabaseAuthCurrentUserProvider.swift:19` 寫死成 email、整個 app
   沒地方 surface 過真實 displayName。

Slice A 同時為 Phase 4 後續（settings view / account deletion / 未來
user discovery）鋪好「`public.user_profiles` 表 + 真 displayName」這條
基礎建設。

不含：email verification flow / password reset / settings view / account
deletion / privacy manifest（各自 Slice，見下方 Out of Scope）。

## What

### 新增的概念

- **UserProfile**（Domain entity）：`{ userID, displayName }`。
  `displayName` 在 init 時驗 length 1-50 chars（trim 後）。
- **`public.user_profiles`** 表：`(user_id PK FK auth.users ON DELETE
  CASCADE, display_name TEXT NOT NULL, created_at, updated_at)`。
  RLS：self-only SELECT/UPDATE；INSERT 走 SECURITY DEFINER RPC。
- **`OwnerBooking`** 加 `studentDisplayName: String?` 欄位（nil = profile
  不存在；View 端 fallback 到 email）。

### Student 可以做的事（增量）

- 開 app 看到「沒有帳號？註冊」連結 → 進 sign-up 表單 3 欄（email /
  password / displayName）→ 填完按「註冊」→ 註冊成功並自動 login。
- displayName 必填（1-50 chars，trim 後不可空）。

### Teacher 可以做的事（增量）

- 進自己 schedule calendar 看 booking row 顯示為「**小明**」（學生的
  displayName），而非 email。
- 學生若沒走過新 sign-up flow（profile row 不存在），仍 fallback 顯示
  email，不破舊用戶體驗。

## 不做的事（Out of Scope）

Slice A **不含**以下項目：

- **Email verification flow**（local config `enable_confirmations =
  false`、本 slice 限 local 行為；上 production 前要另開 Slice 處理）
  → Slice B
- **Password reset / forgot password** → 獨立 Slice
- **Settings view**（自己看 / 編輯 displayName / logout / delete
  account） → 跟 account deletion 同 Slice 一起做
- **Account deletion**（Apple App Store 硬 gate） → 獨立 Slice
- **Privacy manifest**（`PrivacyInfo.xcprivacy`） → 獨立 Slice
- **User discovery / search** → mid-term roadmap
- **displayName uniqueness constraint** → 等 user discovery 才需要
- **Avatar / 頭像** → Phase 4+
- **Sign in with Apple** → Apple 強制要求是「同 app 提供其他 social
  provider 時」；本 slice 仍只有 email/password、不觸發

## Permissions

| 角色 | 可做 | 不可做 |
|---|---|---|
| 任何 authenticated user | 透過 `create_user_profile` RPC 建立自己的 profile（一次）；透過 PostgREST 讀 / 更新自己的 profile（self_select / self_update RLS） | 讀 / 改別人的 profile（RLS 擋）；對 user_profiles 表直接 INSERT（無 INSERT policy） |
| Schedule owner | 透過 `get_bookings_for_owner` RPC（SECURITY DEFINER）讀到 schedule 上 booking 的 student displayName + email | 直接 SELECT user_profiles 看別人（owner !⇒ self；RLS 擋） |
| Anonymous | 無；signUp 流程要 Supabase Auth 先 issue session 才能 call create_user_profile | 任何 user_profiles 操作 |

權限執行位置：
- **Domain 層**：`UserProfile.init` 擋 length invariant；不做 authorization
- **Usecase 層**：`CompleteSignUpUseCase` 做 fail-fast 預檢（email / password /
  displayName 非空）；非權威
- **Backend RLS**：`user_profiles` self-only SELECT / UPDATE
- **Backend RPC**：`create_user_profile` SECURITY DEFINER + auth.uid()
  + length check + unique_violation handling

## User Flow

### Sign-up

```
LoginView 預設顯示 sign-in mode
  ↓ 點「沒有帳號？註冊」
切換為 sign-up mode：display 第三個 TextField「顯示名稱」
  ↓ 三欄填完按「註冊」
viewModel.signUp()
  → CompleteSignUpUseCase.completeSignUp(email, password, displayName)
    → 預檢：invalidEmail / invalidPassword / invalidDisplayName
    → authClient.signUp(email:password:)
      → 422 → .userAlreadyExists
      → URLError → .network
    → userProfileRepo.create(displayName:)
      → create_user_profile RPC: auth → length → INSERT
      → unique_violation → ALREADY_EXISTS → usecase 視為成功（重試 race）
      → other → .partialFailure
  ↓ 成功
authStateChanges .signedIn → RootView 切到 ContentView
```

### Owner 看到 student 的 displayName

```
Schedule owner 進 calendar
  → loadOwnerBookings (既有 Slice 1.5)
    → ListAllBookingsForOwnerUseCase.listAllBookingsForOwner
      → SupabaseBookingRepository.fetchAllForOwner
        → get_bookings_for_owner RPC（v2、加 LEFT JOIN user_profiles）
          → 回 OwnerBooking 含 studentDisplayName: String?
  → presentedSlotsForSelectedDate owner 分支
    → SlotPresentationState.bookedByStudent(displayName: String?, email: String)
  → DaySlotListView.bookedByStudentRow
    → label = displayName ?? email （View 層 fallback）
```

### SupabaseAuthCurrentUserProvider 在 sign-in 後 hydrate displayName

```
Supabase auth.signedIn event fires
  → RootView.observeAuthState
    → await provider.update(from: authUser)
      → userProfileRepo.fetch(userID: authUser.id)
        → 有 profile → User(id, displayName: profile.displayName)
        → 無 profile → User(id, displayName: authUser.email ?? "") + log warning
```

partial failure 罕見場景：sign-up 第 1 步 (auth) 成功、第 2 步 (profile)
失敗。MVP UX：inlineError「註冊失敗，請重啟 app 再試」、user 重啟
後重新 sign in；下一次 sign in 沒 profile 就 fallback email。等
settings view ship 後再讓 user 在那邊補 profile。
