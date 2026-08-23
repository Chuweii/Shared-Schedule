import SwiftUI

struct RedeemInvitationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale
    @State var viewModel: RedeemInvitationViewModel
    @State private var sensoryToken = 0
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if viewModel.success == nil {
                            Button("取消") { dismiss() }
                        }
                    }
                }
                .sensoryFeedback(.success, trigger: sensoryToken)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let success = viewModel.success {
            successView(success)
                .navigationTitle(Text(""))
        } else {
            inputView
                .navigationTitle(Text("加入課表"))
        }
    }

    // MARK: - Input state

    private var inputView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 16)

            TextField(
                "",
                text: Binding(
                    get: { viewModel.input },
                    set: { viewModel.updateInput($0) }
                ),
                prompt: Text("邀請碼").foregroundStyle(theme.textCaption)
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .font(.title.weight(.semibold).monospaced())
            .multilineTextAlignment(.center)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(theme.textFieldBgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .focused($inputFocused)
            // Empty-title field: the prompt is the only visible name.
            .accessibilityLabel(Text("邀請碼"))

            Text("邀請碼共 8 個英數字元")
                .font(.footnote)
                .foregroundStyle(theme.textSecondary)

            if let error = viewModel.inlineError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(theme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            submitButton
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
        .onAppear { inputFocused = true }
    }

    private var submitButton: some View {
        Button {
            Task { await viewModel.didTapSubmit() }
        } label: {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(theme.buttonTextPrimary)
                        .accessibilityLabel(Text("a11yLoading"))
                } else {
                    Text("加入")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.buttonTextPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(viewModel.canSubmit ? theme.buttonBgPrimary : theme.buttonBgPrimary.opacity(0.4))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSubmit)
    }

    // MARK: - Success state

    private func successView(_ success: RedeemInvitationViewModel.SuccessState) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(theme.success)
                .accessibilityHidden(true)

            Text("已加入「\(success.schedule.title)」")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("完成")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.buttonTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.buttonBgPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .onAppear {
            sensoryToken &+= 1
            // Success replaces the whole sheet content — narrate it in
            // step with the haptic.
            AccessibilityNotification.Announcement(
                String(
                    localized: "已加入「\(success.schedule.title)」",
                    bundle: .forLocale(locale)
                )
            ).post()
        }
    }
}
