import Testing
@testable import Shared_Schedule

struct InvitationTokenTests {

    @Test("用合法 8 字元 Crockford 字串建 token，成功")
    func createToken_validCrockford8Chars_succeeds() throws {
        // Given
        let raw = "ABCD1234"

        // When
        let token = try InvitationToken(raw)

        // Then
        #expect(token.rawValue == raw)
    }

    @Test("用 7 字元字串建 token，throws .invalidLength")
    func createToken_sevenChars_throwsInvalidLength() {
        // Given
        let raw = "ABCD123"

        // When / Then
        #expect(throws: InvitationTokenError.invalidLength) {
            _ = try InvitationToken(raw)
        }
    }

    @Test("用含 I 的 8 字元字串建 token，throws .invalidCharacter")
    func createToken_containsExcludedI_throwsInvalidCharacter() {
        // Given — 'I' is excluded from the Crockford-without-confusables alphabet
        let raw = "AICD1234"

        // When / Then
        #expect(throws: InvitationTokenError.invalidCharacter) {
            _ = try InvitationToken(raw)
        }
    }
}
