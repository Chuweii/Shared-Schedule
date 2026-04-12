# Coding Conventions

> Loaded by Claude when naming files, writing commits, picking colors,
> adding strings, or checking App Store readiness. See `CLAUDE.md` §3
> routing.

---

## 1. File & type naming

- File names mirror the primary type they contain: `BookingViewModel.swift`,
  `Schedule.swift`.
- Extensions follow the existing `Color+Semantic.swift` pattern:
  `Type+Aspect.swift`.
- Test files: `<TypeUnderTest>Tests.swift`, mirroring the production folder.

---

## 2. Commit messages

- **Prefix every commit subject** with one of:
  `feature` / `fix` / `chore` / `refactor` / `test` / `docs`
- Format: `<prefix>: <imperative summary in English>`
  - ✅ `feature: add booking confirmation flow`
  - ✅ `fix: prevent overlapping availability windows`
  - ❌ `Added booking flow.`
- Subject line ≤ 72 characters; body wraps at 72.
- **Body explains the *why*, not the *what*.** The diff already shows the
  what.
- **Never** `--no-verify`. **Never** force-push to `main`. **Never** create
  a commit without explicit user instruction.

---

## 3. Color usage

- **Always go through `SemanticColor`.** Never reference primitive colors
  (`Color.gray700`, etc.) directly from a `View`.
- When the design needs a color the semantic layer doesn't expose, **add a
  semantic token first**, then use it. Don't reach into primitives as a
  shortcut.
- **New primitive colors** follow: one color one name, numeric-first
  differentiation. Refactor to a hue-prefix only when the palette already
  has multiple saturated variants of that hue.
- Theme system already covers Dark Mode — do not write custom
  light/dark switches inside views.

---

## 4. Localization

- All user-facing strings go through **String Catalog (`.xcstrings`)**.
- **Hard-coded user-facing strings are not allowed**, even in prototypes.
- Catalog languages: `zh-Hant` (default) + `en` + `ja`.
- **Every new user-facing string must be added to all three locales
  before the feature is considered complete.** Leaving a string
  untranslated in `en` or `ja` counts as an unfinished feature, not a
  follow-up task.
- Use the key as plain English text (Apple's recommended pattern), not
  symbolic IDs.

---

## 5. Code style

- **Comments**: don't write comments unless the *why* is non-obvious.
  Identifier names should carry the *what*. Never write multi-paragraph
  doc-comments.
- **No premature abstraction.** Three similar lines beats a wrong
  abstraction. Wait for the third use site before extracting.
- **No "just in case" error handling.** Validate at system boundaries
  (user input, network, persistence). Trust internal code.
- **No backwards-compatibility shims.** If something is removed, delete it
  cleanly — don't leave `// removed` comments or unused re-exports.

---

## 6. Logging

- Use the existing logger (or `os.Logger` if no project logger exists).
  **Never** use `print(`.
- Log levels follow Apple's `OSLogType`: `debug` / `info` / `notice` /
  `error` / `fault`.

---

## 7. Xcode project

- The project uses **`PBXFileSystemSynchronizedRootGroup`** (Xcode 16+).
  Any `.swift` file placed under `App/` is automatically included in the
  main app target; any `.swift` file under `Shared ScheduleTests/` is
  automatically included in the test target. **No manual
  `project.pbxproj` edits are needed** when adding new source files —
  just create the file at the right path.
- **`SWIFT_VERSION = 6.0`** (Swift 6 language mode). All code compiles
  under strict concurrency. Domain types use `nonisolated` to opt out
  of the project-wide `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- **Do NOT drag `CLAUDE.md` or `docs/` into Xcode's Project Navigator.**
  Xcode may auto-add them to a target's Resources build phase. Edit
  these files in VS Code / Cursor / any text editor outside Xcode.

---

## 8. App Store Readiness Checklist

Refer to this list as the app approaches ship-ready. Items are tracked in
PR descriptions or a dedicated issue — **do not edit this list to mark
progress unless explicitly asked**.

- [ ] App Icon — all required sizes
- [ ] Launch Screen
- [ ] Privacy Manifest (`PrivacyInfo.xcprivacy`)
- [ ] App Tracking Transparency prompt (if any tracking is added)
- [ ] Sign in with Apple (required when offering any third-party login)
- [ ] Privacy Policy URL + Terms of Service URL
- [ ] Screenshots — 6.7" / 6.1" / iPad
- [ ] Accessibility — Dynamic Type, VoiceOver labels, color contrast
- [ ] Dark Mode — covered by the existing theme system
- [ ] Localization — zh-Hant + en + ja (all three required before ship)
- [ ] Crash reporting — MetricKit or Sentry
- [ ] App Store Connect metadata, keywords, age rating, export compliance
