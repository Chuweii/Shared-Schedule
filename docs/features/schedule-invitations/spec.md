# 邀請學生加入課表 — Spec

> Phase 3a of Shared-Schedule
> 第一個跨身份的 feature：teacher 產生邀請碼、student 加入、student
> 在 list 看見自己加入的 schedule（read-only）

## Why

Phase 1 + 2 結束時，整個 app 只有 teacher 自己用——學生角色完全不
存在於系統內。Phase 3 的整體目標是讓學生進來；Phase 3a 是這條鏈的
**第一節**，建立兩個核心 aggregate（Invitation、Membership），把
「誰能看到哪份 schedule」的權限模型從「只有 owner」擴成「owner + 所
有有效成員」。

完成 Phase 3a 後 user-visible 的轉變：
1. **Teacher**：每份 schedule 可產生數張不限次數的「邀請碼」（8 字元
   英數字串），分享給學生
2. **Student**：在 app 內輸入邀請碼即可加入該課表
3. **Student**：在「我加入的」section 看到所有自己有 membership 的
   schedule、點進去能看到 read-only 的月曆與當日 slot 列表

但 **不能 book**——booking 是 Phase 3b。

## What

### 新增的概念

- **Invitation**：一張可被多次 redeem 的邀請券，屬於某份 schedule
  - 8 字元 token（Crockford Base32：`0-9A-Z` 去掉 `I L O U`）
  - 7 天後自動失效
  - 由 schedule 的 owner 產生
- **Membership**：學生 ↔ schedule 的綁定，紀錄是從哪張 invitation 來的
- **Hybrid 角色模型**：teacher 不寫 membership row，靠 `schedules.owner_id`
  快速辨識；memberships 表只放學生

### Teacher 可以做的事

- 在自己 schedule 的 calendar toolbar 點「邀請學生」按鈕
- 看到目前有效的邀請碼列表（含失效時間）
- 產生新邀請碼（系統自動配 7 天 expiry）
- 複製邀請碼到剪貼簿

### Student 可以做的事

- 在 schedule list toolbar 點「輸入邀請碼」按鈕
- 輸入 / 貼上 8 字元邀請碼、確認加入
- 加入成功後：自動 navigate 到該 schedule 的 calendar
- 在 list 的「我加入的」section 看到所有加入的 schedule
- 點進去看 read-only 的月曆 + 當日 slot 列表（同 teacher 看到的 UI、
  少了 toolbar 的編輯入口）

## 不做的事（Out of Scope）

Phase 3a **不含**以下項目：

- Booking（預約 slot）→ Phase 3b
- 看到別人的 booking 為 time-only → Phase 3c
- Invitation **revocation**（teacher 主動讓 token 失效）→ Phase 4
- Invitation **usage_limit**（限制單一 token 被 N 人使用）→ Phase 4
- Invitation **expiry 自訂**（teacher 選 1/7/30 天）→ Phase 4
- Universal Link / QR code 分享 → Phase 4
- Member 主動 leave / Teacher kick member → Phase 3b 或 4
- 學生身份顯示在 row 上的 badge → Slice 3 plan 再決
- Cross-device / Universal Clipboard / Share Sheet → Phase 4

## Permissions

| 角色 | 可做 | 不可做 |
|---|---|---|
| Schedule owner（teacher） | 產生 invitation、看自己 schedule 的 invitations、看 memberships（誰加入了）、編輯 schedule（既有功能） | 對自己 schedule 的 invitation 自我 redeem |
| Member（student） | redeem invitation、read-only 看自己加入的 schedule（calendar + slots） | 編輯該 schedule 的任何欄位、產生 invitation、看其他 members、書讀其他 schedule |
| 既未 own、亦未 member 的 user | 無法看到該 schedule 的任何欄位（RLS 阻擋） | — |

權限執行位置：
- **Domain 層**：不處理 authorization
- **Usecase 層**：`schedule.ownerID == currentUser.id` 檢查（產生 invitation、列 invitation）
- **Backend RLS**：實際的存取阻擋線（owner_select / member_select / self_or_owner_select）
- **Backend RPC**：`redeem_invitation()` SECURITY DEFINER 函式，做原子的「驗 token + 建 membership」

## User Flow

### Teacher 產生邀請碼

```
ScheduleListView
  ↓ 點某份 schedule row
ScheduleCalendarView（既有）
  ↓ toolbar 多一顆「邀請學生」按鈕
InviteSheet（新）
  ├─ 標題：邀請學生加入「課表名稱」
  ├─ 「＋ 產生新邀請碼」按鈕
  └─ 邀請碼列表（每筆顯示 token、失效時間、複製按鈕）
  ↓ 按「＋ 產生新邀請碼」
新邀請出現在列表最上方（前置）
  ↓ 按「複製」
token 進剪貼簿（觸覺回饋）
  ↓ dismiss
回到 ScheduleCalendarView
```

### Student 加入課表

```
ScheduleListView
  ↓ toolbar 多一顆「輸入邀請碼」按鈕（envelope.badge icon）
  ↓ 或 empty state 上的 secondary CTA「輸入邀請碼」
RedeemInvitationSheet
  ├─ 【輸入狀態】
  │   ├─ 文字輸入框（8 字元、即時 auto-uppercase + Crockford filter、monospace）
  │   ├─ 副說明：邀請碼共 8 個英數字元
  │   └─ 「加入課表」按鈕（disabled until input.count == 8）
  │   ↓ 按「加入課表」
  │   ├─ 成功 → 切換到【成功狀態】
  │   └─ 失敗 → inline error 顯示在輸入框下方，輸入內容保留
  │       ├─ 邀請碼不存在
  │       ├─ 邀請碼已過期
  │       ├─ 你是這份課表的老師
  │       ├─ 你已加入過此課表
  │       └─ 加入失敗，請稍後再試（一般 persistence 失敗 fallback）
  └─ 【成功狀態】
      ├─ ✓ 已加入「<課表名稱>」
      └─ 「完成」按鈕 → dismiss sheet 回到 ScheduleListView
```

> 成功後 Slice 2 不做 navigation；學生 dismiss 後會在 ScheduleListView
> 的「我加入的」section 看到該 schedule（Slice 3 才落地此 section；
> 在 Slice 3 完成前，學生 dismiss 後 list 上不會顯示——這是預期、非 bug）。

### Student 看自己加入的 schedule

```
ScheduleListView（Slice 3 改）
  ├─ section「我的課表」（owned，既有）
  └─ section「我加入的」（new，joined as student）
       ↓ 點 row
       ScheduleCalendarView（read-only mode）
         └─ toolbar 不顯示「邀請學生」按鈕（owner 才顯示）
```

## Scenarios 摘要

完整 Given / When / Then 見 [scenarios.md](./scenarios.md)。

### Slice 1 — Teacher 產生 invitation

#### Domain — InvitationToken (3)

| # | Scenario | 結果 |
|---|---|---|
| T1 | 用合法 8 字元 Crockford 字串建 token | success |
| T2 | 用 7 字元字串建 token | throws `.invalidLength` |
| T3 | 用含 `I` 的 8 字元字串建 token | throws `.invalidCharacter` |

#### Domain — Invitation (4)

| # | Scenario | 結果 |
|---|---|---|
| I1 | expiresAt 晚於 createdAt 建 invitation | success |
| I2 | expiresAt 等於 createdAt | throws `.invalidExpiry` |
| I3 | expiresAt 早於 createdAt | throws `.invalidExpiry` |
| I4 | `isExpired(at:)` 邊界（前 / 等於 / 後） | 邏輯正確 |

#### Usecase — CreateInvitationUseCase (4)

| # | Scenario | 結果 |
|---|---|---|
| C1 | Owner 對自己 schedule 建立 invitation | repo 多一筆、expiresAt = now+7d |
| C2 | 非 owner 嘗試 | throws `.notOwner` |
| C3 | 對不存在 scheduleID | throws `.scheduleNotFound` |
| C4 | Repository save 失敗 | throws `.persistenceFailure` |

#### Usecase — ListInvitationsUseCase (3)

| # | Scenario | 結果 |
|---|---|---|
| L1 | Owner list 自己 schedule（已有 2 筆） | 回傳 2 筆 |
| L2 | Owner list 沒 invitation 的 schedule | 回傳 [] |
| L3 | 非 owner | throws `.notOwner` |

#### Infrastructure 整合測試 (3，打 local Supabase)

| # | Scenario | 結果 |
|---|---|---|
| INT1 | Owner save invitation → fetchAll 撈得到 | round-trip OK |
| INT2 | 換 user B fetchAll(scheduleID) | RLS 擋住、回傳 [] |
| INT3 | 同 token INSERT 兩次 | UNIQUE constraint throws |

#### ViewModel — InviteSheetViewModel (4)

| # | Scenario | 結果 |
|---|---|---|
| V1 | onAppear，repo 為空 | invitations == [] |
| V2 | onAppear，repo 有 2 筆 | invitations.count == 2 |
| V3 | didTapGenerate 成功 | 新 invitation 出現在列表頂端 |
| V4 | didTapGenerate 失敗 | inlineError 設定、列表不變 |

**Slice 1 合計 21 個測試。**

### Slice 2 — Student redeem invitation

#### Usecase — RedeemInvitationUseCase (6)

| # | Scenario | 結果 |
|---|---|---|
| R1 | Valid token、非 owner、未加入 | 回傳 Schedule X |
| R2 | Token 不存在 | throws `.invalidToken` |
| R3 | Token 已過期 | throws `.expired` |
| R4 | Current user 是 schedule owner | throws `.selfRedemption` |
| R5 | Current user 已是 member | throws `.alreadyMember` |
| R6 | Redeem 成功但後續 schedule fetch 失敗 | throws `.persistenceFailure` |

#### Infrastructure 整合測試 (4，打 local Supabase)

| # | Scenario | 結果 |
|---|---|---|
| INT-R1 | User B redeem user A 的 valid token | memberships 多一筆，回傳 InvitationRedemption |
| INT-R2 | Redeem 已過期 token | RPC 拋 EXPIRED → repo 拋 `.expired` |
| INT-R3 | 同 user 第二次 redeem 同 token | RPC 拋 ALREADY_MEMBER → repo 拋 `.alreadyMember` |
| INT-R4 | Owner self-redeem 自己 schedule 的 token | RPC 拋 SELF_REDEMPTION → repo 拋 `.selfRedemption` |

#### ViewModel — RedeemInvitationViewModel (7)

| # | Scenario | 結果 |
|---|---|---|
| VN1 | `normalize` 處理小寫 + 標點 + 過濾非 Crockford 字元 | "abcd-12 34!o" → "ABCD1234" |
| VN2 | `normalize` 截斷至 8 字元 | "ABCDEFGHJKMN" → "ABCDEFGH" |
| V1 | `updateInput` 正規化並清掉 inlineError | input 變大寫，inlineError = nil |
| V2 | `didTapSubmit` 在 input 不到 8 字元時 no-op | usecase 沒被呼叫 |
| V3 | `didTapSubmit` 成功 | success.schedule = X、isSubmitting = false |
| V4 | `didTapSubmit` invalidToken | inlineError 設定，input 保留，success = nil |
| V5 | `didTapSubmit` alreadyMember | inlineError 訊息對應 |

> Membership 不寫 Domain test：無 invariant、struct init 是 compiler-enforced。

**Slice 2 合計 17 個測試。**

### Slice 3 — Student 看 joined schedules

#### Usecase — ListJoinedSchedulesUseCase (2)

| # | Scenario | 結果 |
|---|---|---|
| J1 | 沒 membership | 回傳 [] |
| J2 | 兩筆 membership 對應 X、Y | 回傳 [X, Y] |

#### ViewModel — ScheduleListViewModelTests 擴增 (4)

| # | Scenario | 結果 |
|---|---|---|
| M1 | owned + joined 都成功 | 兩個 array 都填、兩個 error nil、isFullScreenError == false |
| M2 | owned 成功、joined 失敗 | 只設 joinedLoadError、isFullScreenError == false |
| M3 | owned 為空、joined 有 1 筆 | isEmpty == false（顯示只有 joined section） |
| M4 | 兩邊都失敗 | 兩個 error 都設、isFullScreenError == true |

> 既有 8 個 ViewModel test 同步 migrate 到新 state name（`ownedSchedules` /
> `ownedLoadError` / `retryOwned`），不增加 test 總數。

#### Infrastructure 整合測試 (2，打 local Supabase)

| # | Scenario | 結果 |
|---|---|---|
| INT-J1 | B redeem A 的 invitation 後 fetchAll(memberOf: B) | 結果含 X、rules + windows 完整 |
| INT-J2 | A 建一個 B 沒被邀請的 schedule Y、fetchAll(memberOf: B) | !result.contains(Y) |

#### DTO Decoder unit test (1)

> 不打 server。`MembershipScheduleRowDTO` 對 PostgREST embedded shape
> （`[{schedules: {…}}]`）的 decode 正確、`convertFromSnakeCase` 對 nested
> `availability_rules / availability_windows` 有遞迴套用。

**Slice 3 合計 9 個新測試**（J1-J2 + M1-M4 + INT-J1/J2 + D1）。

#### UX 決策（Plan cozy-kindling-lollipop §5）

- joined row UI 完全同 owned，不加 badge — section header 自帶身份訊號
- nav title 從「我的課表」改為中性「課表」
- empty state 描述改為中性「建立自己的課表，或輸入邀請碼加入別人的」
- per-section 失敗：成功的 section 正常顯示、失敗的 section 顯示 inline
  retry row；只有兩邊都失敗 + 兩邊都空時才走 full-screen error fallback
- `ScheduleCalendarView` 完全不動：Slice 1 已經用 `isOwner` gate 掉
  「邀請」toolbar、calendar grid 本身無 edit affordance，read-only 自動成立

## Technical Notes

### Domain 設計
- `Invitation` 是 aggregate root；`InvitationToken` 是 VO（封裝格式驗證）
- `Membership` 是 aggregate root；無 Domain-layer invariant（uniqueness 跟
  selfRedemption 在 backend RPC 層做）
- 全部 `nonisolated struct ... Sendable`、跟既有 Schedule 一致
- 使用 typed throws（`throws(InvitationError)` 等）

### 角色模型 — Hybrid
- `schedules.owner_id` 留著當 teacher fast path（RLS：`owner_id = auth.uid()`）
- `memberships` 只放學生（`role = 'student'` 在 MVP 是只有一種值，未來可
  擴成 enum）
- 輕微偏離 architecture.md「role 只屬於 Membership」的嚴格讀法、但
  cost-of-change 最低、Phase 4 可重新評估

### Token 設計
- 8 字元 Crockford Base32：alphabet `0123456789ABCDEFGHJKMNPQRSTVWXYZ`
  （去掉 `I L O U` 避免肉眼混淆）
- 32^8 ≈ 1.1T、UNIQUE 衝突概率極低
- App-side `SecureRandomNumberGenerator` 產生；衝突時呼叫者 retry 一次
- DB 端有 `CHECK (length(token) = 8)` + `UNIQUE` 雙重防線

### Backend
- 一張新 migration，**整批**包含 Slice 1 + 2 + 3 的 schema + RLS + RPC
- `redeem_invitation(token)` SECURITY DEFINER PG function：原子化
  「驗 token / 驗非 self / 驗未加入過 / INSERT membership」
- 既有表 RLS 擴充：schedules / availability_rules / availability_windows 各加
  一條 `member_select` policy

### 錯誤呈現
- ViewModel 直接用 Usecase 的 typed error；error → LocalizedStringResource → View
- inline error（form-style），不打 alert／toast
- Slice 2 「failed to redeem」的訊息分得多細，留 Slice 2 plan 討論

### 測試配置
- Domain / Usecase / ViewModel：純單元測（既有架構）
- Infrastructure 整合測：擴 `SupabaseIntegrationTests` 加 `Invitations` sub-suite
- Phase 2.5 既有的 RLS deny 整合測試 = 契約守門員，**新 RLS policy 不
  能弄壞它們**（Phase 3a 改完 7 個既有整合測試必須仍 green）

## 驗收條件（Slice 1 完成）

- `xcodebuild test`：91 → ~112 tests 全綠（含 INT1-INT3 整合測試需
  `supabase start` + `supabase db reset` 後才能跑）
- Domain 零框架依賴：`grep -r "import SwiftUI\|import Combine\|import Supabase" App/Domain/Invitation` 為空
- 所有新 ViewModel 用 `@Observable`、無 `ObservableObject` + `@Published`
- String Catalog 三語完整（zh-Hant / en / ja 每個 key 都有翻譯）
- Simulator e2e：登入 user A、進 sample schedule、產生兩張邀請碼、複製、
  dismiss、重進仍見兩筆
- Phase 2.5 既有 7 個整合測試仍 green（驗證 RLS 沒被新 policy 弄壞）

## 後續 plan 銜接

Slice 1 完成、commit 後，下一輪 plan 進 Slice 2（student redeem 流程）。
Slice 2 plan mode 時要決定的事：
- redeem 失敗訊息粒度
- 第一次成功 redeem 的 onboarding tooltip
- token 輸入欄位的 input formatter（auto-uppercase？大寫即時驗證？）

Slice 3 plan mode 時要決定的事：
- joined schedule row 是否加身份 badge
- student 進入 calendar 時 toolbar 邏輯
