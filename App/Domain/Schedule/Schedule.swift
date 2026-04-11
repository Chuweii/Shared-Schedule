import Foundation

nonisolated struct Schedule: Sendable {
    static let defaultMinWindowDuration: TimeInterval = 3600

    let id: ScheduleID
    let ownerID: UserID
    let title: String
    let minWindowDuration: TimeInterval
    private(set) var windows: [AvailabilityWindow]

    init(
        id: ScheduleID = ScheduleID(),
        ownerID: UserID,
        title: String,
        minWindowDuration: TimeInterval = Schedule.defaultMinWindowDuration
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.minWindowDuration = minWindowDuration
        self.windows = []
    }

    mutating func addWindow(
        id: AvailabilityWindowID = AvailabilityWindowID(),
        start: Date,
        end: Date
    ) throws {
        guard end > start else {
            throw ScheduleError.invalidRange
        }

        let duration = end.timeIntervalSince(start)
        guard duration >= minWindowDuration else {
            throw ScheduleError.belowMinimumDuration
        }

        for existing in windows {
            if start < existing.end && existing.start < end {
                throw ScheduleError.overlapping
            }
        }

        windows.append(AvailabilityWindow(id: id, start: start, end: end))
    }
}
