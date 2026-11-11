import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SwitchItem.createdAt) private var items: [SwitchItem]
    @State private var isAddingSwitch = false
    @State private var selectedItem: SwitchItem?

    private var onCount: Int {
        items.filter(\.isOn).count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Theme.background)
            .navigationTitle("Перемикачі")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedItem) { item in
                SwitchHistoryView(item: item)
            }
            .sheet(isPresented: $isAddingSwitch) {
                AddSwitchView()
            }
        }
        .tint(Theme.ink)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(SwitchFormatting.locale)))
                    .capsStyle()
                Text("Перемикачі")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.ink)
                if !items.isEmpty {
                    Text("Увімкнено \(onCount) з \(items.count)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .contentTransition(.numericText())
                        .animation(.default, value: onCount)
                }
            }
            Spacer()
            Button {
                isAddingSwitch = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.background)
                    .frame(width: 44, height: 44)
                    .background(Theme.ink, in: Circle())
            }
            .accessibilityLabel("Додати перемикач")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    private var list: some View {
        List {
            ForEach(items) { item in
                SwitchRow(item: item) {
                    selectedItem = item
                }
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 28) {
            Capsule()
                .fill(SwitchTone.amber.color)
                .frame(width: 120, height: 72)
                .overlay(alignment: .trailing) {
                    Circle()
                        .fill(Theme.onTone)
                        .frame(width: 60, height: 60)
                        .padding(6)
                }
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Поки що жодного перемикача")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)
                Text("Додайте перший — наприклад, «Полила квіти» чи «Двері зачинені». Застосунок запам'ятає, коли ви його перемкнули.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .multilineTextAlignment(.center)
            Button {
                isAddingSwitch = true
            } label: {
                Text("Додати перемикач")
                    .font(.headline)
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 28)
                    .frame(height: 52)
                    .background(Theme.ink, in: Capsule())
            }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

private struct SwitchRow: View {
    let item: SwitchItem
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                SwitchCardLabel(name: item.name, status: item.statusText(), icon: item.icon, tone: item.tone, isOn: item.isOn)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Відкрити історію")

            Toggle(item.name, isOn: Binding(
                get: { item.isOn },
                set: { item.setOn($0) }
            ))
            .labelsHidden()
            .toggleStyle(LampToggleStyle())
        }
        .padding(16)
        .switchCard(isOn: item.isOn, tone: item.tone)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SwitchItem.self, inMemory: true)
}
