import SwiftData
import SwiftUI

struct AddSwitchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var name = ""
    @State private var icon = SwitchIcon.check
    @State private var tone = SwitchTone.amber
    @State private var previewIsOn = false
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button("Скасувати") { dismiss() }
                        .font(.body.weight(.medium))
                        .frame(minHeight: 44)
                    Spacer()
                    Button(action: save) {
                        Text("Додати")
                            .font(.headline)
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background(Theme.ink, in: Capsule())
                    }
                    .opacity(trimmedName.isEmpty ? 0.4 : 1)
                    .disabled(trimmedName.isEmpty)
                }
                Text("Новий перемикач")
                    .font(.title.bold())
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 4)
                field("Назва") {
                    let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                    TextField("Наприклад, «Вимкнула плиту»", text: $name)
                        .font(.body.weight(.medium))
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(Theme.surface, in: shape)
                        .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2).opacity(isNameFocused ? 1 : 0))
                }
                field("Колір") {
                    TonePicker(selection: $tone)
                }
                field("Значок") {
                    IconPicker(selection: $icon, tone: tone)
                }
                field("Вигляд у списку") {
                    preview
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .tint(Theme.ink)
        .presentationBackground(Theme.background)
        .presentationDragIndicator(.visible)
        .onAppear { isNameFocused = true }
        .task {
            // Картка-зразок сама вмикається й вимикається, щоб показати обидва стани.
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.6))
                previewIsOn.toggle()
            }
        }
    }

    private var preview: some View {
        HStack(spacing: 14) {
            SwitchCardLabel(
                name: trimmedName.isEmpty ? "Назва перемикача" : trimmedName,
                status: "Ще не перемикали",
                icon: icon,
                tone: tone,
                isOn: previewIsOn
            )
            LampSwitch(isOn: previewIsOn)
        }
        .padding(16)
        .switchCard(isOn: previewIsOn, tone: tone)
        .accessibilityHidden(true)
    }

    private func field(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .capsStyle()
                .padding(.horizontal, 4)
            content()
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        modelContext.insert(SwitchItem(name: trimmedName, icon: icon, tone: tone))
        dismiss()
    }
}

#Preview {
    AddSwitchView()
        .modelContainer(for: SwitchItem.self, inMemory: true)
}
