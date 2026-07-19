import SwiftUI

/// Transient bottom toast, driven by a Bool binding: set it to `true`
/// and the modifier animates the capsule in, waits `duration`, then
/// resets the binding and animates out. Re-setting `true` while the
/// toast is already visible does NOT restart the timer — acceptable at
/// these durations, and it keeps the API a plain binding.
///
///     .toast(isPresented: $showCopied, message: "inviteToastCopied")
///
extension View {
    func toast(
        isPresented: Binding<Bool>,
        message: LocalizedStringKey,
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
    @Binding var isPresented: Bool
    let message: LocalizedStringKey
    let systemImage: String
    let duration: Duration

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    Label(message, systemImage: systemImage)
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
