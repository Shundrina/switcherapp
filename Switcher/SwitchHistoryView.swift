import SwiftData
import SwiftUI

struct SwitchHistoryView: View {
    let item: SwitchItem

    var body: some View {
        List(item.sortedEvents) { event in
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.isOn ? "Увімкнено" : "Вимкнено")
                    Text(event.timestamp.formatted(date: .long, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: event.isOn ? "power.circle.fill" : "power.circle")
                    .foregroundStyle(event.isOn ? .green : .secondary)
            }
        }
        .overlay {
            if item.sortedEvents.isEmpty {
                ContentUnavailableView(
                    "Історія порожня",
                    systemImage: "clock",
                    description: Text("Тут з'являться дата й час кожного перемикання.")
                )
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
