import SwiftUI

struct DaySlotListView: View {
    @Environment(\.theme) private var theme
    let date: Date
    let slots: [ComputedSlot]

    var body: some View {
        if slots.isEmpty {
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
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                slotRow(slot)
            }
        }
    }

    private func slotRow(_ slot: ComputedSlot) -> some View {
        HStack {
            HStack(spacing: 4) {
                Text(slot.start, style: .time)
                Text("—")
                Text(slot.end, style: .time)
            }
            .font(.body.weight(.medium))
            .foregroundStyle(theme.textPrimary)

            Spacer()

            Text("\(Int(slot.end.timeIntervalSince(slot.start) / 60)) 分鐘")
                .font(.caption)
                .foregroundStyle(theme.textCaption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.bgSecondary)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.bgSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
