import Foundation

nonisolated enum Weekday: Int, CaseIterable, Hashable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    static func from(date: Date, calendar: Calendar = .current) -> Weekday {
        let component = calendar.component(.weekday, from: date)
        return Weekday(rawValue: component)!
    }
}
