# 學生預約時段 — Scenarios

> Phase 3b Slice 1 完整 BDD scenario list（Given / When / Then）。
> 每筆 scenario title 對應一個 `@Test` function；test 名以 camelCase
> 對映（testing.md §2）。代碼前綴：BD = Domain、BC = CreateBooking
> Usecase、BX = CancelBooking Usecase、BL = ListMyBookings Usecase、
> BINT = Infrastructure 整合、BCV = ScheduleCalendarViewModel。

## Domain — Booking（5）

### BD1
**Given** 給 endsAt > startsAt 且 duration_seconds 與時長匹配
**When** 建立 Booking
**Then** 建立成功、所有欄位回填

### BD2
**Given** endsAt == startsAt
**When** 建立 Booking
**Then** throws `.invalidRange`

### BD3
**Given** durationSeconds = 0
**When** 建立 Booking
**Then** throws `.invalidDuration`

### BD4
**Given** 30 分區間但 durationSeconds = 3600
**When** 建立 Booking
**Then** throws `.durationMismatch`

### BD5
**Given** booking 與 ComputedSlot 對齊或 start 相差 2 秒
**When** 呼叫 `matches(_:)`
**Then** 對齊回 true、相差 2 秒回 false

## Usecase — CreateBookingUseCase（10）

> Fakes：`FakeScheduleRepository`、`FakeBookingRepository`、
> `FakeCurrentUserProvider`、`now: () -> Date` 注入。

### BC1
**Given** Member 對自己加入 schedule 上某未來 ComputedSlot
**When** createBooking
**Then** repo.create 被呼叫一次、回傳 booking、durationSeconds = 3600

### BC2
**Given** repo.create 拋 `.notMember`（server-side race）
**When** createBooking
**Then** 透傳 `.notMember`

### BC3
**Given** Owner 對自己 schedule
**When** createBooking
**Then** throws `.ownerCannotBook`、repo 未呼叫（client 預檢）

### BC4
**Given** scheduleID 不存在
**When** createBooking
**Then** throws `.scheduleNotFound`

### BC5
**Given** slot.start 在 now 之前
**When** createBooking
**Then** throws `.slotInPast`、repo 未呼叫

### BC6
**Given** slot 的 (start, end) 不對應任何 ComputedSlot（offset 30 分鐘）
**When** createBooking
**Then** throws `.slotNotInSchedule`、repo 未呼叫

### BC7
**Given** repo.create 拋 `.slotTaken`
**When** createBooking
**Then** 透傳 `.slotTaken`

### BC8
**Given** repo.create 拋 `.persistenceFailure`
**When** createBooking
**Then** 透傳 `.persistenceFailure`

### BC9
**Given** scheduleRepository.fetch 拋一般 Error
**When** createBooking
**Then** throws `.persistenceFailure`

### BC10
**Given** repo.create 拋 `.scheduleNotFound`（server-side race）
**When** createBooking
**Then** 透傳 `.scheduleNotFound`

## Usecase — CancelBookingUseCase（4）

### BX1
**Given** 自己擁有的未來 booking
**When** cancelBooking
**Then** repo.cancel 被呼叫、無錯誤

### BX2
**Given** repo.cancel 拋 `.notOwner`
**When** cancelBooking
**Then** 透傳 `.notOwner`

### BX3
**Given** repo.cancel 拋 `.slotAlreadyStarted`
**When** cancelBooking
**Then** 透傳 `.slotAlreadyStarted`

### BX4
**Given** repo.cancel 拋 `.bookingNotFound` 或 `.persistenceFailure`
**When** cancelBooking
**Then** 各自透傳

## Usecase — ListMyBookingsUseCase（3）

### BL1
**Given** 已加入 schedule、有 0 筆 booking
**When** listMyBookings
**Then** 回傳 `[]`、repo.fetchAll 被呼叫一次

### BL2
**Given** 已加入 schedule、有 2 筆 booking
**When** listMyBookings
**Then** 回傳 2 筆、按 startsAt asc

### BL3
**Given** repo 拋一般 Error
**When** listMyBookings
**Then** throws `.persistenceFailure`

## Infrastructure 整合測試（7，打 local Supabase）

> 沿用 `@Suite(.serialized)` + `requireLocalStack()` + `signIn(email:)`。
> `freshFutureSlot()` 用 UUID-derived entropy 避免並行 simulator clone
> 在 `UNIQUE(schedule_id, starts_at)` 撞車。

### BINT1
**Given** user C（seed 進來的 member）已登入
**When** 對 user A 的 sample schedule 上未來 slot 呼叫 `book_slot`
**Then** 回傳 booking row、欄位正確、DB 多一筆

### BINT2
**Given** 同一 (schedule, starts_at) 已有 booking
**When** 再次呼叫 `book_slot`
**Then** RPC 回 `SLOT_TAKEN` → mapper → `.slotTaken`

### BINT3
**Given** user A（owner）已登入
**When** 對自己 schedule 呼叫 `book_slot`
**Then** RPC 回 `OWNER_CANNOT_BOOK` → `.ownerCannotBook`

### BINT4
**Given** user B（無任何 membership）已登入
**When** 對 user A schedule 呼叫 `book_slot`
**Then** RPC 回 `NOT_MEMBER` → `.notMember`

### BINT5
**Given** user C 已預約一筆
**When** `fetchAll(scheduleID:, studentID: userC.id)`
**Then** 結果含該 booking、mapper 正確還原

### BINT6
**Given** user C 已預約一筆
**When** user C 呼叫 `cancel_booking`
**Then** RPC 成功、row 消失、下次 fetchAll 沒有

### BINT7
**Given** user C 已預約一筆
**When** user B（非 owner、非 member）嘗試 `cancel_booking(thatID)`
**Then** RPC 回 `NOT_OWNER` → `.notOwner`、row 仍可被 user C fetch 到

## ViewModel — ScheduleCalendarViewModel（5）

> Fakes：`FakeListMyBookingsUseCase`、`FakeCreateBookingUseCase`、
> `FakeCancelBookingUseCase`。schedule 有 Monday rule 09:00–18:00、
> 9 個 slot。

### BCV1
**Given** onAppear，listMyBookings 回 0 筆
**When** selectDate(monday)
**Then** 9 個 slot 全 `.available`、myBookings 為空

### BCV2
**Given** onAppear，listMyBookings 回 1 筆對應 09:00 slot
**When** selectDate(monday)
**Then** 09:00 slot 為 `.mineBooked(bookingID)`、其餘 8 個 `.available`

### BCV3
**Given** Fake CreateBookingUseCase 設定為成功回 booking
**When** bookSlot(targetSlot)
**Then** 對應 slot 變 `.mineBooked`、myBookings 多 1、inlineError 清空

### BCV4
**Given** Fake CreateBookingUseCase 設定拋 `.slotTaken`
**When** bookSlot(targetSlot)
**Then** inlineError 設定、slot 維持 `.available`、myBookings 不變

### BCV5
**Given** 已有一筆 mineBooked 的 booking
**When** cancelBooking(bookingID)
**Then** 對應 slot 退回 `.available`、myBookings 少 1、cancel.callCount == 1

## Test 數量總計（Slice 1）

| 層 | 數量 |
|---|---|
| Domain (BD) | 5 |
| Usecase Create (BC) | 10 |
| Usecase Cancel (BX) | 4 |
| Usecase List (BL) | 3 |
| Infrastructure (BINT) | 7 |
| ViewModel (BCV) | 5 |
| **Slice 1 合計** | **34** |

---

## Slice 2 增量（2026-05-10 加入）

> 代碼前綴：BSD = BookedSlot Domain、BO = ListOthersBookings Usecase、
> BINT-V = visibility 整合、BCV8+ = ViewModel cross-student 增量
> （Slice 1.5 已先佔用 BCV6/BCV7 為 owner-mode 測試，Slice 2 從 BCV8
> 起算以免衝突）。

### Domain — BookedSlot（4）

#### BSD1
**Given** endsAt > startsAt 且 duration_seconds 與時長匹配
**When** 建立 BookedSlot
**Then** 建立成功、所有欄位回填

#### BSD2
**Given** endsAt == startsAt
**When** 建立 BookedSlot
**Then** throws `BookingError.invalidRange`

#### BSD3
**Given** durationSeconds = 0
**When** 建立 BookedSlot
**Then** throws `BookingError.invalidDuration`

#### BSD4
**Given** BookedSlot 與 ComputedSlot 對齊或 start 相差 2 秒
**When** 呼叫 `matches(_:)`
**Then** 對齊回 true、相差 2 秒回 false

### Usecase — ListOthersBookingsUseCase（3）

> Fakes：`FakeBookingRepository` 加 `fetchOthersBookingsResult` slot。

#### BO1
**Given** repo.fetchOthersBookings 回 `[]`
**When** listOthersBookings
**Then** usecase 回 `[]`

#### BO2
**Given** repo.fetchOthersBookings 回 2 筆 BookedSlot
**When** listOthersBookings
**Then** usecase 透傳、order 不變

#### BO3
**Given** repo.fetchOthersBookings 拋 `.notMember` 或 `.persistenceFailure`
**When** listOthersBookings
**Then** 各自透傳對應 typed error

### Infrastructure 整合測試（4，打 local Supabase）

> setup 內動態 INSERT user B membership（teardown 復原），user C 仍是
> seed member、不額外動。

#### BINT-V1
**Given** user C 已 book 一筆未來 slot；user B 是 member
**When** user B 呼叫 `get_bookings_visible_to_member`
**Then** 回 1 筆 sanitized row（同 starts_at / ends_at / duration），
DTO **無** student_id / email / booking_id 欄位

#### BINT-V2
**Given** user C 已 book 一筆 slot
**When** user **C 自己**呼叫 `get_bookings_visible_to_member`
**Then** 回 0 筆（RPC 內 `student_id <> auth.uid()` 已篩）

#### BINT-V3
**Given** 一位非 member 的 user（teardown 後的 user B）已登入
**When** 呼叫 `get_bookings_visible_to_member`
**Then** RPC 回 `NOT_MEMBER` → mapper → `.notMember`

#### BINT-V4
**Given** user A（owner、非 member）已登入
**When** 呼叫 `get_bookings_visible_to_member`
**Then** RPC 回 `NOT_MEMBER` → `.notMember`（owner 應走 owner RPC、
此 RPC 不為 owner 設計）

### ViewModel — ScheduleCalendarViewModel 增量（4）

> Fakes 多一個 `FakeListOthersBookingsUseCase`。schedule 仍是 Monday
> rule 09:00–18:00 共 9 個 slot。

#### BCV8
**Given** non-owner、onAppear、listOthersBookings 回 0 筆
**When** selectDate(monday)
**Then** 所有 slot state 仍照 my-bookings 判定（available / mineBooked），
無 .bookedByOther

#### BCV9
**Given** non-owner、onAppear、listOthersBookings 回 1 筆對應 09:00 slot、
myBookings 為空
**When** selectDate(monday)
**Then** 09:00 slot 為 `.bookedByOther`、其餘 8 個 `.available`

#### BCV10
**Given** non-owner、myBookings 與 othersBookings 同時包含 09:00 slot
（race / 不一致狀態）
**When** selectDate(monday)
**Then** 09:00 slot 為 `.mineBooked(bookingID)`（mineBooked 優先；
退化路徑保留 cancel 入口）

#### BCV11
**Given** non-owner、bookSlot 對某 slot 成功、othersBookings 不變
**When** 觀察該 slot state
**Then** 該 slot 變 `.mineBooked`、bookedByOther 不曾出現該 slot

## Test 數量（Slice 2）

| 層 | 數量 |
|---|---|
| Domain (BSD) | 4 |
| Usecase ListOthers (BO) | 3 |
| Infrastructure (BINT-V) | 4 |
| ViewModel (BCV8-11) | 4 |
| **Slice 2 合計** | **15** |

合計（Slice 1 + 2）：49
