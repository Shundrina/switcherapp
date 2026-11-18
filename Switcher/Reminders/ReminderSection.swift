import SwiftData
import SwiftUI

/// Розділ «Нагадування» на екрані перемикача: рядки правил (натискання відкриває вікно правила),
/// «Додати нагадування» і, якщо сповіщення заборонено, «Сповіщення вимкнено» з «Відкрити Параметри».
struct ReminderSection: View {
    let item: SwitchItem
    @Environment(ReminderService.self) private var reminders: ReminderService?
    @Environment(\.openURL) private var openURL
    @State private var editorTarget: ReminderEditorTarget?

    /// Правила в порядку створення; видалене, але ще не збережене правило не показується.
    private var rules: [ReminderRule] {
        (item.rules ?? []).filter { !$0.isDeleted }.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        let rules = rules
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                ForEach(rules) { rule in
                    ruleRow(rule)
                    Rectangle()
                        .fill(Theme.line)
                        .frame(height: 1)
                        .padding(.leading, 16)
                }
                addButton
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if !rules.isEmpty, reminders?.permission.showsDisabledNotice == true {
                disabledNotice
            }
        }
        .sheet(item: $editorTarget) { target in
            ReminderEditorView(item: item, target: target)
        }
    }

    private func ruleRow(_ rule: ReminderRule) -> some View {
        let summary = ReminderFormatting.ruleSummary(
            condition: rule.condition, amount: rule.amount, unit: rule.unit, repeats: rule.repeats
        )
        return Button {
            editorTarget = .existing(rule)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 24)
                Text(summary)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(summary)
        .accessibilityHint("Змінити нагадування")
        .accessibilityIdentifier("reminderRow")
    }

    private var addButton: some View {
        Button {
            editorTarget = .new
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(width: 24)
                Text("Додати нагадування")
                    .font(.body.weight(.medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Додати нагадування")
        .accessibilityIdentifier("addReminderButton")
    }

    private var disabledNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Сповіщення вимкнено")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.warning)
                .accessibilityIdentifier("notificationsDisabledNotice")
            Text("Нагадування не прийдуть, доки сповіщення для Switcher вимкнено в Параметрах.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            Button {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text("Відкрити Параметри")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(Theme.ink, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openNotificationSettingsButton")
        }
        .padding(.horizontal, 4)
    }
}
