import Foundation
@testable import Shared_Schedule

final class FakeUserProfileRepository: UserProfileRepositoryProtocol, @unchecked Sendable {
    var createError: UserProfileError?
    var createResult: UserProfile?
    var fetchError: UserProfileError?
    var fetchResult: UserProfile?

    private(set) var createCount = 0
    private(set) var lastCreateDisplayName: String?
    private(set) var fetchCount = 0
    private(set) var lastFetchUserID: UserID?

    func create(displayName: String) async throws(UserProfileError) -> UserProfile {
        createCount += 1
        lastCreateDisplayName = displayName
        if let createError { throw createError }
        guard let createResult else { throw .persistenceFailure }
        return createResult
    }

    func fetch(userID: UserID) async throws(UserProfileError) -> UserProfile? {
        fetchCount += 1
        lastFetchUserID = userID
        if let fetchError { throw fetchError }
        return fetchResult
    }
}
