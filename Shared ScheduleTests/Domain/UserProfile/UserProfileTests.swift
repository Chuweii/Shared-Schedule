import Testing
import Foundation
@testable import Shared_Schedule

struct UserProfileTests {

    private static let userID = UserID("a1b2c3d4-e5f6-7890-abcd-ef1234567890")

    @Test("UD1. 有效 displayName 建立 UserProfile，trim 後保留")
    func createUserProfile_validDisplayName_succeeds() throws {
        // Given
        let raw = "  小明  "

        // When
        let profile = try UserProfile(userID: Self.userID, displayName: raw)

        // Then
        #expect(profile.userID == Self.userID)
        #expect(profile.displayName == "小明")
    }

    @Test("UD2. 空字串 displayName，throws .invalidDisplayName")
    func createUserProfile_emptyDisplayName_throwsInvalidDisplayName() {
        // When / Then
        #expect(throws: UserProfileError.invalidDisplayName) {
            _ = try UserProfile(userID: Self.userID, displayName: "")
        }
    }

    @Test("UD3. 全 whitespace displayName（trim 後空），throws .invalidDisplayName")
    func createUserProfile_whitespaceOnly_throwsInvalidDisplayName() {
        // When / Then
        #expect(throws: UserProfileError.invalidDisplayName) {
            _ = try UserProfile(userID: Self.userID, displayName: "   \t\n  ")
        }
    }

    @Test("UD4. 51 字 displayName，throws .invalidDisplayName")
    func createUserProfile_tooLong_throwsInvalidDisplayName() {
        // Given
        let fiftyOne = String(repeating: "a", count: 51)

        // When / Then
        #expect(throws: UserProfileError.invalidDisplayName) {
            _ = try UserProfile(userID: Self.userID, displayName: fiftyOne)
        }
    }
}
