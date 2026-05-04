@testable import Shared_Schedule

final class FakeListJoinedSchedulesUseCase: ListJoinedSchedulesUseCaseProtocol, @unchecked Sendable {
    var schedulesToReturn: [Schedule] = []
    var errorToThrow: Error?

    func listJoinedSchedules() async throws -> [Schedule] {
        if let error = errorToThrow { throw error }
        return schedulesToReturn
    }
}
