# 邀請學生加入課表 — Scenarios（完整 Given / When / Then）

> 規範：每個 scenario title = 一個 `@Test` function name 的中文敘述；
> camelCase 函式名透過 grep 可雙向定位。Domain test 純函式、Usecase
> test 用 fake repo、ViewModel test 用 fake usecase、Infrastructure 整合
> test 打 local Supabase。
>
> ★ = Slice 1 範圍（本輪實作）；其餘為 Slice 2 / 3 的概要、留各自 plan
> 細談。

---

## Slice 1 — Teacher 產生 invitation ★

### Domain — InvitationToken (3) ★

#### T1. 用合法 8 字元 Crockford 字串建 token，成功

```
Given 一個 8 字元的合法字串 "ABCD1234"，全部都在 Crockford 字母表內
When  以該字串建立 InvitationToken
Then  建立成功，rawValue 等於該字串
```

#### T2. 用 7 字元字串建 token，throws .invalidLength

```
Given 一個 7 字元的字串 "ABCD123"
When  以該字串建立 InvitationToken
Then  throws .invalidLength
```

#### T3. 含 `I` 的 8 字元字串建 token，throws .invalidCharacter

```
Given 一個 8 字元字串 "AICD1234"，含 Crockford 表外的 'I'
When  以該字串建立 InvitationToken
Then  throws .invalidCharacter
```

> `InvitationToken.generate()` 不單獨測——T1/T3 已驗 length + alphabet 契約。

### Domain — Invitation (4) ★

#### I1. 建立 expiresAt 晚於 createdAt 的 invitation，成功

```
Given scheduleID = sample, createdAt = 2026-05-03T00:00Z,
      expiresAt = 2026-05-10T00:00Z
When  建立 Invitation
Then  建立成功；id / scheduleID / token / expiresAt / createdAt 全部存在
```

#### I2. 建立 expiresAt 等於 createdAt 的 invitation，throws .invalidExpiry

```
Given createdAt 與 expiresAt 同為 2026-05-03T00:00Z
When  建立 Invitation
Then  throws .invalidExpiry
```

#### I3. 建立 expiresAt 早於 createdAt 的 invitation，throws .invalidExpiry

```
Given createdAt = 2026-05-10T00:00Z, expiresAt = 2026-05-03T00:00Z
When  建立 Invitation
Then  throws .invalidExpiry
```

#### I4. isExpired(at:) 在邊界回傳正確

```
Given Invitation with expiresAt = 2026-05-10T00:00Z
When  分別呼叫 isExpired(at: 2026-05-09T23:59Z),
                    isExpired(at: 2026-05-10T00:00Z),
                    isExpired(at: 2026-05-10T00:01Z)
Then  回傳 false, true, true
```

### Usecase — CreateInvitationUseCase (4) ★

> Fake `InvitationRepository`（in-memory dict + save() 紀錄）+
> `InMemoryScheduleRepository`（既有）+ Fake `CurrentUserProvider`
> （既有 `InMemoryCurrentUserProvider`）。

#### C1. Owner 對自己 schedule 建立 invitation，成功

```
Given currentUser = teacher-001，repo 已有屬於 teacher-001 的 schedule X
When  呼叫 createInvitation(scheduleID: X)
Then  invitationRepository 多一筆，scheduleID = X，
      expiresAt 接近 now + 7 天，token 通過 Crockford 格式驗證
```

#### C2. 非 owner 嘗試對他人 schedule 建立，throws .notOwner

```
Given currentUser = teacher-002，repo 有屬於 teacher-001 的 schedule X
When  呼叫 createInvitation(scheduleID: X)
Then  throws .notOwner，invitationRepository 無變化
```

#### C3. 對不存在 scheduleID 建立，throws .scheduleNotFound

```
Given currentUser = teacher-001，repo 沒有 scheduleID = X 的 row
When  呼叫 createInvitation(scheduleID: X)
Then  throws .scheduleNotFound
```

#### C4. Repository save 失敗，throws .persistenceFailure

```
Given currentUser = teacher-001，schedule X 存在；
      InvitationRepository 設成 save 一定 throw
When  呼叫 createInvitation(scheduleID: X)
Then  throws .persistenceFailure
```

### Usecase — ListInvitationsUseCase (3) ★

#### L1. Owner list 自己 schedule 的 invitations（已有 2 筆），回傳 2 筆按 createdAt desc

```
Given currentUser = teacher-001 own schedule X；
      X 有 invitation A (createdAt = T1) 與 invitation B (createdAt = T2 > T1)
When  呼叫 listInvitations(for: X)
Then  回傳 [B, A]（新 → 舊）
```

#### L2. Owner list 沒 invitation 的 schedule，回傳空陣列

```
Given currentUser = teacher-001 own schedule X，X 沒有任何 invitation
When  呼叫 listInvitations(for: X)
Then  回傳 []
```

#### L3. 非 owner 嘗試 list，throws .notOwner

```
Given currentUser = teacher-002，schedule X 屬於 teacher-001
When  呼叫 listInvitations(for: X)
Then  throws .notOwner
```

### Infrastructure 整合測試 (3) ★

> 擴 `SupabaseIntegrationTests` 加 `Invitations` sub-suite，沿用既有
> serialized + sign-in helper。`supabase db reset` 必跑（確保 sample
> seed 在）。

#### INT1. Owner save invitation → fetchAll 撈得到（round-trip）

```
Given user A 已登入，A own schedule X
When  SupabaseInvitationRepository.save(invitation Y for X)
      然後 fetchAll(for: X)
Then  回傳含 Y 的列表，Y 的 token / expiresAt / scheduleID 完整
```

#### INT2. 非 owner fetchAll，RLS 擋住，回傳空

```
Given A 已 save invitation Y for schedule X
When  切換登入到 user B（非 X 的 owner），fetchAll(for: X)
Then  回傳 []（RLS owner_select 過濾掉）
```

#### INT3. 同 token INSERT 兩次，UNIQUE 阻擋

```
Given A 已 save invitation Y（token = "ABCD1234"）for schedule X
When  嘗試再 save 另一個 invitation Z，token 同樣是 "ABCD1234"
Then  throws（PostgrestError 含 UNIQUE 違反訊息）
```

### ViewModel — InviteSheetViewModel (4) ★

> 用 `FakeCreateInvitationUseCase` + `FakeListInvitationsUseCase`，模式
> 同 Phase 1-2 的 ViewModel 測試。

#### V1. onAppear，repo 為空，invitations == []

```
Given FakeListInvitationsUseCase.resultToReturn = []
When  vm.onAppear()
Then  vm.invitations.isEmpty == true，loadError == nil
```

#### V2. onAppear，repo 有 2 筆，invitations.count == 2

```
Given FakeListInvitationsUseCase.resultToReturn = [a, b]
When  vm.onAppear()
Then  vm.invitations == [a, b]
```

#### V3. didTapGenerate 成功，新 invitation 出現在列表最前面

```
Given vm.invitations = []，FakeCreateInvitationUseCase.resultToReturn = newInv
When  vm.didTapGenerate()
Then  vm.invitations.first == newInv，
      vm.invitations.count == 1，
      vm.isGenerating == false（async 結束時），
      vm.inlineError == nil
```

#### V4. didTapGenerate 失敗，inlineError 設定、列表不變

```
Given vm.invitations = [existing]，
      FakeCreateInvitationUseCase.errorToThrow = .persistenceFailure
When  vm.didTapGenerate()
Then  vm.invitations == [existing]（不變），
      vm.inlineError != nil，
      vm.isGenerating == false
```

> `didTapCopy(_:)` 不寫測——純 `UIPasteboard.general.string = ...` side
> effect、無狀態變化。

---

## Slice 2 — Student redeem invitation（暫列輪廓）

### Domain — Membership (1)
- M1：建立 Membership，欄位完整

### Usecase — RedeemInvitationUseCase (5)
- R1：valid token + 非 owner + 未加入 → 回傳 ScheduleID
- R2：token 不存在 → throws `.invalidToken`
- R3：token 已過期 → throws `.expired`
- R4：current user 是該 schedule owner → throws `.selfRedemption`
- R5：current user 已是 member → throws `.alreadyMember`

### Infrastructure 整合 (4)
- INT-R1：valid token redeem 成功 → memberships 多一筆
- INT-R2：expired token redeem → RPC 拋 EXPIRED
- INT-R3：第二次 redeem 同 token 同人 → RPC 拋 ALREADY_MEMBER
- INT-R4：owner self-redeem → RPC 拋 SELF_REDEMPTION

### ViewModel — RedeemInvitationViewModel (5)
- 文字輸入、空輸入、各種錯誤 inline 顯示、成功流程

---

## Slice 3 — Student 看自己加入的 schedule（暫列輪廓）

### Usecase — ListJoinedSchedulesUseCase (2)
- J1：無 memberships → 回傳 []
- J2：兩筆 memberships → 回傳兩個對應的 Schedule

### ViewModel — ScheduleListViewModel 修改 (3)
- M1：載入 owned + joined 各 1 筆 → 兩個 section
- M2：load joined 失敗 → joined 顯示 error，但 owned 仍正常
- M3：empty owned + 1 joined → 隱藏 owned section

### Infrastructure 整合 (2)
- INT-J1：member 透過 RLS 看到自己加入的 schedule
- INT-J2：非 member 看不到該 schedule（既有 RLS deny 測試應仍 green）

---

## 命名對照表（scenario title ↔ test function name）

> 慣例：title 第一段是英文 method 名（snake/camel）、後面是 _ 分隔的
> 描述。test function 用 camelCase 直譯。例如：

| Scenario title | Swift test function name |
|---|---|
| T1. 用合法 8 字元 Crockford 字串建 token，成功 | `createToken_validCrockford8Chars_succeeds()` |
| T2. 用 7 字元字串建 token，throws .invalidLength | `createToken_sevenChars_throwsInvalidLength()` |
| I1. 建立 expiresAt 晚於 createdAt 的 invitation，成功 | `createInvitation_expiresAfterCreated_succeeds()` |
| I2. 建立 expiresAt 等於 createdAt 的 invitation，throws .invalidExpiry | `createInvitation_expiresEqualCreated_throwsInvalidExpiry()` |
| C1. Owner 對自己 schedule 建立 invitation，成功 | `createInvitation_ownerOwnSchedule_succeeds()` |
| C2. 非 owner 嘗試對他人 schedule 建立，throws .notOwner | `createInvitation_nonOwner_throwsNotOwner()` |
| L1. Owner list 自己 schedule 的 invitations… | `listInvitations_ownerWithTwo_returnsNewestFirst()` |
| INT1. Owner save invitation → fetchAll 撈得到 | `ownerSaveAndFetchAllInvitations_roundTrips()` |
| V1. onAppear，repo 為空，invitations == [] | `onAppear_emptyRepo_invitationsIsEmpty()` |
| V3. didTapGenerate 成功 | `didTapGenerate_success_prependsToList()` |
| V4. didTapGenerate 失敗 | `didTapGenerate_failure_setsInlineError()` |

剩餘 scenarios 依此命名規則延伸。
