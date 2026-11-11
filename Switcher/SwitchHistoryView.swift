import SwiftData
import SwiftUI

struct SwitchHistoryView: View {
    @Bindable var item: SwitchItem
    @Environment(\.now) private var now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                VStack(alignment: .leading, spacing: 8) {
                    Text("Колір")
                        .capsStyle()
                        .padding(.horizontal, 4)
                    TonePicker(selection: $item.tone)
                }
                Text("Історія")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 4)
                history
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                IconBubble(icon: item.icon, tone: item.tone, isOn: item.isOn, size: 56)
                Spacer()
                Toggle(item.name, isOn: Binding(
                    get: { item.isOn },
                    set: { item.setOn($0) }
                ))
                .labelsHidden()
                .toggleStyle(LampToggleStyle(large: true))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.title.bold())
                    .foregroundStyle(item.isOn ? Theme.onTone : Theme.ink)
                Text(item.statusText(now: now))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(item.isOn ? Theme.onTone.opacity(0.8) : Theme.muted)
            }
            .animation(.easeInOut(duration: 0.3), value: item.isOn)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .switchCard(isOn: item.isOn, tone: item.tone, cornerRadius: 28, origin: UnitPoint(x: 0.86, y: 0.24))
    }

    @ViewBuilder
    private var history: some View {
        let days = item.historyDays()
        if days.isEmpty {
            Text("Тут з'являться дата й час кожного перемикання.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 4)
        } else {
            ForEach(days) { day in
                VStack(alignment: .leading, spacing: 8) {
                    Text(SwitchFormatting.dayTitle(day.date, now: now))
                        .capsStyle()
                        .padding(.horizontal, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(day.events.enumerated()), id: \.element.id) { index, event in
                            if index > 0 {
                                Rectangle()
                                    .fill(Theme.line)
                                    .frame(height: 1)
                            }
                            EventRow(event: event, tone: item.tone)
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
    }
}

private struct EventRow: View {
    let event: SwitchEvent
    let tone: SwitchTone

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(event.isOn ? tone.color : Theme.surface)
                .overlay(Circle().strokeBorder(event.isOn ? Theme.ink : Theme.track, lineWidth: 2))
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
            Text(event.isOn ? "Увімкнено" : "Вимкнено")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(SwitchFormatting.time(event.timestamp))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }
}
