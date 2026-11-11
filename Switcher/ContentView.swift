import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SwitchItem.createdAt) private var items: [SwitchItem]
    @State private var isAddingSwitch = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        SwitchRow(item: item)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Немає перемикачів",
                        systemImage: "switch.2",
                        description: Text("Натисніть «+», щоб додати перший перемикач.")
                    )
                }
            }
            .navigationTitle("Switcher")
            .navigationDestination(for: SwitchItem.self) { item in
                SwitchHistoryView(item: item)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Додати", systemImage: "plus") {
                        isAddingSwitch = true
                    }
                }
            }
            .sheet(isPresented: $isAddingSwitch) {
                AddSwitchView()
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

private struct SwitchRow: View {
    let item: SwitchItem

    var body: some View {
        Toggle(isOn: Binding(
            get: { item.isOn },
            set: { item.setOn($0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        guard let date = item.lastToggledAt else { return "Ще не перемикали" }
        let formatted = date.formatted(date: .abbreviated, time: .shortened)
        return item.isOn ? "Увімкнено \(formatted)" : "Вимкнено \(formatted)"
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SwitchItem.self, inMemory: true)
}
