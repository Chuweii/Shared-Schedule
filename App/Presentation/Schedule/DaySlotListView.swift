import SwiftUI

struct DaySlotListView: View {
    @Environment(\.theme) private var theme
    let date: Date
    let presentedSlots: [PresentedSlot]
    /// When false, rows render but tap callbacks (book / cancel) are
    /// suppressed. Owners on their own schedule pass `false` so they
    /// can see the calendar without booking affordances.
    let interactive: Bool
    let onTapAvailable: (ComputedSlot) -> Void
    let onTapCancel: (BookingID) -> Void

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

    private func timeRange(_ slot: ComputedSlot) -> some View {
        HStack(spacing: 4) {
            Text(slot.start, style: .time)
            Text("—")
            Text(slot.end, style: .time)
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
