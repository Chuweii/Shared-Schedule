import Foundation

@Observable
final class InviteSheetViewModel {
    private(set) var invitations: [Invitation] = []
    private(set) var loadError: LocalizedStringResource?
    private(set) var inlineError: LocalizedStringResource?
    private(set) var isGenerating = false

    let schedule: Schedule
    private let createInvitationUseCase: any CreateInvitationUseCaseProtocol
    private let listInvitationsUseCase: any ListInvitationsUseCaseProtocol

    init(
        schedule: Schedule,
        createInvitationUseCase: any CreateInvitationUseCaseProtocol,
        listInvitationsUseCase: any ListInvitationsUseCaseProtocol
    ) {
        self.schedule = schedule
        self.createInvitationUseCase = createInvitationUseCase
        self.listInvitationsUseCase = listInvitationsUseCase
    }

    func onAppear() async {
        loadError = nil
        do {
            invitations = try await listInvitationsUseCase.listInvitations(for: schedule.id)
        } catch {
            invitations = []
            loadError = "inviteSheetLoadError"
        }
    }

    func didTapGenerate() async {
        guard !isGenerating else { return }
        isGenerating = true
        inlineError = nil
        do {
            let new = try await createInvitationUseCase.createInvitation(scheduleID: schedule.id)
            invitations.insert(new, at: 0)
        } catch {
            inlineError = "inviteSheetGenerateFailed"
        }
        isGenerating = false
    }
}
