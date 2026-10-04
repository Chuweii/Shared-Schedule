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

---

## Slice 2 — 跨 student 可見性（2026-05-10 加入）

### Why

Slice 1 完成後 member-vs-member 之間互盲：學生 B 看不到學生 C 已佔用
的 slot，唯一感知途徑是預約後被 RPC 回 `SLOT_TAKEN` 報錯——多餘的
confirmation alert + 錯誤閃。學生也看不到「忙日 vs 空日」的視覺密
度，無從預測搶課。

Slice 2 解：calendar slot list 上把「他人已預約」的 row 渲染成灰底、
disabled、`時段 — 已被預約`。tap 直接無反應、不發 RPC。

### What

#### 新增的概念

- **BookedSlot**（Domain VO）：sanitized 的「已被預約時段」表示，僅含
  `(startsAt, endsAt, durationSeconds)`，**無 booking_id / student_id /
  email**——型別系統就擋掉「不小心拿這個 row 去 cancel」或「不小心
  log/render student email」的 bug。
- **`SlotPresentationState.bookedByOther`** case：student 視角，無
  payload。owner 視角仍用既有 `bookedByStudent(email:)`（Slice 1.5）。

#### Student 可以做的事（增量）

- 進 calendar 立即看到他人已預約的 slot 為灰底「已被預約」row、tap
  完全無反應。
- 不再走「點下去 → confirmation → SLOT_TAKEN」的失敗路徑。

### Permissions（增量）

| 角色 | 可做（Slice 2 新增） | 不可做 |
|---|---|---|
| Member（student） | 透過新 RPC `get_bookings_visible_to_member` 看到同 schedule 上他人預約的時段範圍（time-only）、不含他人身分 | 看到他人 student_id / email / booking_id（RPC return signature 預先限縮三欄） |
| Schedule owner（teacher） | 不變——仍走 `get_bookings_for_owner` 含 email | RPC `get_bookings_visible_to_member` 對 owner 回 `NOT_MEMBER`、owner 應走 owner path |

### 為什麼 RLS 不直接 OR-add `is_member_of_schedule(...)`

Slice 1 plan 草稿曾提過此方向。Slice 2 plan-mode 複盤後改採 RPC-only：

- OR-add 會讓 `bookings?select=*` 直接回完整 row，PostgREST 不像
  Postgres view 能 column-level mask。要避免 PII 還得另加 view /
  function 包裝；那就乾脆只加 RPC、不動 base table RLS。
- base table RLS 收緊代表將來任何路徑都得明確走 RPC、少一條「不小心
  打開」的洞。
- audit story 簡單：要審查「member 還能看到什麼」只看一個 RPC
  migration 檔案。

### User Flow（Slice 2 增量）

```
ScheduleCalendarView onAppear（非 owner 分支）
  → loadMyBookings (既有)
  → loadOthersBookings ← 新
    → ListOthersBookingsUseCase.listOthersBookings
      → SupabaseBookingRepository.fetchOthersBookings
        → get_bookings_visible_to_member RPC：
            auth → member → SELECT sanitized rows
        → 失敗：silent（同 loadMyBookings；不污染 inlineError）
  → presentedSlotsForSelectedDate 解析優先序：
    mineBooked > bookedByOther > available
```

bookedByOther row：無 tap callback、無 button。`onTapAvailable` 只接
`available` row、`onTapCancel` 只接 `mineBooked` row——bookedByOther
的 tap 不路由到任何 action。

### Out of Scope（Slice 2 不做、但設計上不堵）

- Teacher 主動取消學生 booking → Phase 4+；純 backend 改 cancel_booking
  RPC、不影響本 slice
- Group-class capacity > 1 → 不在 roadmap；新 RPC 回 row-list（非
  boolean）+ `BookedSlot` 不含 id 都已為此鋪好
- Real-time 同步（websocket）→ Phase 4+；目前 polling-on-appear
- 「有多少 slot 可預約」的密度 badge → Phase 4+
- Reschedule（直接改時間）→ Phase 4+；MVP 用「先取消再預約」

---

## Slice 3 — 預約狀態刷新（2026-10-04 加入）

### Why

手動 e2e 發現：學生預約了老師的課，老師停在課表頁上看不到這筆新預約，
要退出再進來才會出現。原因是 calendar 只在進頁面時載入一次預約資料
（polling-on-appear），之後沒有任何重新載入的途徑。學生端同理：停在
畫面上看不到別人剛訂走的時段、也看不到別人剛取消而釋出的時段。

### What

三種刷新方式，皆只重新載入**預約狀態**，後端、RLS、Usecase 都不變：

| 方式 | 觸發 | 失敗時 |
|---|---|---|
| 下拉刷新 | 使用者在課表頁往下拉 | 保留原畫面，顯示「無法更新預約狀態，請稍後再試」 |
| 回前景自動刷新 | App 從背景切回前景且停在課表頁 | 靜默（與進頁面載入一致，不打擾） |
| 搶位失敗自動刷新 | 學生預約時收到「已被預約」 | 靜默；錯誤訊息仍是「已被預約，請選其他時段」 |

老師與學生兩種視角都適用（老師刷新 owner bookings；學生刷新自己的與
他人的 bookings）。下拉刷新成功會清掉畫面上殘留的舊錯誤提示。

### 不做的事（Out of Scope）

- **即時推播（Supabase Realtime）**：需新增 `Realtime` package
  product（專案設定變更）；且學生依 RLS 讀不到他人 bookings row，
  `postgres_changes` 推不到學生端，需另行設計 broadcast。等上架後有
  實際需求再評估。
- **定時輪詢**：耗電、API 次數多；下拉＋回前景已涵蓋主要情境。
- **刷新課表本身（老師修改規則）**：schedule 是進頁面時帶入的值物件，
  本 slice 只刷新預約狀態。

### Scenarios 摘要

完整 Given / When / Then 見 [`scenarios.md`](scenarios.md#slice-3-增量2026-10-04-加入)。

| ID | 情境 | 層 |
|---|---|---|
| BCV12 | 老師下拉刷新看到新預約 | ViewModel |
| BCV13 | 學生下拉刷新看到別人的新預約 | ViewModel |
| BCV14 | 學生下拉刷新看到被取消的時段恢復可預約 | ViewModel |
| BCV15 | 下拉刷新失敗時保留原畫面並提示 | ViewModel |
| BCV16 | 下拉刷新成功會清掉舊的錯誤提示 | ViewModel |
| BCV17 | 預約時被搶先，該時段立刻顯示已被預約 | ViewModel |
| RUI1 | App 回前景自動刷新 | 手動 e2e |

### Technical Notes

- `ScheduleCalendarViewModel` 新增 `refresh()`（下拉用，失敗會設
  `inlineError`）；既有 `loadBookings()` 維持靜默語意，供 `onAppear`、
  回前景、搶位失敗使用。
- 各 loader 失敗時**不覆寫**既有資料，所以刷新失敗不會讓畫面變空。
- 回前景：View 以 `@Environment(\.scenePhase)` 觀察，變成 `.active`
  時呼叫 `loadBookings()`。首次進頁面時 scenePhase 已是 `.active`、
  不會觸發，不會與 `.task` 重複載入。
- 已知小限制（接受）：刷新請求在途中時若使用者剛好完成一筆預約，刷新
  結果可能短暫蓋掉這筆，下次刷新即修正。
