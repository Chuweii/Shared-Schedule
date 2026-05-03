# 邀請學生加入課表 — Backend API

> Phase 3a 的 backend 規格：tables、RLS policies、PG function、DTO ↔ Domain
> mapping。對應 plan file melodic-sprouting-hopper.md §7。

## 1. Migration 命名

`supabase/migrations/<timestamp>_add_invitations_memberships.sql`

> 一張 migration **整批包**含 invitations + memberships + 既有表的
> RLS 擴充 + redemption RPC。Slice 2 / 3 用得到、但 Slice 1 一次推完，
> 之後不需要再來第二張 migration。

## 2. 新表

### invitations

```sql
CREATE TABLE invitations (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id  UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  token        TEXT NOT NULL UNIQUE,
  expires_at   TIMESTAMPTZ NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (expires_at > created_at),
  CHECK (length(token) = 8)
);

CREATE INDEX invitations_token_idx ON invitations (token);
```

| 欄位 | 對應 Domain |
|---|---|
| `id` | `Invitation.id` (`InvitationID(UUID)`) |
| `schedule_id` | `Invitation.scheduleID` (`ScheduleID`) |
| `token` | `Invitation.token` (`InvitationToken.rawValue`) |
| `expires_at` | `Invitation.expiresAt` (`Date`) |
| `created_at` | `Invitation.createdAt` (`Date`) |

### memberships

```sql
CREATE TABLE memberships (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id    UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invitation_id  UUID REFERENCES invitations(id) ON DELETE SET NULL,
  joined_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (schedule_id, user_id)
);
```

| 欄位 | 對應 Domain |
|---|---|
| `id` | `Membership.id` |
| `schedule_id` | `Membership.scheduleID` |
| `user_id` | `Membership.userID` |
| `invitation_id` | `Membership.invitationID` (Optional) |
| `joined_at` | `Membership.joinedAt` |

> Hybrid 模型：teacher 不寫 memberships row。`memberships` 永遠是
> 「該 schedule 的學生集合」。

## 3. RLS Policies

### invitations

| Operation | Policy | 條件 |
|---|---|---|
| SELECT | `owner_select` | schedule 的 `owner_id = auth.uid()` |
| INSERT | `owner_insert` | 同上（with check） |
| UPDATE / DELETE | （不開）| Phase 3a 沒有 revoke / edit |

```sql
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner_select" ON invitations FOR SELECT
  USING (EXISTS (SELECT 1 FROM schedules
                 WHERE id = invitations.schedule_id
                 AND owner_id = auth.uid()));

CREATE POLICY "owner_insert" ON invitations FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM schedules
                      WHERE id = invitations.schedule_id
                      AND owner_id = auth.uid()));
```

### memberships

| Operation | Policy | 條件 |
|---|---|---|
| SELECT | `self_or_owner_select` | 自己的 row OR 自己擁有的 schedule 的 row |
| INSERT | （不開 RLS）| 一律走 `redeem_invitation` RPC |
| UPDATE / DELETE | （不開） | Phase 3a 沒有 leave / kick |

```sql
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self_or_owner_select" ON memberships FOR SELECT
  USING (user_id = auth.uid()
         OR EXISTS (SELECT 1 FROM schedules
                    WHERE id = memberships.schedule_id
                    AND owner_id = auth.uid()));
```

### 既有表的 RLS 擴充

Phase 2 的 RLS 只允許 owner 讀；Phase 3a 加上「member 也能讀」：

```sql
CREATE POLICY "member_select" ON schedules FOR SELECT
  USING (EXISTS (SELECT 1 FROM memberships
                 WHERE schedule_id = schedules.id
                 AND user_id = auth.uid()));

CREATE POLICY "member_select" ON availability_rules FOR SELECT
  USING (EXISTS (SELECT 1 FROM memberships
                 WHERE schedule_id = availability_rules.schedule_id
                 AND user_id = auth.uid()));

CREATE POLICY "member_select" ON availability_windows FOR SELECT
  USING (EXISTS (SELECT 1 FROM memberships
                 WHERE schedule_id = availability_windows.schedule_id
                 AND user_id = auth.uid()));
```

> Postgres RLS 對同一 operation 的多條 policy 是 **OR** 關係：
> owner_select **OR** member_select 都會通過。所以 Phase 2 的
> `owner_select` 不需要動。

## 4. RPC：redeem_invitation

```sql
CREATE FUNCTION redeem_invitation(invitation_token TEXT)
RETURNS TABLE(schedule_id UUID, membership_id UUID, joined_at TIMESTAMPTZ)
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_invitation invitations%ROWTYPE;
  v_user_id UUID := auth.uid();
  v_owner_id UUID;
  v_membership_id UUID;
  v_now TIMESTAMPTZ := now();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT * INTO v_invitation FROM invitations WHERE token = invitation_token;
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_TOKEN'; END IF;
  IF v_invitation.expires_at <= v_now THEN RAISE EXCEPTION 'EXPIRED'; END IF;

  SELECT owner_id INTO v_owner_id FROM schedules WHERE id = v_invitation.schedule_id;
  IF v_owner_id = v_user_id THEN RAISE EXCEPTION 'SELF_REDEMPTION'; END IF;

  IF EXISTS (SELECT 1 FROM memberships
             WHERE schedule_id = v_invitation.schedule_id
             AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'ALREADY_MEMBER';
  END IF;

  INSERT INTO memberships (schedule_id, user_id, invitation_id, joined_at)
  VALUES (v_invitation.schedule_id, v_user_id, v_invitation.id, v_now)
  RETURNING id INTO v_membership_id;

  RETURN QUERY SELECT v_invitation.schedule_id, v_membership_id, v_now;
END $$;

GRANT EXECUTE ON FUNCTION redeem_invitation(TEXT) TO authenticated;
```

| 錯誤訊息 | Domain RedeemInvitationError |
|---|---|
| `AUTH_REQUIRED` | (不該發生 — 未登入時 sign-in gate 已擋) |
| `INVALID_TOKEN` | `.invalidToken` |
| `EXPIRED` | `.expired` |
| `SELF_REDEMPTION` | `.selfRedemption` |
| `ALREADY_MEMBER` | `.alreadyMember` |

> RPC 用 `SECURITY DEFINER` 是因為 `memberships` 的 INSERT policy 不開、
> 一般 user 沒有 INSERT 權限；函式以 owner（superuser）身份執行、繞過
> RLS、但用 `auth.uid()` 嚴格鎖目標 user。

## 5. Swift Infrastructure 對應

### DTO

`App/Infrastructure/Supabase/DTOs/InvitationDTO.swift`：

```swift
struct InvitationDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let token: String
    let expiresAt: String       // ISO 8601 ‒ tolerant parsing via ScheduleMapper.parseTimestamptz
    let createdAt: String?
}

struct InvitationInsertDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let token: String
    let expiresAt: String       // 用 ScheduleMapper.formatTimestamptz
}
```

`App/Infrastructure/Supabase/DTOs/MembershipDTO.swift`：

```swift
struct MembershipDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let userId: UUID
    let invitationId: UUID?
    let joinedAt: String
}
```

JSON encoder 已在 SupabaseClientProvider 設定 `.convertToSnakeCase`，所以
`scheduleId` 自動序列化成 `schedule_id`，依此類推。

### Repository methods（Slice 1 用到的）

```swift
protocol InvitationRepositoryProtocol: Sendable {
    func save(_ invitation: Invitation) async throws
    func fetchAll(for scheduleID: ScheduleID) async throws -> [Invitation]
    func fetch(id: InvitationID) async throws -> Invitation?
    func fetchByToken(_ token: InvitationToken) async throws -> Invitation?  // Slice 2 用
}
```

Implementation `SupabaseInvitationRepository`:

| Method | SQL |
|---|---|
| `save` | `INSERT INTO invitations ... ON CONFLICT (id) DO UPDATE SET ...`（upsert，跟 schedule 的 pattern 一致）|
| `fetchAll(for:)` | `SELECT * FROM invitations WHERE schedule_id = $1 ORDER BY created_at DESC` |
| `fetch(id:)` | `SELECT * FROM invitations WHERE id = $1` |
| `fetchByToken` | `SELECT * FROM invitations WHERE token = $1` |

RLS 由 `owner_select` 自動套上、不需要 client 加 `WHERE owner_id = ...`。

### Mapper 重用

時間欄位用 Phase 2.5 已經寫好的 `ScheduleMapper.parseTimestamptz` 與
`formatTimestamptz`（已涵蓋 fractional / non-fractional 兩種 Postgres 輸出
shape）。`InvitationMapper` 走相同路徑。

## 6. Seed 擴充

`supabase/seed.sql` 加（保留既有 user A / user B / sample schedule）：

```sql
-- 給 user A 的 sample schedule 一張示範邀請碼，方便手動 / Slice 2 整合測試
INSERT INTO invitations (id, schedule_id, token, expires_at) VALUES (
  '88888888-8888-8888-8888-888888888888',
  '11111111-1111-1111-1111-111111111111',
  'ABCD1234',
  now() + interval '7 days'
) ON CONFLICT (id) DO NOTHING;
```

## 7. 整合測試覆蓋

`Shared ScheduleTests/Infrastructure/Supabase/SupabaseIntegrationTests.swift` 擴
`Invitations` sub-suite：

| Test | 對應 scenarios.md |
|---|---|
| `ownerSaveAndFetchAllInvitations_roundTrips` | INT1 |
| `userBFetchesUserAInvitations_rlsReturnsEmpty` | INT2 |
| `duplicateToken_throwsUniqueViolation` | INT3 |

Phase 2.5 既有 7 個整合測試（Schedule round-trip、RLS deny、Auth provider）
**必須仍 green**——這是新 RLS policy 不能弄壞既有合約的守門員。

## 8. 變更清單（給 reviewer 一次看完）

- ✅ 新表：`invitations`、`memberships`
- ✅ 新 RLS policies：5 條（invitations × 2、memberships × 1、既有表 ×3）
- ✅ 新 PG function：`redeem_invitation(TEXT)` SECURITY DEFINER
- ✅ Phase 2 既有 RLS：**無變動**（新 policy 是 OR-additive）
- ✅ Phase 2 既有表 schema：**無變動**
- ✅ Seed：擴充一筆 sample invitation
- ✅ 整合測試：擴 Invitations sub-suite（3 test）

## 9. 後續 backend 工作

- Slice 2 backend：Swift 端呼叫 `redeem_invitation` RPC、處理錯誤訊息映射
- Slice 3 backend：Swift 端透過 `memberships` 表查詢 user 加入的 schedules
  （`SELECT schedule_id FROM memberships WHERE user_id = auth.uid()` →
  joined Schedule 列表）
- Phase 4 可能加：`UPDATE invitations SET expires_at = now()` revocation policy +
  `usage_limit INT` 欄位 + 新的 RLS 規則
