import SwiftUI
import UIKit

/// Поле числа у вікні правила: числова клавіатура, лише цифри, не більше трьох. Фокус сам не отримує;
/// клавіатуру ховає «Готово» на панелі над нею (на числовій клавіатурі немає Return).
struct ReminderAmountField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    static let maxDigits = 3

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        field.keyboardType = .numberPad
        field.textAlignment = .center
        field.font = UIFontMetrics(forTextStyle: .title3)
            .scaledFont(for: .monospacedDigitSystemFont(ofSize: 20, weight: .semibold))
        field.adjustsFontForContentSizeCategory = true
        field.textColor = .label
        field.tintColor = UIColor(Theme.ink)
        field.accessibilityIdentifier = "reminderAmountField"
        field.accessibilityLabel = "Кількість"
        field.inputAccessoryView = KeyboardDoneBar(for: field, accessibilityIdentifier: "reminderAmountDoneButton")
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text {
            field.text = text
        }
        if !isFocused, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ReminderAmountField

        init(parent: ReminderAmountField) {
            self.parent = parent
        }

        /// Пропускає лише цифри; вставку обрізає до перших трьох цифр.
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = (textField.text ?? "") as NSString
            let updated = current.replacingCharacters(in: range, with: string)
            let digits = String(updated.filter { $0.isASCII && $0.isNumber }.prefix(ReminderAmountField.maxDigits))
            if digits == updated { return true }
            textField.text = digits
            textDidChange(textField)
            return false
        }

        @objc func textDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFocused = false
        }
    }
}
