# 預約 manual AvailabilityWindow — Backlog stub

> Post-MVP backlog placeholder。沒有實作；只當記事用。

## Status

**Deferred — post-MVP backlog**

當前的 student booking（Phase 3b Slice 1）只允許預約 rule-derived
`ComputedSlot`。手動 `AvailabilityWindow`（teacher 在 schedule editor
裡新增的一次性區段）目前完全不會在學生 calendar UI 顯示，也無法被
預約。

## Why deferred

- 目前 calendar UI 只渲染 ComputedSlot；window 在 schedule 編輯介面
  被加入但未細分為時段
- 大多數 1-on-1 / 團體課場景靠 rule 就足夠
- Window 預約涉及多個尚未拍板的設計問題（見下）

## 開做時要回答的設計問題

1. **Window-內 slot 化策略**：window 是當作單一不可分割的 slot（學生
   要嘛訂下整段、要嘛不訂）？還是依 schedule.minWindowDuration 切成
   sub-slot？切的話起點怎麼對齊？
2. **Window / Rule 重疊衝突**：同一天既有 rule slot 又有 window，且時間
   重疊時，重疊的 slot 顯示哪個來源？兩個都顯示還是 window 蓋過 rule？
   被重疊的 rule slot 要不要當作不可預約？
3. **UI 第二視覺軌道**：DaySlotListView 要區分「rule 來的」 vs
   「window 來的」嗎？視覺差異化會影響可發現性
4. **Booking row 怎麼指向 window**：bookings 目前只記 `(schedule_id,
   starts_at)`。要加 `source: 'rule' | 'window'` 嗎？或加 `window_id`
   外鍵？

## 跟既有 Slice 1 設計的銜接

Slice 1 plan：`~/.claude/plans/cheeky-bouncing-dusk.md` §3、§5、§7
記錄了「booking target 僅 ComputedSlot」的決策、UNIQUE 鍵設計、以及
為何 RPC 收 `(starts_at, ends_at, duration_seconds)` 而非 `slot_id`。

當 window booking 開做時，這些前提需要重新評估：
- UNIQUE 鍵可能要擴成 `(schedule_id, starts_at, source)` 或 `(schedule_id,
  window_id)` 的雙鍵聯合
- `book_slot` RPC 要加新參數區分來源（或開另一支 RPC `book_window`）
- ComputedSlot Domain 結構可能要區分「rule-derived」vs 「window-derived」
