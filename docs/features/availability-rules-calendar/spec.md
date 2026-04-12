# 月曆式課表管理 + 可預約時段規則 — Spec

> Feature 2 of Shared-Schedule
> Phase 1 — Mock（不接 Supabase、不做 Auth、不做 booking）

## Why

Feature 1 讓老師可以手動新增 AvailabilityWindow（用 DatePicker 選 start/end），但這個操作不直覺——老師的心智模型是「我每週一到五、上午 9 點到下午 6 點可以上課」，不是「我 2026/4/14 14:00-15:00 可以上課」。

Feature 2 引入 **AvailabilityRule**（可預約時段規則）和**月曆視圖**，讓老師：
1. 建立課表時設定「哪幾天、幾點到幾點」的通用規則
2. 在月曆上看到哪些日子有可預約時段、哪些沒有
3. 點擊日期看到系統自動根據 minWindowDuration 切割出的 slot 列表

## What

### 新增的概念

- **AvailabilityRule**：一條規則代表「每個〔星期幾〕的〔幾點〕到〔幾點〕」
- **ComputedSlot**：系統根據 Rule + minWindowDuration 自動切割出的等長 slot（不持久化）

### 老師可以做的事

- 建立課表時選擇 weekdays（如週一至五）+ 開始/結束時間（如 9:00-18:00），系統自動對每個選中的 weekday 建一條 rule
- 看到提示「建立後可針對每天細調」（細調功能 defer 到 Feature 3）
- 進入某份課表 → 看到月曆視圖
  - 有 rule 的日期有標記（如彩色 dot）
  - 沒有 rule 的日期反灰、不可點擊
  - 可切換月份
- 點擊有 rule 的日期 → 看到當天自動生成的 slot 列表
  - 例如 rule=9-18, minDuration=60 → [9-10, 10-11, ..., 17-18]

### Slot 生成規則

- 從 rule.startTime 開始，每隔 minWindowDuration 切一格
- 一直切到 rule.endTime 為止
- 最後如果剩餘時間 < minWindowDuration → 捨棄（不夠一個 slot）
- Phase 1 所有 slot 狀態都是「可預約」（沒有學生、沒有 booking）

## 不做的事（Out of Scope）

- 逐天細調規則（per-day override）→ Feature 3
- 每天多條規則（午休場景）→ Feature 3
- 週視圖 / 日視圖 → roadmap
- 跨日規則（18:00-09:00 隔天）→ 不允許
- 學生 booking / slot 狀態變化 → Phase 3
- 刪除 Feature 1 的 AvailabilityWindow / Detail 程式碼 → 保留備用

## Permissions

同 Feature 1：Phase 1 hardcoded teacher-001，無 student。

## User Flow

```
啟動 app → 我的課表 list
  ↓
按「＋新增課表」
  ↓
CreateScheduleSheet（改版）
  ├─ 課表名稱（同 Feature 1）
  ├─ 最短時段長度（同 Feature 1）
  ├─ 【新增】可預約日期：weekday 多選（一至日）
  ├─ 【新增】可預約時間：start time picker + end time picker
  └─ 【新增】Hint：「建立後可針對每天細調」
  ↓
按「建立」→ 回到 list
  ↓
點擊 list 中的課表
  ↓
【取代 ScheduleDetailView】→ 月曆視圖（ScheduleCalendarView）
  ├─ 月份標題 + 前後月按鈕
  ├─ 7 × 6 grid（日一二三四五六）
  ├─ 有 rule 的日期：彩色 dot
  ├─ 沒 rule 的日期：反灰
  └─ 今天高亮
  ↓
點擊有 rule 的日期
  ↓
Day Slot List（push 或 expand）
  ├─ 日期標題
  ├─ 自動生成的 slot 列表
  └─ 每個 slot 顯示時段（如 09:00 — 10:00）
```

## Scenarios 摘要

完整 Given / When / Then 見 [scenarios.md](./scenarios.md)。

### Domain — TimeOfDay (3)

| # | Scenario | 結果 |
|---|---|---|
| 1 | 建立有效 TimeOfDay | 成功 |
| 2 | hour 超過 23 | throw |
| 3 | minute 超過 59 | throw |

### Domain — AvailabilityRule on Schedule (6)

| # | Scenario | 結果 |
|---|---|---|
| 4 | 新增有效 rule | 成功 |
| 5 | startTime >= endTime | throws `.invalidRange` |
| 6 | rule duration < minWindowDuration | throws `.ruleTooShort` |
| 7 | 同 weekday 重複加 rule | throws `.ruleOverlapping` |
| 8 | 不同 weekday 各加 rule | 成功 |
| 9 | 刪除 rule | 成功 |

### Domain — computedSlots (6)

| # | Scenario | 結果 |
|---|---|---|
| 10 | 9-18 minDur=60 | 9 slots |
| 11 | 9-12 minDur=90 | 2 slots |
| 12 | 9-10 minDur=90 | 0 slots |
| 13 | 無 rule 的 weekday | 空 |
| 14 | slot 含完整日期 | Date 正確 |
| 15 | 注入 Calendar 驗證 | weekday 正確 |

### UseCase + ScheduleListViewModel (6)

| # | Scenario | 結果 |
|---|---|---|
| 16 | 建立 Schedule 帶 rules | repo 有 N 條 rules |
| 17a | 建立 Schedule 不傳 ruleTemplate | throws `.noWeekdaysSelected` |
| 17b | 建立 Schedule 帶空 weekdays set | throws `.noWeekdaysSelected` |
| 18 | VM create 帶 rules | schedule 有 rules |
| 19 | VM create 不選 weekday | inline error、sheet 不關 |
| 20 | list row 顯示 rule 摘要 | 有 weekday + time |
| 21 | 建立後 state 重設 | weekdays/time 歸預設 |

### Calendar ViewModel (5)

| # | Scenario | 結果 |
|---|---|---|
| 22 | onAppear | 當月日期矩陣 |
| 23 | 選有 rule 的日期 | 有 slots |
| 24 | 選沒 rule 的日期 | 無 slots |
| 25 | 切上月 | 矩陣更新 |
| 26 | 切下月 | 矩陣更新 |

**合計 26 個新測試**

## Technical Notes

### Domain 擴充
- `TimeOfDay` 和 `Weekday` 放在 `Domain/Shared/`——這是第一次用到 Shared 資料夾
- `Weekday` 自建 enum（不用 Foundation），mapping 放 extension
- `computedSlots(for:calendar:)` 參數化注入 Calendar，避免測試時區抖動
- `ScheduleError` 新增 `.ruleOverlapping` / `.ruleTooShort`
- Schedule.init 新增 `rules: [AvailabilityRule] = []`

### Feature 1 程式碼處理
- AvailabilityWindow、AddWindowSheet、ScheduleDetailView、相關 UseCase 全部保留不動
- ScheduleListView 的 NavigationLink 從指向 ScheduleDetailView 改成 ScheduleCalendarView
- Feature 1 的 40 個 tests 必須仍然全綠（zero regression）

### 月曆元件
- 自建 SwiftUI LazyVGrid（7 columns）
- 不引入第三方依賴
- 用 theme semantic colors
