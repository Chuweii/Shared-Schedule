import Foundation
@testable import Shared_Schedule

final class FakeUserProfileRepository: UserProfileRepositoryProtocol, @unchecked Sendable {
    var createError: UserProfileError?
    var createResult: UserProfile?
    var fetchError: UserProfileError?
    var fetchResult: UserProfile?
    var updateError: UserProfileError?
    var updateResult: UserProfile?

    private(set) var createCount = 0
    private(set) var lastCreateDisplayName: String?
    private(set) var fetchCount = 0
    private(set) var lastFetchUserID: UserID?
    private(set) var updateCount = 0
    private(set) var lastUpdateDisplayName: String?

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

    func update(displayName: String) async throws(UserProfileError) -> UserProfile {
        updateCount += 1
        lastUpdateDisplayName = displayName
        if let updateError { throw updateError }
        guard let updateResult else { throw .persistenceFailure }
        return updateResult
    }
}
