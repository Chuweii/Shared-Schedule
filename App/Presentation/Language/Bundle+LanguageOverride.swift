import Foundation

extension Bundle {
    /// Bundle whose `.lproj` matches the locale's identifier, falling
    /// back to `.main` when there is no exact match — which is exactly
    /// right for Follow System (device language drives the lookup).
    ///
    /// Needed for navigation-bar titles: the bar only refreshes when
    /// the passed *value* changes, so a `LocalizedStringKey` title goes
    /// stale after an in-app language switch. Resolving the title as
    /// `String(localized:bundle:)` through this bundle makes the value
    /// itself change with the selection.
    static func forLocale(_ locale: Locale) -> Bundle {
        guard let path = main.path(forResource: locale.identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
