@testable import Shared_Schedule

final class FakeListSchedulesUseCase: ListSchedulesUseCaseProtocol, @unchecked Sendable {
    var schedulesToReturn: [Schedule] = []
    var errorToThrow: Error?

    func listSchedules() async throws -> [Schedule] {
        if let error = errorToThrow { throw error }
        return schedulesToReturn
    }
}
