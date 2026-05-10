# 學生預約時段 — API & DB

> Phase 3b Slice 1 backend contract：DB schema、RLS policy、RPC、DTO、
> error code mapping。實際 SQL 在
> `supabase/migrations/20260509000000_add_bookings.sql`。

## DB Schema

```sql
CREATE TABLE bookings (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id       UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  student_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  starts_at         TIMESTAMPTZ NOT NULL,
  ends_at           TIMESTAMPTZ NOT NULL,
  duration_seconds  INTEGER NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at),
  CHECK (duration_seconds > 0),
  UNIQUE (schedule_id, starts_at)
);

CREATE INDEX bookings_schedule_student_idx ON bookings (schedule_id, student_id);
```

### 欄位設計理由

- `UNIQUE(schedule_id, starts_at)`：在固定 `minWindowDuration` 下、
  ComputedSlot 由 `(rule, date, offset)` 唯一決定，等價於
  `(schedule_id, starts_at)`。`ends_at` 不入唯一鍵——它是 starts_at +
  duration 的衍生值，加進去會失去「同 start 不同 end」的擋下能力。
- `duration_seconds`：denormalize 當下的 lesson duration，老師若日後
  改 `minWindowDuration`，已成立的 booking 仍維持當下時長語意。
  Booking.endsAt / Booking.durationSeconds 都是 row 上的 snapshot，
  防呆已內建。
- `created_at` 欄位是 audit 用、目前 UI 沒展示但後續寫 booking 列表時
  方便排序。
- 沒有 `cancelled_at`：MVP hard-delete；日後若要 audit 是 partial
  unique index + 欄位的小遷移。

## RLS

```sql
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self_or_owner_select" ON bookings
  FOR SELECT USING (
    student_id = auth.uid()
    OR is_owner_of_schedule(schedule_id, auth.uid())
  );

-- INSERT / UPDATE / DELETE 沒有 policy，所有 mutation 走 RPC
```

`is_owner_of_schedule(...)` helper 由 Phase 3a migration
（`20260503152719_add_invitations_memberships.sql` lines 50-73）
建立、SECURITY DEFINER bypass RLS。本 migration 直接重用、不重定義。

Slice 2 採 RPC-only 路徑（**不**改本 policy）：新增
`get_bookings_visible_to_member` RPC 由 SECURITY DEFINER 投影 sanitized
欄位給 member、避免 PostgREST `bookings?select=*` 直接回完整 row 失誤。
詳見本檔末段「Slice 2 — get_bookings_visible_to_member RPC」。

## RPC：book_slot

```sql
book_slot(
  target_schedule_id      UUID,
  target_starts_at        TIMESTAMPTZ,
  target_ends_at          TIMESTAMPTZ,
  target_duration_seconds INTEGER
) RETURNS TABLE(id, schedule_id, student_id, starts_at, ends_at,
                duration_seconds, created_at)
SECURITY DEFINER
```

### 檢查順序（嚴格）

1. `auth.uid() IS NULL` → `RAISE EXCEPTION 'AUTH_REQUIRED'`
2. `target_ends_at <= target_starts_at` → `INVALID_RANGE`
3. `target_duration_seconds <= 0` → `INVALID_DURATION`
4. `target_starts_at <= now()` → `PAST_SLOT`
5. schedule 不存在 → `SCHEDULE_NOT_FOUND`
6. `owner_id == auth.uid()` → `OWNER_CANNOT_BOOK`
7. 非 member → `NOT_MEMBER`
8. INSERT；UNIQUE 衝突由 plpgsql `EXCEPTION WHEN unique_violation`
   捕捉、重 `RAISE EXCEPTION 'SLOT_TAKEN'`

`GRANT EXECUTE TO authenticated`。

### 為什麼 RPC 收 (start, end, duration) 而非 slot_id

ComputedSlot **不持久化**——由 `Schedule.rules` 即時計算，沒有 slot_id
可傳。RPC 收完整三元組由 server 自行做 sanity check。「這個 (start,
end) 真的對應某 ComputedSlot」的檢查留在 client 端 usecase 做（用
`schedule.computedSlots(for:).contains(slot)`）；server 不重做，否則
要在 plpgsql 重做 weekday + rule 展開、重複代碼。

## RPC：cancel_booking

```sql
cancel_booking(target_booking_id UUID) RETURNS VOID
SECURITY DEFINER
```

### 檢查順序

1. `auth.uid() IS NULL` → `AUTH_REQUIRED`
2. booking 不存在 → `BOOKING_NOT_FOUND`
3. `student_id <> auth.uid()` → `NOT_OWNER`
4. `starts_at <= now()` → `SLOT_STARTED`
5. DELETE

## DTO

`App/Infrastructure/Supabase/DTOs/BookingDTO.swift`：

```swift
struct BookingDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let studentId: UUID
    let startsAt: String         // ISO 8601 from TIMESTAMPTZ
    let endsAt: String
    let durationSeconds: Int
    let createdAt: String
}
```

PostgrestClient 的 encoder/decoder 在 `SupabaseClientProvider.swift`
配 `.convertToSnakeCase` / `.convertFromSnakeCase`，camelCase ↔
snake_case 自動轉換。Insert DTO 不需要——insert 走 RPC、由
SupabaseBookingRepository 內部的 private Encodable struct
（`BookSlotParams` / `CancelBookingParams`）攜帶。

## Error Code Mapping

`App/Infrastructure/Supabase/Mappers/BookingMapper.swift`：substring
match `PostgrestError.localizedDescription`，與
`SupabaseInvitationRepository.mapRedeemError` 同 pattern。

| RPC 'CODE' | Domain error |
|---|---|
| `SLOT_TAKEN` | `.slotTaken` |
| `OWNER_CANNOT_BOOK` | `.ownerCannotBook` |
| `NOT_MEMBER` | `.notMember` |
| `PAST_SLOT` | `.slotInPast` |
| `SCHEDULE_NOT_FOUND` | `.scheduleNotFound` |
| 其他 | `.persistenceFailure` |

| RPC 'CODE' (cancel) | Domain error |
|---|---|
| `BOOKING_NOT_FOUND` | `.bookingNotFound` |
| `NOT_OWNER` | `.notOwner` |
| `SLOT_STARTED` | `.slotAlreadyStarted` |
| 其他 | `.persistenceFailure` |

> 警示：RPC 訊息字串是 server-client 間的 informal contract。日後若改
> code 字面（例如重命名 `SLOT_TAKEN` → `BOOKING_CONFLICT`），mapper
> 跟 RPC 必須同 PR 一起改、本 api.md 也要一起更新。

## Seed 影響

`supabase/seed.sql` 加 `test-student-c@example.com`（user C，UUID
`c3d4e5f6-a7b8-9012-cdef-345678901234`），以及 user C 對 user A
sample schedule（`11111111-...`）的直接 `memberships` row。整合測試
使用此固定 fixture，而 user B 維持「無 membership」以保 Phase 3a
JoinedSchedules 既有 `userBNoMemberships_...` 測試前提。

---

## Slice 2 — get_bookings_visible_to_member RPC（2026-05-10 加入）

### 設計脈絡

Slice 2 開放「member 看到他人 booking 但無 PII」的可見性。bookings
table 的 RLS **不變**——避免 PostgREST `bookings?select=*` 直接回
完整 row 失誤。新增 SECURITY DEFINER RPC 預投影成 sanitized row
shape，作為 member 視角的唯一可見路徑。實際 SQL 在
`supabase/migrations/<ts>_add_get_bookings_visible_to_member.sql`。

### RPC

```sql
get_bookings_visible_to_member(target_schedule_id UUID)
RETURNS TABLE(
  starts_at        TIMESTAMPTZ,
  ends_at          TIMESTAMPTZ,
  duration_seconds INTEGER
)
SECURITY DEFINER
```

#### 檢查順序（嚴格）

1. `auth.uid() IS NULL` → `RAISE EXCEPTION 'AUTH_REQUIRED'`
2. `NOT is_member_of_schedule(target_schedule_id, auth.uid())` →
   `NOT_MEMBER`
3. `SELECT b.starts_at, b.ends_at, b.duration_seconds FROM bookings b
   WHERE b.schedule_id = target_schedule_id AND b.student_id <>
   auth.uid() ORDER BY b.starts_at ASC`

`GRANT EXECUTE TO authenticated`。

### 為什麼 return signature 不含 booking_id / student_id / email

- BookingID 是 PII（cross-schedule unique 的 booker 行為相關識別）；
  學生看到也無 cancel 權限（`cancel_booking` RPC 仍會擋）。
- VM 的 `PresentedSlot` 已用 `slot.start.timeIntervalSince1970` 當
  Identifiable id、不需新 id 來源。
- 拒絕誘惑 → 型別 + RPC 雙重防護「就是不外流」。

### 為什麼 owner 也被拒（NOT_MEMBER）

owner 通常**不是** schedule 的 member（owner !⇒ membership in 此 app
模型）。owner 應走 `get_bookings_for_owner` RPC（Slice 1.5）含 email；
此 RPC 拒絕 owner 強制兩條 path 嚴格分開、避免 owner 誤用 member
path 拿到 sanitized 而非 enriched view。VM 已用 `isOwner` 分支保證老
師不會誤呼。

### DTO

`App/Infrastructure/Supabase/DTOs/BookedSlotDTO.swift`：

```swift
struct BookedSlotDTO: Codable, Sendable {
    let startsAt: String         // ISO 8601 from TIMESTAMPTZ
    let endsAt: String
    let durationSeconds: Int
}
```

3 欄、純 sanitized；camelCase ↔ snake_case 轉換沿用
`SupabaseClientProvider` 的 encoder 設定。

### Error Code Mapping

`BookingMapper.mapVisibleFetchError`：

| RPC 'CODE' | Domain error |
|---|---|
| `NOT_MEMBER` | `.notMember` |
| 其他 | `.persistenceFailure` |
