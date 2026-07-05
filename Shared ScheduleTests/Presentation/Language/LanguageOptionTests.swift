import Testing
import Foundation
@testable import Shared_Schedule

struct LanguageOptionTests {

    @Test("LO1. rawValue 為穩定儲存格式 — system / zh-Hant / en / ja")
    func rawValues_areStableStorageTokens() {
        // Given
        let options = LanguageOption.allCases

        // When
        let rawValues = options.map(\.rawValue)

        // Then — persisted format; changing these breaks stored selections
        #expect(rawValues == ["system", "zh-Hant", "en", "ja"])
    }

    @Test("LO2. 跟隨系統不覆寫 locale — .system 的 overrideLocale 為 nil")
    func overrideLocale_system_isNil() {
        // Given
        let option = LanguageOption.system

        // When
        let locale = option.overrideLocale

        // Then
        #expect(locale == nil)
    }

    @Test("LO3. 語言選項對應正確 locale — zh-Hant / en / ja")
    func overrideLocale_languages_matchIdentifiers() {
        // Given
        let expectations: [(LanguageOption, String)] = [
            (.traditionalChinese, "zh-Hant"),
            (.english, "en"),
            (.japanese, "ja")
        ]

        for (option, identifier) in expectations {
            // When
            let locale = option.overrideLocale

            // Then
            #expect(locale == Locale(identifier: identifier))
        }
    }
}
