@testable import Shared_Schedule

final class FakeListSchedulesUseCase: ListSchedulesUseCaseProtocol, @unchecked Sendable {
    var schedulesToReturn: [Schedule] = []

    func listSchedules() async throws -> [Schedule] {
        schedulesToReturn
    }
}
