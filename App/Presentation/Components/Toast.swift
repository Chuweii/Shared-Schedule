import SwiftUI

/// Transient bottom toast, driven by a Bool binding: set it to `true`
/// and the modifier animates the capsule in, waits `duration`, then
/// resets the binding and animates out. Re-setting `true` while the
/// toast is already visible does NOT restart the timer — acceptable at
/// these durations, and it keeps the API a plain binding.
///
/// The message is a catalog key resolved through `Bundle.forLocale` so
/// both the visible text and the VoiceOver announcement follow the
/// in-app language override.
///
///     .toast(isPresented: $showCopied, message: "inviteToastCopied")
///
extension View {
    func toast(
        isPresented: Binding<Bool>,
        message: String.LocalizationValue,
        systemImage: String = "checkmark.circle.fill",
        duration: Duration = .seconds(2)
    ) -> some View {
        modifier(ToastModifier(
            isPresented: isPresented,
            message: message,
            systemImage: systemImage,
            duration: duration
        ))
    }
}

private struct ToastModifier: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale
    @Binding var isPresented: Bool
    let message: String.LocalizationValue
    let systemImage: String
    let duration: Duration

    private var resolvedMessage: String {
        String(localized: message, bundle: .forLocale(locale))
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    Label(resolvedMessage, systemImage: systemImage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.buttonTextPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(theme.buttonBgPrimary, in: Capsule())
                        .padding(.bottom, 32)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .task {
                            try? await Task.sleep(for: duration)
                            guard !Task.isCancelled else { return }
                            isPresented = false
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isPresented)
            // The toast outlives VoiceOver focus opportunities — narrate
            // it explicitly on presentation.
            .onChange(of: isPresented) { _, shown in
                guard shown else { return }
                AccessibilityNotification.Announcement(resolvedMessage).post()
            }
    }
}

#Preview {
    @Previewable @State var isPresented = true

    VStack {
        Button("Show toast") { isPresented = true }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast(isPresented: $isPresented, message: "inviteToastCopied")
}
