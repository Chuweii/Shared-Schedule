import Foundation

nonisolated struct CalendarDay: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let isCurrentMonth: Bool
    let hasRule: Bool
    let isToday: Bool
}
