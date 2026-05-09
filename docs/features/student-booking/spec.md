# 學生預約時段 — Spec

> Phase 3b Slice 1 of Shared-Schedule
> 學生在加入的 schedule 上預約 1-on-1 時段、可取消、看見自己已預約的 slot

## Why

Phase 3a 結束時，學生已經能 redeem 邀請碼、加入 schedule、進到
calendar 看見當日 slot 列表——但 row **不可點**。學生看得到、卻什麼
都做不了，是 learner journey 的最後一道斷層。

Phase 3b 解決這個斷層：把 row 變可點、加上 server 端的衝突偵測、讓
學生能取消自己的預約、在 calendar 上一眼看出哪些是自己的。完成後
私人課場景的最小可用閉環就跑通了。

不含：他人預約的可見性（Slice 2），手動 `AvailabilityWindow` 預約
（post-MVP backlog，見 `docs/features/booking-manual-windows/`）。

## What

### 新增的概念

- **Booking**：學生 ↔ schedule slot 的單筆預約，1-on-1 模型
  - 透過 `(schedule_id, starts_at)` UNIQUE 強制唯一
  - 落 row 時 snapshot 當下的 lesson duration（`duration_seconds`），
    防 teacher 日後改 `minWindowDuration` 後跟 ComputedSlot 對不齊
  - **Hard-delete 取消**：取消 = `DELETE`，slot 即時釋放（無 audit
    歷史；若日後要 audit 是 ~30 行 partial-unique-index 遷移）

### Teacher 可以做的事

- 看見學生在自己 schedule 上的 booking（owner branch；無 booking 按鈕）
- 不能對自己 schedule 預約（client `isOwner` 隱藏按鈕；server RPC 兜底
  `OWNER_CANNOT_BOOK`）

### Student 可以做的事

- 在 calendar 點 available 的 slot row → 確認 sheet「確定預約 09:00–10:00？」
  → 確認後 row 變身為「✓ 已預約 [取消預約]」
- 點「取消預約」→ 確認 alert → 預約消失、row 退回 available
- 切月份 / 重進 calendar，已預約 slot 維持「已預約」標記
- 同一 slot 被別人占走時：點 → server 回 `SLOT_TAKEN` → inline error
  「已被預約，請選其他時段」（Slice 2 之後會在 UI 預先 disable）

## 不做的事（Out of Scope）

Slice 1 **不含**以下項目：

- **跨 student 可見性**（看到他人 booking 為 time-only）→ Slice 2
- **AvailabilityWindow-based booking** → backlog
- **Booking notification（email / push）** → Phase 4+
- **Cancel time-cutoff 商業規則**（例如「24 小時前才能取消」）→ Phase 4+
- **Booking history / audit trail** → Phase 4+（hard-delete 改 soft-delete）
- **Group class（capacity > 1）** → 不在 roadmap
- **Teacher 主動取消學生 booking** → Phase 4+
- **Booking reschedule（直接改時間）** → Phase 4+；MVP 用「先取消再預約」
- **Booking reminder / 行事曆匯出（ICS）** → Phase 4+
- **Member leave / kick** → Phase 4+

## Permissions

| 角色 | 可做 | 不可做 |
|---|---|---|
| Schedule owner（teacher） | 看自己 schedule 上的所有 booking（含學生身分）；既有 schedule / invitation 編輯 | 對自己 schedule 預約（client UI 隱藏 + server RPC `OWNER_CANNOT_BOOK`） |
| Member（student） | 預約自己加入 schedule 上的未來 slot；fetch 自己的 booking；取消自己未開始的 booking | 看他人 booking（Slice 1 RLS 不開）；取消他人 booking（RPC `NOT_OWNER`）；預約過去 slot（RPC `PAST_SLOT`）；預約已被佔走的 slot（RPC `SLOT_TAKEN`） |
| 非 member、非 owner | 無法 SELECT bookings（RLS 阻擋） | 預約：RPC `NOT_MEMBER` |

權限執行位置：
- **Domain 層**：不處理 authorization；`Booking.init` 只擋語意 invariant
- **Usecase 層**：fail-fast 預檢（owner、past、slotNotInSchedule）給出
  描述性錯誤；非權威
- **Backend RLS**：booking SELECT 的 source of truth（`self_or_owner_select`）
- **Backend RPC**：`book_slot()` / `cancel_booking()` SECURITY DEFINER
  函式，做原子的 auth + 業務規則 + INSERT/DELETE

## User Flow

### Student 預約時段

```
ScheduleListView「我加入的」section
  ↓ 點某份 schedule row
ScheduleCalendarView
  ↓ 點某天的 row
DaySlotListView 顯示當日 slots（rule-derived ComputedSlot）
  ↓ 點某個 available slot row
.confirmationDialog「確定預約 09:00–10:00？」
  ↓ 按「預約這個時段」
viewModel.bookSlot(slot)
  → CreateBookingUseCase.createBooking
    → 預檢：scheduleNotFound / ownerCannotBook / slotInPast / slotNotInSchedule
    → SupabaseBookingRepository.create
      → book_slot RPC：auth → range → past → owner → member → INSERT
        → 成功：回傳 booking row
        → unique_violation → SLOT_TAKEN → mapper → .slotTaken
  ↓ 成功
row 變身「✓ 已預約 [取消預約]」、myBookings 多一筆
  ↓ 失敗（.slotTaken 等）
inlineError 顯示「已被預約，請選其他時段」
```

### Student 取消預約

```
DaySlotListView mineBooked row
  ↓ 點「取消預約」
.alert「確定取消這筆預約？」
  ↓ 按「取消預約」（destructive）
viewModel.cancelBooking(bookingID)
  → CancelBookingUseCase.cancelBooking
    → SupabaseBookingRepository.cancel
      → cancel_booking RPC：auth → ownership → not-yet-started → DELETE
        → 成功：void
        → SLOT_STARTED → .slotAlreadyStarted
        → NOT_OWNER → .notOwner
  ↓ 成功
row 退回 available、myBookings 少一筆
  ↓ 失敗
inlineError「這個時段已開始，無法取消」
```

### Owner 進入自己 schedule 的 calendar

```
ScheduleCalendarView（既有 isOwner === true）
  → DaySlotListView 用 interactive: false
  → row 不可點（Button disabled），無 confirmation flow
  → toolbar 仍顯示「邀請學生」按鈕（既有 owner-only）
```
