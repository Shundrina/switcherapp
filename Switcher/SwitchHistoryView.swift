import SwiftData
import SwiftUI

struct SwitchHistoryView: View {
    @Bindable var item: SwitchItem
    @Environment(\.now) private var now
    /// Назва в картці показана як поле редагування.
    @State private var isEditingName = false
    /// Текст поля назви; зберігається в `item` лише після завершення редагування.
    @State private var draft = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                section("Колір") {
                    TonePicker(selection: $item.tone)
                }
                section("Значок") {
                    IconPicker(selection: $item.icon, tone: item.tone)
                }
                VStack(alignment: .leading, spacing: 20) {
                    Text("Історія")
                        .font(.title3.bold())
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 4)
                    history
                }
                .modifier(EndsEditingOnTap(isEnabled: isEditingName, action: finishNameEditing))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .background {
                Color.clear.modifier(EndsEditingOnTap(isEnabled: isEditingName, action: finishNameEditing))
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        // Редагування назви завершується, щойно поле втрачає фокус, змінюється перемикач або екран зникає.
        .onChange(of: isNameFocused) { _, isFocused in
            if !isFocused { finishNameEditing() }
        }
        .onChange(of: item.isOn) { finishNameEditing() }
        .onChange(of: item.tone) { finishNameEditing() }
        .onChange(of: item.icon) { finishNameEditing() }
        .onDisappear(perform: finishNameEditing)
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
            .modifier(EndsEditingOnTap(isEnabled: isEditingName, action: finishNameEditing))
            VStack(alignment: .leading, spacing: 4) {
                if isEditingName {
                    nameField
                } else {
                    nameButton
                }
                Text(item.statusText(now: now))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(item.isOn ? Theme.onTone.opacity(0.8) : Theme.muted)
                    .modifier(EndsEditingOnTap(isEnabled: isEditingName, action: finishNameEditing))
            }
            .animation(.easeInOut(duration: 0.3), value: item.isOn)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            Color.clear.modifier(EndsEditingOnTap(isEnabled: isEditingName, action: finishNameEditing))
        }
        .switchCard(isOn: item.isOn, tone: item.tone, cornerRadius: 28, origin: UnitPoint(x: 0.86, y: 0.24))
    }

    /// Назва з олівцем: натискання відкриває поле редагування на тому самому місці.
    private var nameButton: some View {
        let pencil = Text(Image(systemName: "pencil"))
            .font(.title3.weight(.semibold))
            .foregroundStyle(item.isOn ? Theme.onTone.opacity(0.8) : Theme.muted)
        // Нерозривний пробіл не лишає олівець самого на новому рядку.
        return Button(action: startNameEditing) {
            Text("\(item.name)\u{00A0}\(pencil)")
                .font(.title.bold())
                .foregroundStyle(item.isOn ? Theme.onTone : Theme.ink)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.name)
        .accessibilityHint("Змінити назву")
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Багаторядкове поле, щоб довга назва переносилася так само, як у режимі перегляду.
            TextField(
                "Назва",
                text: $draft,
                prompt: Text("Назва перемикача").foregroundStyle(item.isOn ? Theme.onTone.opacity(0.6) : Theme.muted),
                axis: .vertical
            )
            .font(.title.bold())
            .foregroundStyle(item.isOn ? Theme.onTone : Theme.ink)
            .tint(item.isOn ? Theme.onTone : Theme.ink)
            .focused($isNameFocused)
            .submitLabel(.done)
            .onSubmit(finishNameEditing)
            .onChange(of: draft) { old, new in
                // Те саме обмеження, що й у формі додавання. У багаторядковому полі «Готово» вставляє
                // перенос рядка — тоді текст не змінюється й редагування завершується; переноси
                // з вставки чи диктування стають пробілами (див. `SwitchName.fieldEdit`).
                let edit = SwitchName.fieldEdit(from: old, to: new)
                if edit.text != new { draft = edit.text }
                // Після присвоєння: `finishNameEditing` зберігає `draft`.
                if edit.finishesEditing { finishNameEditing() }
            }
            .onAppear { isNameFocused = true }
            Text(SwitchName.counterText(for: draft))
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(item.isOn ? Theme.onTone.opacity(0.8) : Theme.muted)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel(SwitchName.counterAccessibilityLabel(for: draft))
                .modifier(EndsEditingOnTap(isEnabled: isEditingName, action: finishNameEditing))
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .capsStyle()
                .padding(.horizontal, 4)
                .modifier(EndsEditingOnTap(isEnabled: isEditingName, action: finishNameEditing))
            content()
        }
    }

    private func startNameEditing() {
        draft = item.name
        isEditingName = true
    }

    /// Зберігає назву й повертає режим перегляду. Кілька шляхів завершення можуть спрацювати
    /// одночасно (наприклад, «Готово» і втрата фокуса), тож зберігає лише перший виклик.
    private func finishNameEditing() {
        guard isEditingName else { return }
        isEditingName = false
        isNameFocused = false
        item.rename(to: draft)
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

/// Дотик по вмісту завершує редагування назви. Кнопки всередині спрацьовують як звичайно;
/// поки назву не редагують, жест вимкнено.
private struct EndsEditingOnTap: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(TapGesture().onEnded { action() }, including: isEnabled ? .all : .subviews)
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
