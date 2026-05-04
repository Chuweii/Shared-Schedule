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

## Slice 2 — Student redeem invitation ★

> Membership 不寫 Domain test（無 invariant、struct init 是 compiler-enforced）。
> 原 M1「建立 Membership 欄位完整」已移除。

### Usecase — RedeemInvitationUseCase (6) ★

> Fake `InvitationRepository`（in-memory + `redeemResultToReturn` /
> `redeemErrorToThrow`）+ `InMemoryScheduleRepository`（既有）。

#### R1. Valid token、非 owner、未加入，回傳 Schedule

```
Given fake invitation repo redeem 回傳 InvitationRedemption(scheduleID: X, ...)，
      InMemoryScheduleRepository 已有 Schedule X
When  呼叫 redeemInvitation(token: T)
Then  回傳 Schedule X
```

#### R2. Token 不存在，throws .invalidToken

```
Given fake invitation repo redeem throws .invalidToken
When  呼叫 redeemInvitation(token: T)
Then  throws .invalidToken
```

#### R3. Token 已過期，throws .expired

```
Given fake invitation repo redeem throws .expired
When  呼叫 redeemInvitation(token: T)
Then  throws .expired
```

#### R4. Current user 是 schedule owner，throws .selfRedemption

```
Given fake invitation repo redeem throws .selfRedemption
When  呼叫 redeemInvitation(token: T)
Then  throws .selfRedemption
```

#### R5. Current user 已是 member，throws .alreadyMember

```
Given fake invitation repo redeem throws .alreadyMember
When  呼叫 redeemInvitation(token: T)
Then  throws .alreadyMember
```

#### R6. Redeem 成功但後續 schedule fetch 失敗，throws .persistenceFailure

```
Given fake invitation repo redeem 回傳 InvitationRedemption(scheduleID: X, ...)，
      但 scheduleRepository.fetch(id: X) 拋錯
When  呼叫 redeemInvitation(token: T)
Then  throws .persistenceFailure
```

### Infrastructure 整合測試 (4) ★

> 擴 `SupabaseIntegrationTests` 加 `Redemption` sub-suite，沿用既有
> `@Suite(.serialized)` + `signIn(email:)` helper。

#### INT-R1. User B redeem user A 的 valid token，創出 membership 並回 redemption

```
Given user A 已 own schedule X 並 save invitation Y(token=T) 給 X
      切換登入到 user B
When  SupabaseInvitationRepository.redeem(token: T)
Then  回傳 InvitationRedemption(scheduleID = X, joinedAt 接近 now)
      memberships 表多一筆 (user_id = B, schedule_id = X, invitation_id = Y)
```

#### INT-R2. Redeem 已過期 token，throws .expired

```
Given 直接 raw INSERT 一筆 invitation Y(expires_at = now()-1day)
      （繞過 Domain 的 expiresAt > createdAt 限制；
        DB CHECK 是 expires_at > created_at、用更早的 created_at 過關）
      切換登入到 user B
When  SupabaseInvitationRepository.redeem(token: T)
Then  throws RedeemInvitationError.expired
```

#### INT-R3. 同 user 第二次 redeem 同 token，throws .alreadyMember

```
Given INT-R1 流程跑完（user B 已是 X 的 member）
When  user B 再呼叫 redeem(token: T)
Then  throws RedeemInvitationError.alreadyMember
```

#### INT-R4. Owner self-redeem 自己 schedule 的 token，throws .selfRedemption

```
Given user A own schedule X 並 save invitation Y(token=T) for X
      （仍用 user A 的 session）
When  SupabaseInvitationRepository.redeem(token: T)
Then  throws RedeemInvitationError.selfRedemption
```

> 不再單獨測 INVALID_TOKEN（PG 端純粹 lookup 行為，INT-R1 已驗 RPC 連通性）。

### ViewModel — RedeemInvitationViewModel (7) ★

> 用 `FakeRedeemInvitationUseCase`（resultToReturn / errorToThrow）。

#### VN1. normalize 處理小寫、標點、過濾非 Crockford 字元

```
Given raw = "abcd-12 34!o"（含 lowercase / dash / space / 驚嘆號 / Crockford 字母表外的 'O'）
When  RedeemInvitationViewModel.normalize(raw)
Then  回傳 "ABCD1234"
```

#### VN2. normalize 截斷至 8 字元

```
Given raw = "ABCDEFGHJKMN"（12 字元）
When  RedeemInvitationViewModel.normalize(raw)
Then  回傳 "ABCDEFGH"（前 8 字元）
```

#### V1. updateInput 正規化並清掉先前的 inlineError

```
Given vm.inlineError = "redeemInvalidToken"
When  vm.updateInput("abcd1234")
Then  vm.input == "ABCD1234"，vm.inlineError == nil
```

#### V2. didTapSubmit 在 input 不到 8 字元時 no-op

```
Given vm.input == "ABC"（updateInput 之後），FakeUseCase callCount = 0
When  await vm.didTapSubmit()
Then  FakeUseCase.callCount == 0，vm.success == nil，vm.inlineError == nil
```

#### V3. didTapSubmit 成功，success state 設定為對應 Schedule

```
Given FakeUseCase.resultToReturn = Schedule X，
      vm.updateInput("ABCD1234")
When  await vm.didTapSubmit()
Then  vm.success?.schedule == X，
      vm.isSubmitting == false，
      vm.inlineError == nil
```

#### V4. didTapSubmit invalidToken，設 inlineError、input 保留

```
Given FakeUseCase.errorToThrow = .invalidToken，
      vm.updateInput("ABCD1234")
When  await vm.didTapSubmit()
Then  vm.success == nil，
      vm.inlineError == "redeemInvalidToken"，
      vm.input == "ABCD1234"（保留）
```

#### V5. didTapSubmit alreadyMember，inlineError 訊息對應

```
Given FakeUseCase.errorToThrow = .alreadyMember，vm.updateInput("ABCD1234")
When  await vm.didTapSubmit()
Then  vm.inlineError == "redeemAlreadyMember"
```

> .expired / .selfRedemption / .persistenceFailure 各自的訊息映射跟 V4/V5
> 同形（一行 switch case），不再各加 ViewModel 測；4 個分支已在 Usecase
> 測 R2-R5 涵蓋。**ViewModel 只挑 V4 / V5 兩個代表測 inlineError 寫入路徑**。

---

## Slice 3 — Student 看自己加入的 schedule ★

> Slice 3 在 `ScheduleListView` 同時呈現「我的課表」與「我加入的」兩個
> section。`ScheduleCalendarView` 自動 read-only — Slice 1 寫的 `isOwner`
> 已 gate 掉 toolbar 的「邀請」按鈕、calendar 本身無 edit affordance。

### Usecase — ListJoinedSchedulesUseCase (2) ★

> Fake 不需要：直接用 `InMemoryScheduleRepository` + `addMembership`
> 測試 helper + 既有 `InMemoryCurrentUserProvider`。

#### J1. 沒 membership 時查詢回傳空陣列

```
Given InMemoryRepo 沒被 addMembership(currentUser)，currentUser = teacher-001
When  呼叫 listJoinedSchedules()
Then  result.isEmpty
```

#### J2. 兩筆 membership 對應的 schedule 都會被回傳

```
Given repo 存兩個 owner 不是 teacher-001 的 schedule（X、Y），
      addMembership(X.id, teacher-001), addMembership(Y.id, teacher-001),
      另存一個第三方 schedule Z（沒有 X 也沒有 membership 連到 teacher-001）
When  呼叫 listJoinedSchedules()
Then  result.count == 2，titles 包含 X 與 Y
```

### ViewModel — ScheduleListViewModelTests 擴增 (4) ★

> 既有 8 個 onAppear / didConfirmCreate / retry test 全數 migrate：
> `vm.schedules` → `vm.ownedSchedules`、`vm.loadError` → `vm.ownedLoadError`、
> `vm.retry()` → `vm.retryOwned()`、`makeSUT` 多接 joined fake。

#### M1. owned + joined 都成功 — 兩個 array 都填、兩個 error nil

```
Given fakeOwned 回 [A]，fakeJoined 回 [B]
When  await vm.onAppear()
Then  vm.ownedSchedules.titles == ["我的瑜珈班"]
      vm.joinedSchedules.titles == ["阿明的吉他課"]
      vm.ownedLoadError == nil && vm.joinedLoadError == nil
      vm.isFullScreenError == false
```

#### M2. owned 成功、joined 失敗 — 只設 joinedLoadError、不觸發 full-screen error

```
Given fakeOwned 回 [A]，fakeJoined throws
When  await vm.onAppear()
Then  vm.ownedSchedules.count == 1, vm.joinedSchedules.isEmpty,
      vm.ownedLoadError == nil, vm.joinedLoadError != nil,
      vm.isFullScreenError == false
```

#### M3. owned 為空、joined 有 1 筆 — vm.isEmpty == false（驅動「只顯示 joined section」UI）

```
Given fakeOwned 回 []，fakeJoined 回 [B]
When  await vm.onAppear()
Then  vm.ownedSchedules.isEmpty, vm.joinedSchedules.count == 1,
      vm.isEmpty == false
```

#### M4. 兩邊都失敗 — 兩個 error 都設、isFullScreenError == true

```
Given 兩個 fake 都 throws
When  await vm.onAppear()
Then  vm.ownedLoadError != nil, vm.joinedLoadError != nil,
      ownedSchedules.isEmpty, joinedSchedules.isEmpty,
      vm.isFullScreenError == true
```

> Concurrent fetch flicker 風險：`onAppear` 採「兩個 fetch 都 await 完
> 再一次性 assign」atomic 設計（`async let owned / joined` → `let (o, j)
> = await (...)` → 一次寫入），中間態不會被 SwiftUI 渲染。

### Infrastructure 整合測試 (2) ★

> 擴 `SupabaseIntegrationTests` 加 `JoinedSchedules` sub-suite。

#### INT-J1. user B redeem A 的 invitation 後，fetchAll(memberOf: B) 回傳 A 的 schedule（含 rules + windows）

```
Given user A 已 own schedule X with 1 rule + 1 window,
      A 建 invitation Y for X,
      切到 user B、redeem Y → membership 寫入
When  以 user B 身份 SupabaseScheduleRepository.fetchAll(memberOf: B.id)
Then  結果含 X，X.rules.count == 1，X.windows.count == 1
      （驗 schedules / availability_rules / availability_windows 三表的
        member_select policy 都生效）
```

#### INT-J2. user B 對沒被邀請的 schedule，fetchAll(memberOf: B) 不會看到

```
Given A own 一個全新 schedule Y（沒有任何 invitation 或 redemption）
When  切到 user B、SupabaseScheduleRepository.fetchAll(memberOf: B.id)
Then  !result.contains(where: { $0.id == Y.id })
```

> 不寫 `joined.isEmpty`：先前 INT-J1 / Slice 2 整合測試會在 DB 留下 B 對
> 其他 schedule 的 membership row（test 之間不 reset），故合約是
> 「這個沒邀請的 Y 不可見」、不是「joined 全空」。

### Decoder 隔離 unit test (1) ★

> 純 JSON decode 測試，不打 server，僅驗證 `MembershipScheduleRowDTO`
> 對 PostgREST embedded resource shape 的解碼正確、`convertFromSnakeCase`
> 有遞迴套到 `availability_rules` / `availability_windows`。失敗時可獨立
> 排除「embedded select 寫法錯」與「DB / RLS 問題」。

| # | Scenario | function name |
|---|---|---|
| D1 | 用 `[{schedules: {…with availability_rules + availability_windows}}]` 樣本 JSON 解出 nested 結構 | `decode_postgrestEmbeddedShape_populatesNestedRulesAndWindows()` |

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
| R1. Valid token 回傳 Schedule | `redeemInvitation_valid_returnsSchedule()` |
| R2. Token 不存在 | `redeemInvitation_invalidToken_throwsInvalidToken()` |
| R6. schedule fetch 失敗 | `redeemInvitation_scheduleFetchFails_throwsPersistenceFailure()` |
| INT-R1. User B redeem user A token | `redeemValidToken_createsMembershipAndReturnsRedemption()` |
| INT-R3. 同 user 第二次 redeem | `redeemTwiceSameUser_throwsAlreadyMember()` |
| VN1. normalize 處理小寫 + 標點 | `normalize_lowercaseAndPunctuation_uppercasesAndFilters()` |
| V2. didTapSubmit 不到 8 字元 | `didTapSubmit_belowEightChars_doesNothing()` |
| V3. didTapSubmit 成功 | `didTapSubmit_success_setsSuccessStateWithSchedule()` |
| V4. didTapSubmit invalidToken | `didTapSubmit_invalidToken_setsInlineErrorAndKeepsInput()` |

剩餘 scenarios 依此命名規則延伸。
