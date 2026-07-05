import Testing
import Foundation
@testable import Shared_Schedule

struct UpdateDisplayNameUseCaseTests {

    private static let userID = UserID("a1b2c3d4-e5f6-7890-abcd-ef1234567890")

    private func makeSUT() -> (
        useCase: UpdateDisplayNameUseCase,
        profileFake: FakeUserProfileRepository
    ) {
        let profileFake = FakeUserProfileRepository()
        let useCase = UpdateDisplayNameUseCase(userProfileRepository: profileFake)
        return (useCase, profileFake)
    }

    @Test("UPD1. 有效新名 → repo.update 成功 → 回更新後 UserProfile；repo.update called 1 次帶 trimmed name")
    func updateDisplayName_validName_callsRepoAndReturns() async throws {
        // Given
        let (useCase, profileFake) = makeSUT()
        profileFake.updateResult = try UserProfile(userID: Self.userID, displayName: "小華")

        // When
        let result = try await useCase.updateDisplayName("小華")

        // Then
        #expect(result.displayName == "小華")
        #expect(profileFake.updateCount == 1)
        #expect(profileFake.lastUpdateDisplayName == "小華")
    }

    @Test("UPD2. displayName 全 whitespace（pre-flight）→ throws .invalidDisplayName；repo 未呼叫")
    func updateDisplayName_whitespace_failsPreflight() async {
        // Given
        let (useCase, profileFake) = makeSUT()

        // When / Then
        await #expect(throws: UpdateDisplayNameError.invalidDisplayName) {
            _ = try await useCase.updateDisplayName("   ")
        }
        #expect(profileFake.updateCount == 0)
    }

    @Test("UPD3. displayName 51 字（pre-flight）→ throws .invalidDisplayName；repo 未呼叫")
    func updateDisplayName_tooLong_failsPreflight() async {
        // Given
        let (useCase, profileFake) = makeSUT()
        let fiftyOne = String(repeating: "a", count: 51)

        // When / Then
        await #expect(throws: UpdateDisplayNameError.invalidDisplayName) {
            _ = try await useCase.updateDisplayName(fiftyOne)
        }
        #expect(profileFake.updateCount == 0)
    }

    @Test("UPD4. repo.update 拋 .persistenceFailure → 透傳 .persistenceFailure")
    func updateDisplayName_repoFails_passesThrough() async {
        // Given
        let (useCase, profileFake) = makeSUT()
        profileFake.updateError = .persistenceFailure

        // When / Then
        await #expect(throws: UpdateDisplayNameError.persistenceFailure) {
            _ = try await useCase.updateDisplayName("小華")
        }
    }
}
