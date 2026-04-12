# 老師建立 Schedule 並新增可預約時段 — Spec

> Feature 1 of Shared-Schedule
> Phase 1 — Mock MVP Feature 1（不接 Supabase、不做 Auth）

## Why

Shared-Schedule 是給自由接案教學者（健身教練、音樂老師、家教）使用的學生預約 app。老師要能在 app 內定義「我開放哪些時段讓學生預約」——這是整個 app 最核心的資料生成動作。沒有 Schedule，後續所有 feature（邀請、booking、探索）都沒東西可做。

作為 Phase 1 的第一個 feature，這個 feature 同時有兩個目的：

1. **產品目的**：讓老師能建立課表、定義可預約時段
2. **工程目的**：驗證 DDD + MVVM + 三 stage workflow 的實戰可行性，**在投入 Supabase 整合之前**把流程穩下來

## What

老師可以：

- 建立多份 Schedule（每份 schedule 代表一門課、一個時段組、或一個服務類型）
- 建立時設定 Schedule 的 title 與「最短時段長度」（`minWindowDuration`，預設 60 分鐘）
- 對每份 Schedule 新增 `AvailabilityWindow`（可預約時段）
- 刪除既有的 `AvailabilityWindow`
- 從 list 畫面切換到 detail 畫面查看某份 Schedule 的所有 window

所有 `AvailabilityWindow` 必須滿足以下不變條件（由 Domain aggregate 強制）：

- 結束時間必須晚於開始時間（`end > start`）
- 時段長度不得短於該 Schedule 設定的 `minWindowDuration`
- 不可與同一 Schedule 內的其他 window 時間重疊
  - **相鄰接觸不算重疊**：14:00-15:00 接 15:00-16:00 合法
  - **重疊定義**：`a.start < b.end && b.start < a.end`

## 不做的事（Out of Scope）

Feature 1 **不含**以下項目（未來另開 feature）：

- 刪除整份 Schedule
- 修改 Schedule 的 title 或 `minWindowDuration`
- 修改（移動 / resize）既有的 AvailabilityWindow（本版只能刪掉重加）
- Recurrence / 重複規則
- 任何 Student / Booking / Invitation 相關功能
- 任何 Supabase / Auth / 登入畫面
- 跨時區 UI 呈現（Phase 2 再處理）

## Permissions

Phase 1 階段是單一 hardcoded 老師（`teacher-001`）。沒有角色切換、沒有登入畫面。

- **Teacher**：可建立 / 瀏覽 / 編輯自己的 Schedule
- **Student**：不存在於 Phase 1

Phase 2 接入 Auth 後會改為以 `currentUserProvider.currentUser.id` 作為 owner。Owner 權限檢查在 Usecase 層執行（Domain 層不處理 authorization）。

## User Flow

```
啟動 app
  ↓
ScheduleListView（我的課表列表）
  ├─ 空狀態：顯示「建立第一份課表」提示
  └─ 有資料：列出所有屬於 teacher-001 的 Schedule
  ↓
點擊「＋新增課表」按鈕
  ↓
CreateScheduleSheet
  ├─ 輸入欄：title
  ├─ 選擇器：minWindowDuration（預設 60 分鐘）
  └─ 送出按鈕
  ↓
合法：sheet 關閉、回到 list（新 schedule 出現在列表）
非合法（空白 title）：sheet 不關、inline error「標題不能為空」
  ↓
（回到 list）點擊任一 schedule row
  ↓
NavigationLink push → ScheduleDetailView
  ├─ 顯示 schedule 標題與 minWindowDuration
  ├─ 列出所有 AvailabilityWindow
  └─ 空狀態：顯示「新增第一個時段」提示
  ↓
點擊「＋新增時段」按鈕
  ↓
AddWindowSheet
  ├─ DatePicker：start
  ├─ DatePicker：end
  └─ 送出按鈕
  ↓
合法：sheet 關閉、新 window 出現在列表
非合法：sheet 不關、顯示 inline error
  ├─ .invalidRange → 「結束時間必須晚於開始時間」
  ├─ .belowMinimumDuration → 「時段長度不得短於 N 分鐘」
  └─ .overlapping → 「時段與既有時段重疊」
  ↓
對單一 window 滑動 / 點擊刪除 → 從列表移除
```

## Scenarios 摘要

完整 Given / When / Then 見 [scenarios.md](./scenarios.md)。每個 scenario 對應一個測試函數，測試名稱與 scenario title 一一對應，可從 doc grep 到 test 反之亦然。

### Domain — Schedule aggregate (17)

| # | Scenario | 結果 |
|---|---|---|
| 1 | 以預設最短時段長度建立空 Schedule | 成功 |
| 2 | 以自訂最短時段長度建立空 Schedule | 成功 |
| 3 | 新增合法 window 到空 Schedule | 成功 |
| 4 | 新增接在既有 window 後方的 window（touching-after） | 成功 |
| 5 | 新增接在既有 window 前方的 window（touching-before） | 成功 |
| 6 | 新增恰好等於最短時段長度的 window | 成功 |
| 7 | 新增 start 等於 end 的 window | throws `.invalidRange` |
| 8 | 新增 start 晚於 end 的 window | throws `.invalidRange` |
| 9 | 新增短於最短時段長度的 window | throws `.belowMinimumDuration` |
| 10 | 新增與既有 window 部分重疊於右的 window | throws `.overlapping` |
| 11 | 新增與既有 window 部分重疊於左的 window | throws `.overlapping` |
| 12 | 新增完全包在既有 window 內部的 window | throws `.overlapping` |
| 13 | 新增完全包住既有 window 的 window | throws `.overlapping` |
| 14 | 新增與既有 window 時間完全相同的 window | throws `.overlapping` |
| 15 | 刪除既有 window | 成功、列表為空 |
| 16 | 刪除不存在的 window id | no-op、無錯誤 |
| 17 | 刪除 window 後以相同時段重新加入 | 成功（驗證釋放 slot） |

### Sub-phase 1b — Usecase + ViewModel (10)

**`CreateScheduleUsecase` (2)**

| # | Scenario | 結果 |
|---|---|---|
| 18 | 以有效 title 與最短時段長度建立 Schedule | repo 多一筆 schedule |
| 19 | 以空白（trim 後為空）title 建立 Schedule | throws `.blankTitle` |

**`ListSchedulesUsecase` (2)**

| # | Scenario | 結果 |
|---|---|---|
| 20 | Repository 為空時查詢 | 回傳 `[]` |
| 21 | Repository 含跨 owner 的多份 schedule 時查詢 | 只回傳屬於當前 user 的 |

**`ScheduleListViewModel` (6)**

| # | Scenario | 結果 |
|---|---|---|
| 22 | `onAppear` 載入空 repo | `state.schedules == []` |
| 23 | `onAppear` 載入既有 1 份 schedule | `state.schedules.count == 1` |
| 24 | 輸入有效 title 並送出建立 | 新 schedule 出現、sheet 關閉 |
| 25 | 輸入空白 title 並送出 | inline error、sheet 不關 |
| 26 | 輸入純空白字元 title 並送出 | 同上（trim 後視為空） |
| 27 | 有錯誤狀態後修正 title 重送 | error 清空、成功建立 |

### Sub-phase 1c — Usecase + ViewModel (12)

**`AddAvailabilityWindowUsecase` (3)**

| # | Scenario | 結果 |
|---|---|---|
| 28 | Owner 送出合法 window | schedule 多一個 window |
| 29 | 非 owner 嘗試送出 window | throws `.notOwner` |
| 30 | 對不存在的 scheduleID 嘗試送出 window | throws `.scheduleNotFound` |

**`RemoveAvailabilityWindowUsecase` (2)**

| # | Scenario | 結果 |
|---|---|---|
| 31 | Owner 移除既有 windowID | schedule 不再有該 window |
| 32 | 非 owner 嘗試移除 window | throws `.notOwner` |

**`ScheduleDetailViewModel` (7)**

| # | Scenario | 結果 |
|---|---|---|
| 33 | `onAppear` 進入有 2 windows 的 schedule | `state.schedule.windows.count == 2` |
| 34 | 送出合法 window | window 出現、sheet 關閉 |
| 35 | 送出 overlapping window | inline error `.overlapping`、sheet 不關 |
| 36 | 送出低於最短長度的 window | inline error `.belowMinimumDuration` |
| 37 | 送出 end < start 的 window | inline error `.invalidRange` |
| 38 | 有錯誤狀態後修正並重送合法 window | error 清空、成功加入 |
| 39 | 點擊刪除指定 windowID | window 從列表移除 |

**合計 39 個測試**，分三個 sub-phase 依序實作。

## Technical Notes

### 架構決策

- **DDD Aggregate**: `Schedule` 為 aggregate root、`AvailabilityWindow` 在內部。所有 mutation 透過 Schedule 的 method 進行。外部（Usecase / ViewModel）**絕對不能**直接持有 `AvailabilityWindow` 的可變參考並改它。
- **Typed Throws**: 採用 `throws(ScheduleError)`（iOS 26 原生支援）。好處：比 `Result<Void, E>` 少一層解包；Swift Testing 可直接 `#expect(throws: ScheduleError.overlapping)`。
- **Repository Contract**: `ScheduleRepositoryProtocol.save(_ schedule: Schedule)` 整份 aggregate 覆寫。**不做** `addWindow` / `removeWindow` 之類 repo method。理由：aggregate 是 transactional unit；Phase 2 接 Supabase + RLS 時 write 會是 upsert，contract 一致。
- **Repository 實作**: `InMemoryScheduleRepository` 是 `actor`，所有 method 都是 `async throws` 從 day 1。雖然 InMemory 實作用不到 `await`，但 VM 一律寫 async，Phase 2 切 Supabase 時不用重寫 VM。
- **Owner 權限檢查**: 在 Usecase 層，不在 Domain。Domain 不知道「誰在問」；authorization 是 application-layer 關切。
- **DI Composition**: `AppDependencies` struct 在 `Shared_ScheduleApp.init()` 建立一次，傳入 `ContentView`。ViewModel 透過 `init` 拿 Usecase，**不走** `@Environment`——避免 VM 測試要 mock `EnvironmentValues`。

### i18n

- **Day 1 使用 String Catalog**：`App/Resources/Localizations/Localizable.xcstrings`
- **三語同步**：zh-Hant / en / ja 在每個 PR 必須同時 checkin
- **開發語言為 zh-Hant**：Xcode Project Info → Localizations 設定 zh-Hant 為 Development Language
- **code 內字面值為中文**：`Text("新增課表")`，Xcode auto-extraction 會把中文 key 拉進 catalog
- ⚠️ 這與 `docs/conventions.md` §4「Use the key as plain English text」的措辭矛盾——那邊應改為 language-neutral 寫法。另開 chore commit 修 conventions.md。

### 時區處理

- Phase 1 全部用 `Date`（UTC），defer 跨時區 UI 呈現到 Phase 2
- 單一裝置、單一 locale 的 mock 期間不會觸發時區問題
- 跨日 window（23:00-01:00 次日）用 `Date` 自然支援

### 錯誤呈現

- Phase 1 只使用 **inline error**（form validation 風格）
- Toast / alert 模式在後續 phase 真的需要時才加
- Domain error → ViewModel 翻譯成 localized 字串 → View 顯示
- **Domain error 絕不原始透出到 View**

### 測試配置

- Domain 測試：`Shared ScheduleTests/Domain/Schedule/ScheduleTests.swift`
- Usecase 測試：`Shared ScheduleTests/Usecase/Schedule/`
- ViewModel 測試：`Shared ScheduleTests/Presentation/Schedule/`
- Sample factories：`Shared ScheduleTests/TestHelpers/`
- 全部使用 **Swift Testing**（`import Testing`、`@Test`、`#expect`），**禁用 XCTest**
- 每個測試 function name 對應 scenarios.md 的 scenario title（可從 doc grep 到 test 反之亦然）

## 驗收條件（Feature 1 整體完成）

- `swift test` 全綠：39 個新測試、0 failing、0 skipped
- Domain 零框架依賴（grep 無 `import SwiftUI` / `import Combine` / `import Supabase`）
- 所有 ViewModel 都是 `@Observable`、無 `ObservableObject` + `@Published`
- Repository 走 protocol 注入：grep 確認 ViewModel / Usecase 無直接 `new InMemoryScheduleRepository()`
- String Catalog 三語完整（zh-Hant / en / ja 每個 key 都有翻譯）
- 開 Xcode 跑 app：可建立 schedule、可加 / 刪 window、錯誤狀態正確顯示
- Relaunch app：list 回到空（驗證 in-memory 契約）
