import Testing
import Foundation
@testable import Shared_Schedule

@MainActor
struct LanguageManagerTests {

    private static let storageKey = "app.language.selected"

    /// Fresh, isolated defaults per test — explicit suite name for
    /// reproducibility, wiped before use so earlier runs can't leak in.
    private func makeDefaults(_ suiteName: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("LM1. 從未選過 → 預設跟隨系統")
    func init_emptyDefaults_defaultsToSystem() {
        // Given
        let defaults = makeDefaults("test.language.lm1")

        // When
        let manager = LanguageManager(defaults: defaults)

        // Then
        #expect(manager.current == .system)
        #expect(manager.overrideLocale == nil)
    }

    @Test("LM2. 已存選擇 → 啟動時還原")
    func init_storedRawValue_restoresSelection() {
        // Given
        let defaults = makeDefaults("test.language.lm2")
        defaults.set("ja", forKey: Self.storageKey)

        // When
        let manager = LanguageManager(defaults: defaults)

        // Then
        #expect(manager.current == .japanese)
        #expect(manager.overrideLocale == Locale(identifier: "ja"))
    }

    @Test("LM3. 儲存值毀損 → 安全回退跟隨系統")
    func init_corruptStoredValue_fallsBackToSystem() {
        // Given
        let defaults = makeDefaults("test.language.lm3")
        defaults.set("klingon", forKey: Self.storageKey)

        // When
        let manager = LanguageManager(defaults: defaults)

        // Then
        #expect(manager.current == .system)
    }

    @Test("LM4. 選擇語言 → 更新並持久化")
    func select_persistsRawValueAndUpdatesCurrent() {
        // Given
        let defaults = makeDefaults("test.language.lm4")
        let manager = LanguageManager(defaults: defaults)

        // When
        manager.select(.english)

        // Then
        #expect(manager.current == .english)
        #expect(manager.overrideLocale == Locale(identifier: "en"))
        #expect(defaults.string(forKey: Self.storageKey) == "en")
    }

    @Test("LM5. 重複選同一語言 → no-op")
    func select_sameOption_isNoOp() {
        // Given — select once, then clear the stored value so a second
        // (guarded) select would be observable if it wrote again
        let defaults = makeDefaults("test.language.lm5")
        let manager = LanguageManager(defaults: defaults)
        manager.select(.english)
        defaults.removeObject(forKey: Self.storageKey)

        // When
        manager.select(.english)

        // Then
        #expect(manager.current == .english)
        #expect(defaults.string(forKey: Self.storageKey) == nil)
    }

    @Test("LM6. 重啟 App → 選擇保留")
    func select_thenNewManagerOnSameDefaults_restoresSelection() {
        // Given
        let defaults = makeDefaults("test.language.lm6")
        let firstLaunch = LanguageManager(defaults: defaults)
        firstLaunch.select(.english)

        // When — a new manager on the same defaults simulates relaunch
        let secondLaunch = LanguageManager(defaults: defaults)

        // Then
        #expect(secondLaunch.current == .english)
    }
}
