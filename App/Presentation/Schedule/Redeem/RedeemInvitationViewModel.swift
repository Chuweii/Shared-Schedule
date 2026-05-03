import Foundation

@MainActor
@Observable
final class RedeemInvitationViewModel {
    private(set) var input: String = ""
    private(set) var inlineError: LocalizedStringResource?
    private(set) var isSubmitting = false
    private(set) var success: SuccessState?

    struct SuccessState: Sendable {
        let schedule: Schedule
    }

    private let redeemInvitationUseCase: any RedeemInvitationUseCaseProtocol

    init(redeemInvitationUseCase: any RedeemInvitationUseCaseProtocol) {
        self.redeemInvitationUseCase = redeemInvitationUseCase
    }

    var canSubmit: Bool {
        input.count == InvitationToken.length && !isSubmitting && success == nil
    }

    /// Bound to the TextField. Normalizes input live: uppercases, drops
    /// non-Crockford characters, truncates to 8. Clears any prior inline
    /// error so the user can retry without seeing stale state.
    func updateInput(_ raw: String) {
        input = Self.normalize(raw)
        inlineError = nil
    }

    func didTapSubmit() async {
        guard canSubmit else { return }
        let token: InvitationToken
        do {
            token = try InvitationToken(input)
        } catch {
            // Shouldn't happen — `input` is already normalized to length 8
            // with valid Crockford chars. Defensive fallback.
            inlineError = "redeemPersistenceFailure"
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let schedule = try await redeemInvitationUseCase.redeemInvitation(token: token)
            success = SuccessState(schedule: schedule)
        } catch {
            inlineError = Self.localizationKey(for: error)
        }
    }

    /// Token-input normalizer — exposed for unit testing in isolation.
    static func normalize(_ raw: String) -> String {
        let filtered = raw
            .uppercased()
            .filter { InvitationToken.alphabetSet.contains($0) }
        return String(filtered.prefix(InvitationToken.length))
    }

    private static func localizationKey(for error: InvitationRedemptionError) -> LocalizedStringResource {
        switch error {
        case .invalidToken:        return "redeemInvalidToken"
        case .expired:             return "redeemExpired"
        case .selfRedemption:      return "redeemSelfRedemption"
        case .alreadyMember:       return "redeemAlreadyMember"
        case .persistenceFailure:  return "redeemPersistenceFailure"
        }
    }
}
