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
