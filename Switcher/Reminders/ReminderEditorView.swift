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
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var draft: ReminderRuleDraft
    /// Текст поля числа; порожнє поле — число 0, і «Зберегти» неактивна.
    @State private var amountText: String
    @State private var isAmountFocused = false
    /// Ширина поля числа росте з розміром шрифту, щоб три цифри не обрізалися.
    @ScaledMetric(relativeTo: .title3) private var amountFieldWidth: CGFloat = 76
    @ScaledMetric(relativeTo: .title3) private var amountFieldHeight: CGFloat = 52

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
                SheetHeader(
                    confirmTitle: "Зберегти",
                    isConfirmEnabled: draft.canSave,
                    cancelIdentifier: "reminderEditorCancelButton",
                    confirmIdentifier: "reminderEditorSaveButton",
                    onCancel: { dismiss() },
                    onConfirm: save
                )
                // Жирне «нагадування» на найбільших розмірах шрифту ширше за екран — заголовок
                // росте лише до розміру, на якому слово ще влазить.
                Text(existingRule == nil ? "Нове нагадування" : "Нагадування")
                    .font(.title.bold())
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
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
                    // На великих розмірах шрифту поле числа — окремим рядком над одиницями.
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                        : AnyLayout(HStackLayout(spacing: 10))
                    layout {
                        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                        ReminderAmountField(text: $amountText, isFocused: $isAmountFocused)
                            .frame(width: amountFieldWidth, height: amountFieldHeight)
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

    /// На великих розмірах шрифту тумблер — під текстом, щоб «Повторювати» не рвалося.
    private var repeatRow: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    repeatText
                    repeatToggle
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    repeatText
                    Spacer()
                    repeatToggle
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var repeatText: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Одне довге слово: на найбільших розмірах шрифту трохи зменшується, а не рветься.
            Text("Повторювати")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Ще 2 рази, кожні 10 хв")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
    }

    /// Доріжка ввімкненого тумблера — колір тексту теми: контрастна до картки і в світлій, і в темній темі.
    private var repeatToggle: some View {
        Toggle("Повторювати", isOn: $draft.repeats)
            .labelsHidden()
            .toggleStyle(LampToggleStyle(onTrack: Theme.ink, knob: Theme.surface))
            .accessibilityIdentifier("reminderRepeatToggle")
    }

    /// Як виглядатиме перше сповіщення.
    private var preview: some View {
        HStack(alignment: .top, spacing: 12) {
            // На великих розмірах шрифту значок уже є в заголовку, а місця для тексту мало.
            if !typeSize.isAccessibilitySize {
                IconBubble(icon: item.icon, isOn: false, size: 40)
                    .accessibilityHidden(true)
            }
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
/// На великих розмірах шрифту — вертикальним списком на всю ширину, щоб слова не рвалися.
private struct OptionRow<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: KeyPath<Value, String>
    var accessibilityTitle: KeyPath<Value, String>?
    let identifier: (Value) -> String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let isLarge = typeSize.isAccessibilitySize
        let layout = isLarge ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(option[keyPath: title])
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(isLarge ? nil : 2)
                        .minimumScaleFactor(isLarge ? 1 : 0.8)
                        .foregroundStyle(isSelected ? Theme.background : Theme.ink)
                        .padding(.horizontal, isLarge ? 16 : 6)
                        .padding(.vertical, isLarge ? 8 : 0)
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
