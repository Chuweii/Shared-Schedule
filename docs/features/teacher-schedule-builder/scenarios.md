# 老師建立 Schedule 並新增可預約時段 — Scenarios

> Feature 1 canonical BDD spec。每個 scenario 對應一個測試，測試 function name 必須與 scenario title 可以 grep 對應。
> 本檔是 TDD 的輸入源。寫測試前請先讀對應章節。

## Description

本檔記錄 Feature 1 的所有 39 個 scenarios，分成三組：

- **Domain (17)** — `Schedule` aggregate 的不變條件，Sub-phase 1a 實作
- **Sub-phase 1b (10)** — 建立 Schedule flow 的 Usecase 與 ViewModel
- **Sub-phase 1c (12)** — 編輯 Window flow 的 Usecase 與 ViewModel

## Permission

Teacher（Phase 1 為 hardcoded `teacher-001`）。

---

# Domain — `Schedule` aggregate

## 建立 Schedule

### Scenario: 以預設最短時段長度建立空 Schedule

```
Given 老師 id 為 teacher-001
And 未指定 minWindowDuration
When 建立 Schedule
Then 成功
And 新 Schedule 的 minWindowDuration == 3600 秒（60 分鐘）
And 新 Schedule 的 windows 為空
```

### Scenario: 以自訂最短時段長度建立空 Schedule

```
Given 老師 id 為 teacher-001
And 指定 minWindowDuration 為 1800 秒（30 分鐘）
When 建立 Schedule
Then 成功
And 新 Schedule 的 minWindowDuration == 1800 秒
And 新 Schedule 的 windows 為空
```

---

## 新增 Window — 成功路徑

### Scenario: 新增合法 window 到空 Schedule

```
Given 一份空 Schedule（minWindowDuration 為 60 分鐘）
When 呼叫 addWindow，start=14:00、end=15:00
Then 不 throw
And Schedule 的 windows 數量為 1
And windows[0].start == 14:00
And windows[0].end == 15:00
```

### Scenario: 新增接在既有 window 後方的 window（touching-after）

```
Given 一份 Schedule，minWindowDuration 為 60 分鐘
And 該 Schedule 已有一個 14:00-15:00 的 window
When 呼叫 addWindow，start=15:00、end=16:00
Then 不 throw
And Schedule 的 windows 數量為 2
And 邊界相碰不算 overlap
```

### Scenario: 新增接在既有 window 前方的 window（touching-before）

```
Given 一份 Schedule，minWindowDuration 為 60 分鐘
And 該 Schedule 已有一個 14:00-15:00 的 window
When 呼叫 addWindow，start=13:00、end=14:00
Then 不 throw
And Schedule 的 windows 數量為 2
```

### Scenario: 新增恰好等於最短時段長度的 window

```
Given 一份 Schedule，minWindowDuration 為 1800 秒（30 分鐘）
When 呼叫 addWindow，start=14:00、end=14:30（恰好 30 分鐘）
Then 不 throw
And Schedule 的 windows 數量為 1
And 最短長度邊界恰好通過
```

---

## 新增 Window — Range 錯誤

### Scenario: 新增 start 等於 end 的 window

```
Given 一份空 Schedule
When 呼叫 addWindow，start=14:00、end=14:00
Then throws ScheduleError.invalidRange
And Schedule 的 windows 仍為空
```

### Scenario: 新增 start 晚於 end 的 window

```
Given 一份空 Schedule
When 呼叫 addWindow，start=15:00、end=14:00
Then throws ScheduleError.invalidRange
And Schedule 的 windows 仍為空
```

---

## 新增 Window — 長度錯誤

### Scenario: 新增短於最短時段長度的 window

```
Given 一份 Schedule，minWindowDuration 為 60 分鐘
When 呼叫 addWindow，start=14:00、end=14:59（59 分鐘）
Then throws ScheduleError.belowMinimumDuration
And Schedule 的 windows 仍為空
```

---

## 新增 Window — 重疊錯誤

### Scenario: 新增與既有 window 部分重疊於右的 window

```
Given 一份 Schedule，已有一個 14:00-15:00 的 window
When 呼叫 addWindow，start=14:30、end=15:30
Then throws ScheduleError.overlapping
And Schedule 的 windows 仍只有 1 個
```

### Scenario: 新增與既有 window 部分重疊於左的 window

```
Given 一份 Schedule，已有一個 14:00-15:00 的 window
When 呼叫 addWindow，start=13:30、end=14:30
Then throws ScheduleError.overlapping
And Schedule 的 windows 仍只有 1 個
```

### Scenario: 新增完全包在既有 window 內部的 window

```
Given 一份 Schedule，已有一個 14:00-15:00 的 window
When 呼叫 addWindow，start=14:15、end=14:45
Then throws ScheduleError.overlapping
And Schedule 的 windows 仍只有 1 個
```

### Scenario: 新增完全包住既有 window 的 window

```
Given 一份 Schedule，已有一個 14:15-14:45 的 window
When 呼叫 addWindow，start=14:00、end=15:00
Then throws ScheduleError.overlapping
And Schedule 的 windows 仍只有 1 個
```

### Scenario: 新增與既有 window 時間完全相同的 window

```
Given 一份 Schedule，已有一個 14:00-15:00 的 window
When 呼叫 addWindow，start=14:00、end=15:00
Then throws ScheduleError.overlapping
And Schedule 的 windows 仍只有 1 個
```

---

## 移除 Window

### Scenario: 刪除既有 window

```
Given 一份 Schedule，已有一個 windowID 為 W1 的 window
When 呼叫 removeWindow(id: W1)
Then 不 throw
And Schedule 的 windows 為空
```

### Scenario: 刪除不存在的 window id

```
Given 一份空 Schedule
When 呼叫 removeWindow(id: 任一 UUID)
Then 不 throw（no-op 契約）
And Schedule 的 windows 仍為空
```

### Scenario: 刪除 window 後以相同時段重新加入

```
Given 一份 Schedule，已有一個 14:00-15:00 的 window（id = W1）
When 呼叫 removeWindow(id: W1)
And 再呼叫 addWindow，start=14:00、end=15:00
Then 第二次呼叫不 throw
And Schedule 的 windows 數量為 1
And 證明 remove 真的釋放 slot，不是隱藏
```

---

# Sub-phase 1b — 建立 Schedule Flow

## `CreateScheduleUsecase`

### Scenario: 以有效 title 與最短時段長度建立 Schedule

```
Given currentUserProvider.currentUser.id == teacher-001
And 輸入 title "瑜珈初階"
And 輸入 minWindowDuration 為 60 分鐘
When 呼叫 CreateScheduleUsecase.execute
Then repository 中有一筆新 Schedule
And 新 Schedule 的 ownerID == teacher-001
And 新 Schedule 的 title == "瑜珈初階"
And 新 Schedule 的 minWindowDuration == 60 分鐘
```

### Scenario: 以空白 title 建立 Schedule

```
Given currentUserProvider.currentUser.id == teacher-001
And 輸入 title 為空字串 ""
When 呼叫 CreateScheduleUsecase.execute
Then throws CreateScheduleError.blankTitle
And repository 無新增
```

---

## `ListSchedulesUsecase`

### Scenario: Repository 為空時查詢

```
Given repository 不含任何 Schedule
When 以 teacher-001 身份呼叫 ListSchedulesUsecase.execute
Then 回傳空陣列 []
```

### Scenario: Repository 含跨 owner 的多份 schedule 時查詢

```
Given repository 包含以下 3 份 Schedule：
  - Schedule A, ownerID = teacher-001
  - Schedule B, ownerID = teacher-001
  - Schedule C, ownerID = teacher-002
When 以 teacher-001 身份呼叫 ListSchedulesUsecase.execute
Then 回傳包含 Schedule A 與 Schedule B 的陣列
And 不包含 Schedule C
```

---

## `ScheduleListViewModel`

### Scenario: onAppear 載入空 repository

```
Given repository 為空
And ScheduleListViewModel 剛建立
When 呼叫 onAppear()
Then state.schedules == []
And state.inlineError == nil
```

### Scenario: onAppear 載入既有 1 份 schedule

```
Given repository 已有 1 份 teacher-001 的 Schedule
And ScheduleListViewModel 剛建立
When 呼叫 onAppear()
Then state.schedules.count == 1
```

### Scenario: 輸入有效 title 並送出建立

```
Given ScheduleListViewModel onAppear 完成
And 使用者開啟 create sheet（isCreateSheetPresented == true）
And 使用者輸入 title "瑜珈初階"
And 使用者使用預設 minWindowDuration（60 分鐘）
When 呼叫 didConfirmCreate()
Then state.schedules 多一筆，title == "瑜珈初階"
And state.isCreateSheetPresented == false（sheet 關閉）
And state.inlineError == nil
```

### Scenario: 輸入空白 title 並送出

```
Given ScheduleListViewModel 的 create sheet 開啟
And 使用者輸入 title 為空字串 ""
When 呼叫 didConfirmCreate()
Then state.inlineError == .blankTitle
And state.isCreateSheetPresented == true（sheet 仍開啟）
And state.schedules 無變化
```

### Scenario: 輸入純空白字元 title 並送出

```
Given ScheduleListViewModel 的 create sheet 開啟
And 使用者輸入 title 為 "   "（全部是空格）
When 呼叫 didConfirmCreate()
Then state.inlineError == .blankTitle（trim 後視為空）
And state.isCreateSheetPresented == true
And state.schedules 無變化
```

### Scenario: 有錯誤狀態後修正 title 重送

```
Given ScheduleListViewModel 的 create sheet 開啟
And 使用者先前輸入空白 title 導致 state.inlineError == .blankTitle
When 使用者修正 title 為 "瑜珈初階"
And 再呼叫 didConfirmCreate()
Then state.inlineError == nil（錯誤清空）
And state.schedules 多一筆新 schedule
And state.isCreateSheetPresented == false
```

---

# Sub-phase 1c — 編輯 Window Flow

## `AddAvailabilityWindowUsecase`

### Scenario: Owner 送出合法 window

```
Given repository 中有一份 Schedule，ownerID == teacher-001，minWindowDuration == 60 分鐘
And currentUserProvider.currentUser.id == teacher-001
When 呼叫 AddAvailabilityWindowUsecase.execute(scheduleID: 該 schedule id, start=14:00, end=15:00)
Then 不 throw
And repository 中那份 Schedule 多一個 14:00-15:00 的 window
```

### Scenario: 非 owner 嘗試送出 window

```
Given repository 中有一份 Schedule，ownerID == teacher-001
And currentUserProvider.currentUser.id == teacher-002
When 呼叫 AddAvailabilityWindowUsecase.execute(scheduleID: 該 schedule id, start=14:00, end=15:00)
Then throws ScheduleMutationError.notOwner
And repository 中那份 Schedule 無變化
```

### Scenario: 對不存在的 scheduleID 嘗試送出 window

```
Given repository 不含任何 Schedule
And currentUserProvider.currentUser.id == teacher-001
When 呼叫 AddAvailabilityWindowUsecase.execute(scheduleID: 不存在的 id, start=14:00, end=15:00)
Then throws ScheduleMutationError.scheduleNotFound
```

---

## `RemoveAvailabilityWindowUsecase`

### Scenario: Owner 移除既有 windowID

```
Given repository 中有一份 Schedule，ownerID == teacher-001，含一個 windowID 為 W1 的 window
And currentUserProvider.currentUser.id == teacher-001
When 呼叫 RemoveAvailabilityWindowUsecase.execute(scheduleID: 該 schedule id, windowID: W1)
Then 不 throw
And repository 中那份 Schedule 不再含 windowID == W1 的 window
```

### Scenario: 非 owner 嘗試移除 window

```
Given repository 中有一份 Schedule，ownerID == teacher-001，含一個 windowID 為 W1 的 window
And currentUserProvider.currentUser.id == teacher-002
When 呼叫 RemoveAvailabilityWindowUsecase.execute(scheduleID: 該 schedule id, windowID: W1)
Then throws ScheduleMutationError.notOwner
And repository 中那份 Schedule 無變化
```

---

## `ScheduleDetailViewModel`

### Scenario: onAppear 進入有 2 windows 的 schedule

```
Given repository 中有一份 Schedule 含 2 個 windows
And ScheduleDetailViewModel 以該 scheduleID 建立
When 呼叫 onAppear()
Then state.schedule.windows.count == 2
And state.inlineError == nil
```

### Scenario: 送出合法 window

```
Given ScheduleDetailViewModel onAppear 完成、schedule 為空 windows
And 使用者開啟 add window sheet
And 使用者選擇 start=14:00、end=15:00
When 呼叫 didConfirmAddWindow()
Then state.schedule.windows.count == 1
And state.isAddWindowSheetPresented == false
And state.inlineError == nil
```

### Scenario: 送出 overlapping window

```
Given ScheduleDetailViewModel 的 schedule 已有一個 14:00-15:00 的 window
And 使用者開啟 add window sheet
And 使用者選擇 start=14:30、end=15:30
When 呼叫 didConfirmAddWindow()
Then state.inlineError == .overlapping
And state.isAddWindowSheetPresented == true（sheet 仍開啟）
And state.schedule.windows.count 仍為 1
```

### Scenario: 送出低於最短長度的 window

```
Given ScheduleDetailViewModel 的 schedule minWindowDuration == 60 分鐘
And 使用者開啟 add window sheet
And 使用者選擇 start=14:00、end=14:59（59 分鐘）
When 呼叫 didConfirmAddWindow()
Then state.inlineError == .belowMinimumDuration
And state.isAddWindowSheetPresented == true
And schedule.windows 無變化
```

### Scenario: 送出 end 早於 start 的 window

```
Given ScheduleDetailViewModel 的 schedule 為空 windows
And 使用者開啟 add window sheet
And 使用者選擇 start=15:00、end=14:00
When 呼叫 didConfirmAddWindow()
Then state.inlineError == .invalidRange
And state.isAddWindowSheetPresented == true
```

### Scenario: 有錯誤狀態後修正並重送合法 window

```
Given ScheduleDetailViewModel 之前送出錯誤 window 導致 state.inlineError 被設定
And 使用者仍在 add window sheet 內
When 使用者修正時間為合法值（如 15:00-16:00）
And 再呼叫 didConfirmAddWindow()
Then state.inlineError == nil
And state.schedule.windows.count 增加 1
And state.isAddWindowSheetPresented == false
```

### Scenario: 點擊刪除指定 windowID

```
Given ScheduleDetailViewModel 的 schedule 含 1 個 windowID 為 W1 的 window
When 呼叫 didTapDelete(windowID: W1)
Then state.schedule.windows 不再含 windowID == W1 的 window
And state.schedule.windows 為空
```

---

## 測試 function name 對應

Sub-phase 1a 開始時，每個上述 scenario 將對應一個 Swift Testing `@Test` function。命名格式為 camelCase、描述完整（可從中 grep 到上面的 scenario title）：

```swift
@Test("以預設最短時段長度建立空 Schedule")
func createEmptySchedule_withDefaultMinWindowDuration_succeeds() { ... }

@Test("新增與既有 window 部分重疊於右的 window 應 throw overlapping")
func addWindow_partialOverlapRight_throwsOverlapping() { ... }
```

Test 名稱以 `@Test("中文 scenario title")` 為準，function name 輔助。
