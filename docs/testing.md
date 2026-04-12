# Testing Strategy

> Loaded by Claude when writing any test, designing test scaffolding, or
> deciding whether code is ready to ship. See `CLAUDE.md` §3 routing.

---

## 1. Framework

- **Swift Testing only** (`import Testing`, `@Test`, `#expect`, `#require`).
- **XCTest is banned** for new tests. The existing empty `Shared_ScheduleTests`
  file should be migrated when first touched.

---

## 2. BDD format — Given / When / Then

Both the **test name** and the **test body** must follow Given / When / Then.
The test name describes the scenario in plain language; the body is split
with `// Given` / `// When` / `// Then` comments.

```swift
import Testing
@testable import Shared_Schedule

@Test("Given a booked slot, when another student tries to book the same slot, then the second booking is rejected")
func bookSlot_alreadyTaken_isRejected() {
    // Given
    let window = AvailabilityWindow.sample(start: .now, duration: .oneHour)
    var schedule = Schedule(owner: .teacherA, windows: [window])
    _ = schedule.book(window: window, by: .studentA)

    // When
    let result = schedule.book(window: window, by: .studentB)

    // Then
    #expect(result == .failure(.slotAlreadyBooked))
}
```

### Test name → Scenario mapping

Test function names MUST mirror the scenario titles in
`docs/features/<feature>/scenarios.md` so a reader can grep from doc to
test in either direction. The `@Test` description is the human-readable
form; the function name is the camelCase form of the same scenario.

---

## 3. TDD pacing

- **Domain / Usecase / Infrastructure / ViewModel logic** — **test-first**,
  no exceptions. Red → green → refactor, one scenario at a time.
- **SwiftUI View construction happens AFTER the ViewModel is green.**
  See `docs/workflow.md` Stage 3 for the full slice ordering. The only
  exception is when a design reference exists (Figma / Sketch) and you
  want to validate design fidelity early — in that case an early
  prototype is allowed, but the polished final View still lands after
  the VM is green.
- **Pure layout work** (view composition, `#Preview`, spacing / typography
  tweaks, `@State` for purely local UI concerns) does not require tests.
  Iterate freely on previews once the underlying VM is stable.
- **Pure View snapshot tests are not required.** ViewModels MUST be covered.

---

## 4. Test categories and test doubles

Each layer mocks **only the layer directly below it** — never skip
layers.

| Category | What it covers | Test double used | What it proves |
|---|---|---|---|
| **Domain unit tests** | Aggregate behavior, invariants | None — pure functions | Business rules are correct |
| **UseCase tests** | Orchestration, validation, error mapping | Fake **Repository** + Fake **CurrentUserProvider** | UseCase logic is correct given controlled repo state |
| **ViewModel tests** | State transitions, intent → state | Fake **UseCase** | VM reacts correctly to UseCase results/errors |
| **Infrastructure integration tests** | Real Supabase queries, RLS | `supabase start` local stack | Persistence + RLS policies work |

### Test double pattern

**Fake UseCase** (used in ViewModel tests):

```swift
final class FakeCreateScheduleUseCase: CreateScheduleUseCaseProtocol {
    var resultToReturn: Schedule?
    var errorToThrow: CreateScheduleError?

    func createSchedule(
        title: String,
        minWindowDuration: TimeInterval
    ) async throws(CreateScheduleError) -> Schedule {
        if let error = errorToThrow { throw error }
        return resultToReturn ?? Schedule(
            ownerID: UserID("teacher-001"),
            title: title,
            minWindowDuration: minWindowDuration
        )
    }
}
```

**Key**: the fake has settable `resultToReturn` / `errorToThrow`
properties. Tests configure these in the **Given** block to control
what the ViewModel receives, without knowing anything about
repositories or infrastructure.

**Fake Repository** (used in UseCase tests): use `InMemoryScheduleRepository`
(an `actor` backed by a `[ScheduleID: Schedule]` dictionary). This is
the same in-memory implementation used in the app during Phase 1 mock.

### BDD actor per layer

Given / When / Then is used at every layer, but the **actor** (who
performs the "When" action) changes:

| Layer | Who is the actor in "When"? | Example |
|---|---|---|
| **Domain** | Code calling the aggregate method | `schedule.addWindow(...)` |
| **UseCase** | The ViewModel calling the UseCase | `useCase.createSchedule(...)` |
| **ViewModel** | The **human user** performing an intent | `vm.didConfirmCreate()` |

**In ViewModel tests, you should NEVER call a UseCase directly.** The
UseCase call is hidden inside the ViewModel's intent method. The test
only knows "the user tapped confirm" → "the screen shows X."

---

## 5. Test folder layout

Test folders **mirror** production code:

```
Shared ScheduleTests/
├── Domain/
│   ├── Schedule/
│   ├── Booking/
│   └── …
├── Usecase/
│   ├── Schedule/
│   └── …
├── Infrastructure/
│   └── Supabase/
└── Presentation/
    ├── Schedule/
    └── …
```

A scenario `BookSlot_AlreadyTaken_IsRejected` from
`docs/features/booking/scenarios.md` lives at
`Shared ScheduleTests/Domain/Booking/BookingTests.swift`.

---

## 6. Conventions

- **One test, one scenario.** Don't combine multiple Given/When/Then blocks
  into the same test function.
- **Sample factories live next to the type they test** (e.g.
  `extension Schedule { static var sample: Schedule { … } }`) inside the
  test target, not the production target.
- **No real network, no real database** in unit tests. If you need it, it
  belongs in Infrastructure integration tests.
- **No `Thread.sleep` in tests.** Use `async` / `await` and Swift Testing's
  `confirmation()` helper for asynchronous expectations.
- **Test data is explicit.** Don't rely on `Date()` or random UUIDs without
  pinning them — pass explicit values so failures are reproducible.
