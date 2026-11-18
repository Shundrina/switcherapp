import SwiftData
import SwiftUI

struct AddSwitchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var name = ""
    @State private var icon = SwitchIcon.check
    @State private var tone = SwitchTone.amber
    @State private var previewIsOn = LaunchOptions.current.addPreview.startsOn
    @State private var isNameFocused = false
    @State private var note = ""
    @State private var isNoteFocused = false

    private var savedName: String {
        SwitchName.forSaving(name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button("Скасувати") { dismiss() }
                        .font(.body.weight(.medium))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("addSwitchCancelButton")
                    Spacer()
                    Button(action: save) {
                        Text("Додати")
                            .font(.headline)
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background(Theme.ink, in: Capsule())
                    }
                    .opacity(savedName.isEmpty ? 0.4 : 1)
                    .disabled(savedName.isEmpty)
                    .accessibilityIdentifier("addSwitchSaveButton")
                }
                Text("Новий перемикач")
                    .font(.title.bold())
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 4)
                field("Назва") {
                    let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                    // У повне поле нові символи не вводяться, а з вставки лишаються перші символи,
                    // які влазять, — це вирішує делегат поля ще до того, як текст з'явиться.
                    SwitchNameTextField(
                        text: $name,
                        isFocused: $isNameFocused,
                        placeholder: "Наприклад, «Вимкнула плиту»",
                        accessibilityIdentifier: "addSwitchNameField"
                    )
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(Theme.surface, in: shape)
                    .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2).opacity(isNameFocused ? 1 : 0))
                    Text(SwitchName.counterText(for: name))
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(SwitchName.isOverLimit(name) ? Theme.warning : Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 4)
                        .accessibilityLabel(SwitchName.counterAccessibilityLabel(for: name))
                        .accessibilityIdentifier("addSwitchNameCounter")
                }
                field("Примітка") {
                    let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                    // Необов'язкова, багаторядкова: Return вставляє перенос рядка, а «Готово» над
                    // клавіатурою лише ховає клавіатуру. Обмеження — як у назви, межа 200 символів.
                    // Поле займає всю рамку (відступи — всередині нього), тож дотик будь-де в ній дає фокус.
                    SwitchTextView(
                        kind: .note,
                        text: $note,
                        isFocused: $isNoteFocused,
                        placeholder: "Необов'язково",
                        textStyle: .body,
                        fontWeight: .regular,
                        textColor: Theme.ink,
                        placeholderColor: Color(uiColor: .placeholderText),
                        accessibilityIdentifier: "addSwitchNoteField",
                        insets: UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16),
                        minHeight: 56
                    )
                    .background(Theme.surface, in: shape)
                    .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2).opacity(isNoteFocused ? 1 : 0))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("addSwitchNoteFrame")
                    Text(SwitchNote.counterText(for: note))
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 4)
                        .accessibilityLabel(SwitchNote.counterAccessibilityLabel(for: note))
                        .accessibilityIdentifier("addSwitchNoteCounter")
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
        .task {
            // Картка-зразок сама вмикається й вимикається, щоб показати обидва стани
            // (крім Reduce Motion; у тестовому режимі запуску стоїть увімкненою — див. `LaunchOptions.AddPreview`).
            guard LaunchOptions.current.addPreview.togglesItself(reduceMotion: reduceMotion) else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.6))
                previewIsOn.toggle()
            }
        }
    }

    private var preview: some View {
        HStack(spacing: 14) {
            SwitchCardLabel(
                name: savedName.isEmpty ? "Назва перемикача" : savedName,
                status: "Ще не перемикали",
                icon: icon,
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
        guard !savedName.isEmpty else { return }
        let item = SwitchItem(name: savedName, icon: icon, tone: tone)
        item.updateNote(to: note)
        modelContext.insert(item)
        dismiss()
    }
}

#Preview {
    AddSwitchView()
        .modelContainer(for: SwitchItem.self, inMemory: true)
}
