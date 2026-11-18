import SwiftData
import SwiftUI

/// Що відкрито у вікні правила: нове правило чи наявне.
enum ReminderEditorTarget: Identifiable {
    case new
    case existing(ReminderRule)

    var id: String {
        switch self {
        case .new: "new"
        case .existing(let rule): rule.uuid.uuidString
        }
    }
}

/// Вікно правила (аркуш знизу): «Коли», «Через», «Повторювати», приклад сповіщення;
/// для наявного правила — «Видалити нагадування».
struct ReminderEditorView: View {
    let item: SwitchItem
    let target: ReminderEditorTarget
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ReminderService.self) private var reminders: ReminderService?
    @State private var draft: ReminderRuleDraft
    /// Текст поля числа; порожнє поле — число 0, і «Зберегти» неактивна.
    @State private var amountText: String
    @State private var isAmountFocused = false
    /// Ширина поля числа росте з розміром шрифту, щоб три цифри не обрізалися.
    @ScaledMetric(relativeTo: .title3) private var amountFieldWidth: CGFloat = 76

    init(item: SwitchItem, target: ReminderEditorTarget) {
        self.item = item
        self.target = target
        let draft = switch target {
        case .new: ReminderRuleDraft()
        case .existing(let rule): ReminderRuleDraft(rule: rule)
        }
        _draft = State(initialValue: draft)
        _amountText = State(initialValue: String(draft.amount))
    }

    private var existingRule: ReminderRule? {
        if case .existing(let rule) = target { rule } else { nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button("Скасувати") { dismiss() }
                        .font(.body.weight(.medium))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("reminderEditorCancelButton")
                    Spacer()
                    Button(action: save) {
                        Text("Зберегти")
                            .font(.headline)
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background(Theme.ink, in: Capsule())
                    }
                    .opacity(draft.canSave ? 1 : 0.4)
                    .disabled(!draft.canSave)
                    .accessibilityIdentifier("reminderEditorSaveButton")
                }
                Text(existingRule == nil ? "Нове нагадування" : "Нагадування")
                    .font(.title.bold())
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 4)
                field("Коли") {
                    OptionRow(
                        options: [ReminderCondition.on, .off, .always],
                        selection: $draft.condition,
                        title: \.title,
                        identifier: { "reminderConditionOption_\($0.rawValue)" }
                    )
                }
                field("Через") {
                    HStack(spacing: 10) {
                        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                        ReminderAmountField(text: $amountText, isFocused: $isAmountFocused)
                            .frame(width: amountFieldWidth, height: 52)
                            .background(Theme.surface, in: shape)
                            .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2).opacity(isAmountFocused ? 1 : 0))
                        OptionRow(
                            options: [ReminderUnit.minutes, .hours, .days],
                            selection: $draft.unit,
                            title: \.shortTitle,
                            accessibilityTitle: \.title,
                            identifier: { "reminderUnitOption_\($0.rawValue)" }
                        )
                    }
                }
                repeatRow
                field("Приклад сповіщення") {
                    preview
                }
                if existingRule != nil {
                    Button(role: .destructive, action: deleteRule) {
                        Text("Видалити нагадування")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("reminderDeleteButton")
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.background)
        .tint(Theme.ink)
        .presentationBackground(Theme.background)
        .presentationDragIndicator(.visible)
        .onChange(of: amountText) { _, text in
            draft.amount = Int(text) ?? 0
        }
    }

    private var repeatRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Повторювати")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text("Ще 2 рази, кожні 10 хв")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Toggle("Повторювати", isOn: $draft.repeats)
                .labelsHidden()
                .toggleStyle(LampToggleStyle())
                .accessibilityIdentifier("reminderRepeatToggle")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// Як виглядатиме перше сповіщення.
    private var preview: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBubble(icon: item.icon, isOn: false, size: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(ReminderFormatting.title(icon: item.icon, name: item.name))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("reminderPreviewTitle")
                Text(previewBody)
                    .font(.subheadline)
                    .foregroundStyle(draft.canSave ? Theme.ink : Theme.muted)
                    .accessibilityIdentifier("reminderPreviewBody")
                Text("Кнопка «Перемкнути» в сповіщенні перемикає, не відкриваючи застосунок.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var previewBody: String {
        guard draft.canSave else { return "Вкажіть число від 1 до 999" }
        return ReminderFormatting.previewBody(condition: draft.condition, amount: draft.amount, unit: draft.unit)
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
        guard draft.canSave else { return }
        if let rule = existingRule {
            draft.apply(to: rule, at: .now)
        } else {
            let rule = draft.makeRule(at: .now)
            modelContext.insert(rule)
            rule.item = item
        }
        try? modelContext.save()
        dismiss()
        Task {
            // Дозвіл питають при збереженні першого правила; план складається в будь-якому разі.
            await reminders?.requestPermissionIfNeeded()
            await reminders?.reschedule()
        }
    }

    /// Без підтвердження: правило легко додати знову.
    private func deleteRule() {
        guard let rule = existingRule else { return }
        modelContext.delete(rule)
        try? modelContext.save()
        dismiss()
        Task { await reminders?.reschedule() }
    }
}

/// Ряд кнопок-варіантів однакової ширини; вибраний — темний.
private struct OptionRow<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: KeyPath<Value, String>
    var accessibilityTitle: KeyPath<Value, String>?
    let identifier: (Value) -> String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(option[keyPath: title])
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? Theme.background : Theme.ink)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(isSelected ? Theme.ink : Theme.surface,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(Rectangle())
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option[keyPath: accessibilityTitle ?? title])
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier(identifier(option))
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private extension ReminderCondition {
    var title: String {
        switch self {
        case .on: "Коли увімкнено"
        case .off: "Коли вимкнено"
        case .always: "Завжди"
        }
    }
}

private extension ReminderUnit {
    /// Підпис кнопки: «хв», «год», «дні».
    var shortTitle: String {
        switch self {
        case .minutes: "хв"
        case .hours: "год"
        case .days: "дні"
        }
    }

    /// Для VoiceOver.
    var title: String {
        switch self {
        case .minutes: "хвилини"
        case .hours: "години"
        case .days: "дні"
        }
    }
}
