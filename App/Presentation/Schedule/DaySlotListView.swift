import SwiftUI

struct DaySlotListView: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale
    let date: Date
    let presentedSlots: [PresentedSlot]
    /// When false, rows render but tap callbacks (book / cancel) are
    /// suppressed. Owners on their own schedule pass `false` so they
    /// can see the calendar without booking affordances.
    let interactive: Bool
    let onTapAvailable: (ComputedSlot) -> Void
    let onTapCancel: (BookingID) -> Void

    /// 24-hour HH:mm — locale-independent so zh-Hant doesn't fall back
    /// to 上午 / 下午 prefixes that wrap awkwardly inside the row.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        if presentedSlots.isEmpty {
            emptyState
        } else {
            slotList
        }
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "calendar.badge.minus")
                .foregroundStyle(theme.textCaption)
                .accessibilityHidden(true)
            Text("當天沒有可預約時段")
                .font(.subheadline)
                .foregroundStyle(theme.textCaption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var slotList: some View {
        VStack(spacing: 8) {
            ForEach(presentedSlots) { presented in
                slotRow(presented)
            }
        }
    }

    @ViewBuilder
    private func slotRow(_ presented: PresentedSlot) -> some View {
        switch presented.state {
        case .available:
            availableRow(presented.slot)
        case .mineBooked(let bookingID):
            bookedRow(presented.slot, bookingID: bookingID)
        case .bookedByStudent(let displayName, let email):
            bookedByStudentRow(presented.slot, displayName: displayName, email: email)
        case .bookedByOther:
            bookedByOtherRow(presented.slot)
        }
    }

    private func availableRow(_ slot: ComputedSlot) -> some View {
        Button {
            guard interactive else { return }
            onTapAvailable(slot)
        } label: {
            HStack {
                timeRange(slot)
                Spacer()
                durationCapsule(slot)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.bgSecondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!interactive)
        // Replaces the child readout so "—" never narrates as "dash".
        .accessibilityLabel(Text(verbatim: slotTimeString(slot)))
        .accessibilityValue(Text("\(Int(slot.end.timeIntervalSince(slot.start) / 60)) 分鐘"))
    }

    private func bookedRow(_ slot: ComputedSlot, bookingID: BookingID) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.textPrimary)
                timeRange(slot)
                Text("已預約")
                    .font(.caption)
                    .foregroundStyle(theme.textCaption)
            }
            // Cancel stays a sibling element so combining the info part
            // can't swallow the action.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim:
                "\(slotTimeString(slot))，\(String(localized: "已預約", bundle: .forLocale(locale)))"
            ))
            Spacer()
            if interactive {
                Button {
                    onTapCancel(bookingID)
                } label: {
                    Text("取消預約")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func bookedByStudentRow(_ slot: ComputedSlot, displayName: String?, email: String) -> some View {
        // Phase 4 Slice A: prefer displayName from user_profiles; fall
        // back to email when the student has no profile row yet.
        let label = displayName ?? email
        return HStack(alignment: .firstTextBaseline) {
            timeRange(slot)
            Spacer()
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.textCaption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(slotTimeString(slot))，\(label)"))
    }

    private func bookedByOtherRow(_ slot: ComputedSlot) -> some View {
        HStack(alignment: .firstTextBaseline) {
            timeRange(slot)
            Spacer()
            Text("已被預約")
                .font(.caption)
                .foregroundStyle(theme.textCaption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // Muted look comes from the dimmed background only — a whole-row
        // opacity stacked on textCaption fell below WCAG AA everywhere.
        .background(theme.bgSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim:
            "\(slotTimeString(slot))，\(String(localized: "已被預約", bundle: .forLocale(locale)))"
        ))
    }

    /// "09:00 到 10:00" — the visual "—" separator narrates as "dash",
    /// so accessibility labels swap it for a spoken connective.
    private func slotTimeString(_ slot: ComputedSlot) -> String {
        String(
            localized: "a11ySlotTimeRange \(Self.timeFormatter.string(from: slot.start)) \(Self.timeFormatter.string(from: slot.end))",
            bundle: .forLocale(locale)
        )
    }

    private func timeRange(_ slot: ComputedSlot) -> some View {
        HStack(spacing: 4) {
            Text(Self.timeFormatter.string(from: slot.start))
            Text("—")
            Text(Self.timeFormatter.string(from: slot.end))
        }
        .font(.body.weight(.medium))
        .foregroundStyle(theme.textPrimary)
    }

    private func durationCapsule(_ slot: ComputedSlot) -> some View {
        Text("\(Int(slot.end.timeIntervalSince(slot.start) / 60)) 分鐘")
            .font(.caption)
            .foregroundStyle(theme.textCaption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.bgSecondary)
            .clipShape(Capsule())
    }
}
