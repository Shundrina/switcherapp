import SwiftData
import SwiftUI

struct AddSwitchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Назва, наприклад «Полила квіти»", text: $name)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit(save)
            }
            .navigationTitle("Новий перемикач")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Додати", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear { isNameFocused = true }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        modelContext.insert(SwitchItem(name: trimmedName))
        dismiss()
    }
}

#Preview {
    AddSwitchView()
        .modelContainer(for: SwitchItem.self, inMemory: true)
}
