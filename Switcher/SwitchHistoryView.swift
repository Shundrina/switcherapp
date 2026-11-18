import SwiftData
import SwiftUI

struct SwitchHistoryView: View {
    @Bindable var item: SwitchItem
    @Environment(\.now) private var now
    @Environment(ReminderService.self) private var reminders: ReminderService?
    /// Назва в картці показана як поле редагування.
    @State private var isEditingName = false
    /// Текст поля назви; зберігається в `item` лише після завершення редагування.
    @State private var draft = ""
    @State private var isNameFocused = false
    /// Примітка в картці показана як поле редагування; одночасно з назвою не редагується.
    @State private var isEditingNote = false
    /// Текст поля примітки; зберігається в `item` лише після завершення редагування.
    @State private var noteDraft = ""
    @State private var isNoteFocused = false

    private var isEditing: Bool {
        isEditingName || isEditingNote
    }

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
                // Після значка, а не одразу під карткою: колір і значок лишаються там, де були,
                // і перший ряд значків видно над клавіатурою, поки редагується примітка.
                section("Нагадування") {
                    ReminderSection(item: item)
                }
                VStack(alignment: .leading, spacing: 20) {
                    Text("Історія")
                        .font(.title3.bold())
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 4)
                    history
                }
                .modifier(EndsEditingOnTap(isEnabled: isEditing, action: finishEditing))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .background {
                Color.clear.modifier(EndsEditingOnTap(isEnabled: isEditing, action: finishEditing))
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        // Редагування назви чи примітки завершується, щойно поле втрачає фокус (зокрема «Готово»
        // над клавіатурою в примітці), змінюється перемикач або екран зникає.
        .onChange(of: isNameFocused) { _, isFocused in
            if !isFocused { finishNameEditing() }
        }
        .onChange(of: isNoteFocused) { _, isFocused in
            if !isFocused { finishNoteEditing() }
        }
        .onChange(of: item.isOn) { finishEditing() }
        .onChange(of: item.tone) { finishEditing() }
        .onChange(of: item.icon) {
            finishEditing()
            // Значок і назва — у заголовку запланованих сповіщень.
            Task { await reminders?.reschedule() }
        }
        .onChange(of: item.name) {
            Task { await reminders?.reschedule() }
        }
        .onDisappear(perform: finishEditing)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                IconBubble(icon: item.icon, isOn: item.isOn, size: 56)
                Spacer()
                Toggle(item.name, isOn: Binding(
                    get: { item.isOn },
                    set: { isOn in
                        item.setOn(isOn)
                        Task { await reminders?.didToggle(item) }
                    }
                ))
                .labelsHidden()
                .toggleStyle(LampToggleStyle(large: true))
                .accessibilityIdentifier("switchScreenToggle")
            }
            .modifier(EndsEditingOnTap(isEnabled: isEditing, action: finishEditing))
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
                    .modifier(EndsEditingOnTap(isEnabled: isEditing, action: finishEditing))
                if isEditingNote {
                    noteField
                        .padding(.top, 4)
                } else {
                    noteButton
                }
            }
            .animation(.easeInOut(duration: 0.3), value: item.isOn)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            Color.clear.modifier(EndsEditingOnTap(isEnabled: isEditing, action: finishEditing))
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
        .accessibilityIdentifier("switchNameButton")
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Багаторядкове поле, щоб довга назва переносилася так само, як у режимі перегляду.
            // Те саме обмеження, що й у формі додавання. «Готово» вставляє перенос рядка — тоді
            // текст не змінюється й редагування завершується; переноси з вставки стають пробілами.
            SwitchTextView(
                kind: .name,
                text: $draft,
                isFocused: $isNameFocused,
                placeholder: "Назва перемикача",
                textStyle: .title1,
                fontWeight: .bold,
                textColor: item.isOn ? Theme.onTone : Theme.ink,
                placeholderColor: item.isOn ? Theme.onTone.opacity(0.6) : Theme.muted,
                accessibilityIdentifier: "switchNameEditField",
                onFinish: finishNameEditing
            )
            .onAppear { isNameFocused = true }
            // Стара назва понад межу: лічильник виділено — «Готово» збереже лише перші 30 символів.
            Text(SwitchName.counterText(for: draft))
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(counterColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel(SwitchName.counterAccessibilityLabel(for: draft))
                .accessibilityIdentifier("switchNameEditCounter")
                .modifier(EndsEditingOnTap(isEnabled: isEditing, action: finishEditing))
        }
    }

    /// Примітка повністю, з переносами, або блідий «Додати примітку»: натискання відкриває поле
    /// редагування на тому самому місці. Зона натискання — увесь рядок картки, не нижча за 44 pt.
    private var noteButton: some View {
        let label = item.note.isEmpty ? "Додати примітку" : item.note
        return Button(action: startNoteEditing) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(noteColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(item.note.isEmpty ? "" : "Змінити примітку")
        .accessibilityIdentifier("switchNoteButton")
    }

    private var noteColor: Color {
        if item.note.isEmpty {
            return item.isOn ? Theme.onTone.opacity(0.6) : Theme.muted
        }
        return item.isOn ? Theme.onTone : Theme.ink
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Return вставляє перенос рядка; редагування завершує «Готово» над клавіатурою.
            SwitchTextView(
                kind: .note,
                text: $noteDraft,
                isFocused: $isNoteFocused,
                placeholder: "Наприклад, «Поливати по суботах»",
                textStyle: .footnote,
                fontWeight: .regular,
                textColor: item.isOn ? Theme.onTone : Theme.ink,
                placeholderColor: item.isOn ? Theme.onTone.opacity(0.6) : Theme.muted,
                accessibilityIdentifier: "switchNoteEditField"
            )
            .onAppear { isNoteFocused = true }
            Text(SwitchNote.counterText(for: noteDraft))
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(item.isOn ? Theme.onTone.opacity(0.8) : Theme.muted)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel(SwitchNote.counterAccessibilityLabel(for: noteDraft))
                .accessibilityIdentifier("switchNoteEditCounter")
                .modifier(EndsEditingOnTap(isEnabled: isEditing, action: finishEditing))
        }
    }

    private var counterColor: Color {
        if SwitchName.isOverLimit(draft) {
            return item.isOn ? Theme.warningOnTone : Theme.warning
        }
        return item.isOn ? Theme.onTone.opacity(0.8) : Theme.muted
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .capsStyle()
                .padding(.horizontal, 4)
                .modifier(EndsEditingOnTap(isEnabled: isEditing, action: finishEditing))
            content()
        }
    }

    /// Одночасно редагується щось одне: відкрита примітка спершу зберігається.
    private func startNameEditing() {
        finishNoteEditing()
        draft = item.name
        isEditingName = true
    }

    /// Одночасно редагується щось одне: відкрита назва спершу зберігається.
    private func startNoteEditing() {
        finishNameEditing()
        noteDraft = item.note
        isEditingNote = true
    }

    private func finishEditing() {
        finishNameEditing()
        finishNoteEditing()
    }

    /// Зберігає назву й повертає режим перегляду. Кілька шляхів завершення можуть спрацювати
    /// одночасно (наприклад, «Готово» і втрата фокуса), тож зберігає лише перший виклик.
    private func finishNameEditing() {
        guard isEditingName else { return }
        isEditingName = false
        isNameFocused = false
        item.rename(to: draft)
    }

    /// Зберігає примітку й повертає режим перегляду; як і в назви, зберігає лише перший виклик.
    private func finishNoteEditing() {
        guard isEditingNote else { return }
        isEditingNote = false
        isNoteFocused = false
        item.updateNote(to: noteDraft)
    }

    @ViewBuilder
    private var history: some View {
        let days = item.historyDays()
        if days.isEmpty {
            Text("Тут з'являться дата й час кожного перемикання.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 4)
                .accessibilityIdentifier("historyEmptyText")
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
                            EventRow(event: event, time: SwitchFormatting.time(event.timestamp), tone: item.tone)
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
    }
}

/// Дотик по вмісту завершує редагування назви чи примітки. Кнопки всередині спрацьовують як звичайно;
/// поки ні назву, ні примітку не редагують, жест вимкнено.
private struct EndsEditingOnTap: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(TapGesture().onEnded { action() }, including: isEnabled ? .all : .subviews)
    }
}

/// Час рахує батьківський view, який залежить від `\.now`: сам запис (клас `@Model`) після зміни
/// поясу не змінюється, і SwiftUI не перемалював би рядок зі старим часом.
private struct EventRow: View {
    let event: SwitchEvent
    /// Час перемикання «08:15» у поточному поясі.
    let time: String
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
            Text(time)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        // Для VoiceOver запис — один елемент: «Увімкнено, 14:05».
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("historyEvent")
    }
}
