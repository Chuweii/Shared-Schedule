import SwiftUI
import UIKit

struct InviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State var viewModel: InviteSheetViewModel
    @State private var sensoryToken = 0
    @State private var showCopiedToast = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text("邀請學生加入「\(viewModel.schedule.title)」"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
                .task { await viewModel.onAppear() }
                .sensoryFeedback(.success, trigger: sensoryToken)
                .toast(
                    isPresented: $showCopiedToast,
                    message: "inviteToastCopied",
                    duration: .seconds(1.5)
                )
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.loadError {
            errorState(error)
        } else if viewModel.invitations.isEmpty && !viewModel.isGenerating {
            emptyState
        } else {
            invitationList
        }
    }

    private var generateButton: some View {
        Button {
            Task { await viewModel.didTapGenerate() }
        } label: {
            HStack {
                Image(systemName: "plus")
                Text("產生新邀請碼")
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(theme.buttonTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(theme.buttonBgPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGenerating)
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView {
                Label("還沒有邀請碼", systemImage: "person.crop.circle.badge.plus")
            } description: {
                Text("產生一個邀請碼分享給學生，他們可以用這組碼加入這份課表")
            }
            generateButton
            if let error = viewModel.inlineError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(theme.error)
                    .padding(.horizontal)
            }
            Spacer()
        }
        .padding(.top)
    }

    private func errorState(_ message: LocalizedStringResource) -> some View {
        ContentUnavailableView {
            // Text (not String(localized:)) defers resolution to render
            // time so the message can follow the in-app language.
            Label { Text(message) } icon: { Image(systemName: "exclamationmark.triangle") }
        } actions: {
            Button {
                Task { await viewModel.onAppear() }
            } label: {
                Text("重試")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.buttonTextPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(theme.buttonBgPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var invitationList: some View {
        VStack(spacing: 0) {
            generateButton
                .padding(.top, 8)

            if let error = viewModel.inlineError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(theme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            List(viewModel.invitations, id: \.id) { invitation in
                row(invitation)
            }
            .listStyle(.plain)
        }
    }

    private func row(_ invitation: Invitation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.token.rawValue)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)

                Text("\(invitation.expiresAt, format: .dateTime.year().month().day()) 失效")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = invitation.token.rawValue
                sensoryToken &+= 1
                showCopiedToast = true
            } label: {
                Text("複製")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.buttonTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.buttonBgPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
