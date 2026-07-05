import Foundation

@Observable
final class LanguageManager {
    private static let storageKey = "app.language.selected"

    private let defaults: UserDefaults

    private(set) var current: LanguageOption

    var overrideLocale: Locale? {
        current.overrideLocale
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        self.current = LanguageOption(rawValue: raw) ?? .system
    }

    func select(_ option: LanguageOption) {
        guard option != current else { return }
        current = option
        defaults.set(option.rawValue, forKey: Self.storageKey)
    }
}
