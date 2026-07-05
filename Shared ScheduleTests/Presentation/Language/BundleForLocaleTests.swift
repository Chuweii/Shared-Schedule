import Testing
import Foundation
@testable import Shared_Schedule

/// `Bundle.forLocale(_:)` backs navigation-bar titles: the bar only
/// refreshes when the passed *value* changes, so titles are resolved
/// through the selected language's bundle instead of a
/// `LocalizedStringKey` (see language-settings spec, Technical Notes).
struct BundleForLocaleTests {

    @Test("BFL1. 覆寫語言 en → 用 en.lproj 解析（課表 → Schedules）")
    func forLocale_english_resolvesFromEnglishLproj() {
        // Given
        let locale = Locale(identifier: "en")

        // When
        let resolved = String(localized: "課表", bundle: .forLocale(locale))

        // Then
        #expect(resolved == "Schedules")
    }

    @Test("BFL2. 覆寫語言 ja → 用 ja.lproj 解析（課表 → スケジュール）")
    func forLocale_japanese_resolvesFromJapaneseLproj() {
        // Given
        let locale = Locale(identifier: "ja")

        // When
        let resolved = String(localized: "課表", bundle: .forLocale(locale))

        // Then
        #expect(resolved == "スケジュール")
    }

    @Test("BFL3. 覆寫語言 zh-Hant → 解析回中文原文（課表）")
    func forLocale_traditionalChinese_resolvesSourceString() {
        // Given
        let locale = Locale(identifier: "zh-Hant")

        // When
        let resolved = String(localized: "課表", bundle: .forLocale(locale))

        // Then
        #expect(resolved == "課表")
    }

    @Test("BFL4. 無對應 .lproj 的 locale → 回退 Bundle.main（跟隨系統）")
    func forLocale_unmatchedLocale_fallsBackToMain() {
        // Given — a locale identifier with no matching .lproj in the app
        let locale = Locale(identifier: "xx-Unknown")

        // When
        let bundle = Bundle.forLocale(locale)

        // Then
        #expect(bundle === Bundle.main)
    }
}
