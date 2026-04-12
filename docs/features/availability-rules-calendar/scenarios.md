# 月曆式課表管理 + 可預約時段規則 — Scenarios

> Feature 2 canonical BDD spec。每個 scenario 對應一個測試。
> 測試 function name 必須與 scenario title 可以 grep 對應。

## Permission

Teacher（Phase 1 為 hardcoded `teacher-001`）。

---

# Domain — TimeOfDay

### Scenario: 建立有效 TimeOfDay

```
Given hour = 9, minute = 30
When 建立 TimeOfDay
Then 成功
And hour == 9, minute == 30
And totalMinutes == 570
```

### Scenario: hour 超過 23 的 TimeOfDay 應 throw

```
Given hour = 24, minute = 0
When 建立 TimeOfDay
Then throws TimeOfDayError.invalidHour
```

### Scenario: minute 超過 59 的 TimeOfDay 應 throw

```
Given hour = 9, minute = 60
When 建立 TimeOfDay
Then throws TimeOfDayError.invalidMinute
```

---

# Domain — AvailabilityRule on Schedule

### Scenario: 新增有效 rule 到空 Schedule

```
Given 一份空 Schedule（minWindowDuration = 60 分鐘，rules 為空）
When 呼叫 addRule(weekday: .monday, startTime: 09:00, endTime: 18:00)
Then 不 throw
And schedule.rules.count == 1
And rules[0].weekday == .monday
And rules[0].startTime == 09:00
And rules[0].endTime == 18:00
```

### Scenario: 新增 startTime >= endTime 的 rule 應 throw invalidRange

```
Given 一份空 Schedule
When 呼叫 addRule(weekday: .monday, startTime: 18:00, endTime: 09:00)
Then throws ScheduleError.invalidRange
And schedule.rules 仍為空
```

### Scenario: 新增 duration 短於 minWindowDuration 的 rule 應 throw ruleTooShort

```
Given 一份 Schedule（minWindowDuration = 90 分鐘）
When 呼叫 addRule(weekday: .monday, startTime: 09:00, endTime: 10:00)
Then throws ScheduleError.ruleTooShort
And schedule.rules 仍為空
Note: rule 持續 60 分鐘 < minWindowDuration 90 分鐘，生成 0 slot
```

### Scenario: 同一 weekday 已有 rule 時再加一條應 throw ruleOverlapping

```
Given 一份 Schedule 已有 rule (monday 09:00-18:00)
When 呼叫 addRule(weekday: .monday, startTime: 10:00, endTime: 12:00)
Then throws ScheduleError.ruleOverlapping
And schedule.rules.count 仍為 1
```

### Scenario: 不同 weekday 各加一條 rule 應都成功

```
Given 一份空 Schedule
When 呼叫 addRule(weekday: .monday, startTime: 09:00, endTime: 18:00)
And 呼叫 addRule(weekday: .wednesday, startTime: 13:00, endTime: 17:00)
Then 不 throw
And schedule.rules.count == 2
```

### Scenario: 刪除 rule 後 rules 為空

```
Given 一份 Schedule 已有 rule (monday 09:00-18:00, id = R1)
When 呼叫 removeRule(id: R1)
Then schedule.rules 為空
```

---

# Domain — computedSlots

### Scenario: Rule 9-18 minDuration=60 應生成 9 個 slot

```
Given 一份 Schedule（minWindowDuration = 60 分鐘）
And 有 rule (monday 09:00-18:00)
And 目標日期是某個星期一
When 呼叫 computedSlots(for: 該星期一)
Then 回傳 9 個 ComputedSlot
And slots[0] = 09:00-10:00
And slots[1] = 10:00-11:00
And ...
And slots[8] = 17:00-18:00
```

### Scenario: Rule 9-12 minDuration=90 應生成 2 個 slot

```
Given 一份 Schedule（minWindowDuration = 90 分鐘）
And 有 rule (monday 09:00-12:00)
When 呼叫 computedSlots(for: 某個星期一)
Then 回傳 2 個 ComputedSlot
And slots[0] = 09:00-10:30
And slots[1] = 10:30-12:00
```

### Scenario: Rule 9-10 minDuration=90 應生成 0 個 slot

```
Given 一份 Schedule（minWindowDuration = 90 分鐘）
And 有 rule (monday 09:00-10:00)
When 呼叫 computedSlots(for: 某個星期一)
Then 回傳空陣列
Note: 60 分鐘 < 90 分鐘，不夠切一個 slot（addRule 會擋住這個 case
但 computedSlots 本身仍要 handle 邊界值）
```

### Scenario: 查詢沒有 rule 的 weekday 應回傳空

```
Given 一份 Schedule 有 rule (monday 09:00-18:00)
And 目標日期是某個星期三
When 呼叫 computedSlots(for: 該星期三)
Then 回傳空陣列
```

### Scenario: slot 的 start/end 包含完整的年月日

```
Given 一份 Schedule 有 rule (monday 09:00-18:00, minDuration=60)
And 目標日期是 2026-04-13（星期一）
When 呼叫 computedSlots(for: 2026-04-13)
Then slots[0].start 的年月日 == 2026-04-13
And slots[0].start 的時間 == 09:00
And slots[0].end 的時間 == 10:00
```

### Scenario: 注入不同 Calendar 驗證 weekday 解析正確

```
Given 一份 Schedule 有 rule (monday 09:00-18:00)
And 使用 Calendar(identifier: .gregorian) 且 timeZone = UTC
And 目標日期是 UTC 時間的某個星期一
When 呼叫 computedSlots(for: 該日期, calendar: 該 Calendar)
Then 回傳 slot（不是空陣列）
Note: 驗證不依賴 Calendar.current，避免測試因本地時區而失敗
```

---

# Sub-phase 2b — UseCase + ScheduleListViewModel

## CreateScheduleUseCase 擴充

### Scenario: 建立 Schedule 帶 weekdays 與時段規則

```
Given currentUserProvider.currentUser.id == teacher-001
And 輸入 title "瑜珈初階"
And 輸入 minWindowDuration = 60 分鐘
And 選擇 weekdays = [monday, wednesday, friday]
And 選擇 startTime = 09:00, endTime = 18:00
When 呼叫 createSchedule
Then repo 中新 schedule 有 3 條 rules
And rules 的 weekday 分別是 monday, wednesday, friday
And 每條 rule 的 startTime == 09:00, endTime == 18:00
```

### Scenario: 建立 Schedule 不選任何 weekday

```
Given 輸入 title "瑜珈初階"
And weekdays = []（空）
When 呼叫 createSchedule
Then repo 中新 schedule 有 0 條 rules
And schedule 正常建立（合法——老師稍後再設定）
```

## ScheduleListViewModel 擴充

### Scenario: didConfirmCreate 帶 weekdays 與時段 → schedule 有 rules

```
Given ScheduleListViewModel 的 create sheet 開啟
And 使用者輸入 title "瑜珈初階"
And 使用者選擇 weekdays = [monday, friday]
And 使用者設定 startTime = 09:00, endTime = 18:00
When 呼叫 didConfirmCreate()
Then state.schedules 多一筆 schedule
And 該 schedule 有 2 條 rules
And state.isCreateSheetPresented == false
```

### Scenario: didConfirmCreate 不選 weekday → 正常建立、sheet 關閉

```
Given ScheduleListViewModel 的 create sheet 開啟
And 使用者輸入 title "瑜珈初階"
And 使用者未選擇任何 weekday
When 呼叫 didConfirmCreate()
Then state.schedules 多一筆 schedule（0 rules）
And state.isCreateSheetPresented == false
```

### Scenario: 建立後 list row 顯示 rule 摘要

```
Given state.schedules 有一筆 schedule 含 rules [monday, friday] 09:00-18:00
When 顯示 list row
Then row 包含 "週一、週五" 或 "Mon, Fri" 之類的摘要文字
And row 包含 "09:00 — 18:00" 的時段資訊
```

### Scenario: 建立後 state 重設

```
Given didConfirmCreate() 成功建立一筆 schedule
When 檢查 VM 的 create 相關 state
Then selectedWeekdays 回到預設（空 or 全選，依 UX 決定）
And ruleStartTime 回到預設
And ruleEndTime 回到預設
And titleDraft == ""
```

---

# Sub-phase 2c+2d — Calendar ViewModel

### Scenario: onAppear 載入當月日期矩陣

```
Given ScheduleCalendarViewModel 以一份 schedule 建立
And 當前日期為 2026 年 4 月
When 呼叫 onAppear()
Then state.currentMonth == 2026 年 4 月
And state.days 包含 4 月 1 日到 4 月 30 日
And state.days 還包含前後月的填充日（讓 grid 從週日開始）
```

### Scenario: 選擇有 rule 的日期 → computedSlots 有值

```
Given schedule 有 rule (monday 09:00-18:00, minDuration=60)
And 2026-04-13 是星期一
When 呼叫 selectDate(2026-04-13)
Then state.selectedDate == 2026-04-13
And state.selectedDaySlots.count == 9
```

### Scenario: 選擇沒有 rule 的日期 → computedSlots 為空

```
Given schedule 有 rule (monday 09:00-18:00)
And 2026-04-15 是星期三
When 呼叫 selectDate(2026-04-15)
Then state.selectedDaySlots 為空
```

### Scenario: 切換到上個月

```
Given state.currentMonth == 2026 年 4 月
When 呼叫 changeMonth(by: -1)
Then state.currentMonth == 2026 年 3 月
And state.days 更新為 3 月的日期矩陣
```

### Scenario: 切換到下個月

```
Given state.currentMonth == 2026 年 4 月
When 呼叫 changeMonth(by: 1)
Then state.currentMonth == 2026 年 5 月
And state.days 更新為 5 月的日期矩陣
```

---

## 測試 function name 對應

```swift
@Test("建立有效 TimeOfDay")
func createTimeOfDay_valid_succeeds() { ... }

@Test("Rule 9-18 minDuration=60 應生成 9 個 slot")
func computedSlots_9to18_min60_returns9Slots() { ... }

@Test("onAppear 載入當月日期矩陣")
func onAppear_loadsCurrentMonthDays() { ... }
```
