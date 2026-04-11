# Architecture — DDD + MVVM

> Loaded by Claude when starting a feature, adding a layer, or deciding
> where a piece of code belongs. See `CLAUDE.md` §3 routing.

---

## 1. Layers

The codebase follows **DDD layering** with **MVVM** inside the Presentation
layer. Folders are organized by **vertical slice** (per feature), not by
technical layer alone.

| Layer | Folder | Responsibility | Allowed dependencies |
|---|---|---|---|
| **Domain** | `App/Domain/` | Entities, Value Objects, Domain Services, Repository **protocols**. Pure business rules. | Swift stdlib + `Foundation` only. **No** SwiftUI / Combine / Supabase / any third-party SDK. |
| **Usecase** | `App/Usecase/` | Application layer. Use cases that orchestrate Domain objects via Repository protocols. Defines input/output boundaries. | Domain only. (`Usecase/` ≡ Application layer; the name is kept to match existing folders.) |
| **Infrastructure** | `App/Infrastructure/` *(to be created)* | Concrete implementations: `SupabaseClient` wrapper, Repository implementations, DTOs, mappers, Keychain / UserDefaults adapters, Realtime channels. | Domain + Usecase + third-party SDKs. |
| **Presentation** | `App/Presentation/` | SwiftUI Views and ViewModels, navigation, theme integration. | Usecase + Domain models (read-only). **Never** Infrastructure directly. |

---

## 2. Hard rules (never violate)

1. **Domain stays framework-free.** No `import SwiftUI`, no `import Combine`,
   no `import Supabase`. If you find yourself wanting to, the abstraction
   belongs in Usecase or Infrastructure.
2. **ViewModels depend on Usecase protocols, not Repositories.** Repositories
   live behind Usecases.
3. **Repository protocols live in Domain; implementations live in
   Infrastructure.** This is the dependency-inversion seam — Infrastructure
   depends on Domain, never the other way around.
4. **DTOs (Supabase response shapes) stay inside Infrastructure.** Map
   DTO → Domain at the boundary. Never let `Codable` Supabase types leak
   into Usecase or Presentation.
5. **Vertical slicing.** When you add a feature, create matching folders in
   each layer (`Domain/X/`, `Usecase/X/`, `Infrastructure/X/`,
   `Presentation/X/`) — do not pile everything into one mega-folder per layer.
6. **Dependency injection by `init` parameters.** ViewModels and Usecases
   receive their dependencies through `init`, with concrete defaults if
   useful. **Never** reach into a global container or singleton from new
   code.

---

## 3. Domain concepts — aggregates, invariants, and just-in-time growth

Before the booking aggregates table below, here are the two terms that table
relies on, plus the rule that governs when Domain code gets written at all.

### Aggregate

An **aggregate** is a cluster of Domain objects that change together, with
one **root** as the only legal entry point from the outside. External code
never bypasses the root to touch internals — it goes through methods on the
root. Only the root sees all internal objects at once, which is the only
position from which cross-object rules can be enforced.

Example — the `Schedule` aggregate:

```
Schedule (root)              ← external code only holds references to Schedule
├── AvailabilityWindow       ← internal; never mutated directly from outside
├── AvailabilityWindow
└── AvailabilityWindow
```

```swift
// ❌ Illegal — external code reaching into internals
let window = schedule.windows[0]
window.start = newDate

// ✅ Legal — go through the root, which can enforce cross-window rules
schedule.moveWindow(id: windowID, to: newStart)
```

### Invariant

An **invariant** is a rule that MUST always be true for the aggregate to be
in a valid state. The aggregate root's methods exist to enforce these rules
— if an operation would break an invariant, the method rejects it (returns
a failure / throws) instead of performing a partial update.

Example — invariants on the `Schedule` aggregate:

1. Two `AvailabilityWindow`s in the same `Schedule` MUST NOT overlap in time
2. Only the teacher whose `id` matches `schedule.ownerID` may modify it
3. A window's `end` MUST be strictly after its `start`
4. A window MUST have a minimum duration (product-defined; e.g. 15 minutes)

Each invariant typically generates **one success test** (the operation goes
through) **and one failure test** (the operation is rejected). These tests
are written first (TDD red), and the aggregate code is then grown to
satisfy them.

### Just-in-time Domain growth

The booking aggregates table in §4 is a **map of expected shapes, not a
checklist to pre-build**. Concretely:

- **No aggregate is written before the first feature that needs it.** If
  today's feature only needs `Schedule`, we do not pre-emptively create
  `Booking` / `Membership` / `Invitation` / `Identity`.
- **Aggregates evolve through later features.** When a subsequent feature
  needs to extend an earlier aggregate (e.g. adding `RecurrenceRule` to
  `Schedule` when the recurrence feature arrives), we go back into plan
  mode, discuss the extension with the user, and let new tests drive the
  change. **This is not rework — this is DDD working correctly.**
- **Shared value objects** (like `DateRange`, `TimeZone` wrappers) live
  under `Domain/Shared/` only when a second feature actually needs them.
  No speculative shared types.

In practice this means every new feature's plan (see `docs/workflow.md`
Stage 1b) explicitly discusses: which aggregate this feature touches, what
invariants it introduces or depends on, and whether an existing aggregate
needs to be extended.

---

## 4. Booking Domain — aggregate boundaries

| Aggregate | Entities / VOs | Key invariants |
|---|---|---|
| **Schedule** (owned by a teacher) | `Schedule`, `AvailabilityWindow`, `RecurrenceRule` | Availability windows must not overlap; only the owning teacher can edit. |
| **Booking** (made by a student) | `Booking`, `BookingStatus` (`pending` / `confirmed` / `cancelled`), `BookingSlot` | A booking must fall inside an `AvailabilityWindow`; a student can't book the same slot twice. |
| **Membership** | `Membership`, `MemberRole` | A student must hold an active `Membership` to a `Schedule` before booking. |
| **Invitation** | `InvitationToken`, `InvitationStatus`, `ExpiresAt` | A token can be redeemed at most once; expired tokens cannot be redeemed. |
| **Identity** | `User`, `Profile` | Identity is per-user, but role (teacher / student) is **per-Membership**, not global. |

> **Important**: a single `User` may be a teacher in one `Schedule` and a
> student in another. Do not model `role` as a top-level field on `User`.
> Role belongs on `Membership`.

---

## 5. MVVM Conventions

- **View**: dumb. Bindings + intent dispatch only. No business logic, no
  networking, no formatting beyond what SwiftUI gives you for free.
- **ViewModel**: holds screen state, calls Usecases, handles loading and
  error mapping. One ViewModel per screen.
- **Use the Swift `@Observable` macro** (the iOS 26 deployment target permits
  it). Don't use `ObservableObject` / `@Published` for new code.
- **Method names follow user intent**: `onAppear()`, `didTapBook(slot:)`,
  `refresh()`, `didConfirmCancel()`. Not `loadData()` / `setBooking()`.
- **Shared state across screens** belongs in a parent feature coordinator,
  not a singleton.
- **Delegates** (when needed) are declared as
  `protocol XxxDelegate: AnyObject` and held as `private weak var delegate`.

---

## 6. Target Directory Map

This is the **target** structure. It is built incrementally — do not create
empty folders ahead of time. Scaffold a folder only when you have real code
to put in it.

```
App/
├── Domain/                    Pure Swift, framework-free
│   ├── Schedule/              Schedule aggregate, AvailabilityWindow, RecurrenceRule
│   ├── Booking/               Booking aggregate, BookingStatus
│   ├── Membership/            Membership, MemberRole
│   ├── Invitation/            InvitationToken, InvitationStatus
│   ├── Identity/              User, Profile
│   └── Shared/                Shared VOs (DateRange, TimeZone wrappers, etc.)
│
├── Usecase/                   Application layer; orchestrates Domain
│   ├── Schedule/
│   ├── Booking/
│   ├── Membership/
│   ├── Invitation/
│   └── Identity/
│
├── Infrastructure/            (to be created) Concrete implementations
│   ├── Supabase/
│   │   ├── Repositories/      Domain protocol implementations
│   │   ├── DTOs/              Codable structs from Supabase
│   │   └── Mappers/           DTO ↔ Domain
│   ├── Persistence/           UserDefaults, Keychain adapters
│   └── Realtime/              Supabase Realtime channel wrappers
│
├── Presentation/              SwiftUI Views + ViewModels
│   ├── Schedule/
│   ├── Booking/
│   ├── Onboarding/            Sign-in, accept invitation
│   ├── Settings/              (existing) ThemeSettingsView
│   └── Shared/                Reusable components, navigation
│
└── Resources/
    ├── DesignSystem/          (existing) ColorSystem, typography, spacing
    └── Localizations/         .xcstrings catalogs
```
