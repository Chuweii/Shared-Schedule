import Foundation

/// In-app display-language choice. `rawValue` doubles as the persisted
/// storage token and (for non-system cases) the locale identifier —
/// changing a rawValue breaks previously stored selections.
enum LanguageOption: String, CaseIterable, Identifiable {
    case system
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    /// Locale to pin via `.environment(\.locale, ...)`; `nil` means
    /// follow the device language (apply no override).
    var overrideLocale: Locale? {
        switch self {
        case .system: nil
        case .traditionalChinese, .english, .japanese: Locale(identifier: rawValue)
        }
    }
}
