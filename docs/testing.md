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

- **UI prototype phase** (laying out SwiftUI screens, exploring interactions,
  tweaking layout) — tests are **not** required. Iterate freely on previews.
- **Once you enter Domain / Usecase / Infrastructure** — **test-first**.
  Red → green → refactor. No exceptions.
- **ViewModel logic** (state transitions, error mapping, intent handling) —
  also test-first.
- **Pure View snapshot tests** are not required. ViewModels MUST be covered.

---

## 4. Test categories

| Category | What it covers | Dependencies |
|---|---|---|
| **Domain unit tests** | Pure aggregate behavior, invariants | None — pure functions |
| **Usecase tests** | Use case orchestration, error mapping | In-memory fake repositories |
| **ViewModel tests** | State transitions, intent handling | In-memory fake usecases |
| **Infrastructure integration tests** | Real Supabase queries, RLS, mappers | `supabase start` local stack |

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
