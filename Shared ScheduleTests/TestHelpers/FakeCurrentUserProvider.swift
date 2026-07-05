import Foundation
@testable import Shared_Schedule

final class FakeCurrentUserProvider: CurrentUserProviderProtocol, @unchecked Sendable {
    var user: User

    init(user: User) {
        self.user = user
    }

    var currentUser: User { user }
}
