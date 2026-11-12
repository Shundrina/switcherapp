import SwiftUI
import UIKit

// Поля «Назва» на UIKit: делегат відкидає зайве ДО того, як воно потрапить у поле
// (`SwitchName.edit`), тож межа в 30 символів не змагається з рендером, як у SwiftUI `TextField`.
//
// Фокус — власна прив'язка `isFocused` замість `@FocusState` (з UIKit-полем він не працює):
// SwiftUI → поле через `wantsFocus`, поле → SwiftUI через делегат на початку й наприкінці редагування.
//
// Складання тексту (IME, диктування): поки в полі є позначений текст (`markedTextRange`), правки
// приймаються як є, а прив'язка не оновлюється; щойно складання завершилося, межу застосовує
// `SwitchName.edit(from:to:)` до різниці між останнім прийнятим текстом і тим, що в полі.

/// Однорядкове поле «Назва» на екрані додавання. «Готово» на клавіатурі викликає `onSubmit`
/// і ховає клавіатуру; переноси рядка з вставки стають пробілами.
struct SwitchNameTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let accessibilityIdentifier: String
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> NameTextField {
        let field = NameTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        field.placeholder = placeholder
        field.font = .scaledSystemFont(.body, weight: .medium)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = .label
        field.tintColor = UIColor(Theme.ink)
        field.returnKeyType = .done
        field.accessibilityIdentifier = accessibilityIdentifier
        field.accessibilityLabel = "Назва"
        // Ширину задає SwiftUI: довга назва не розширює поле.
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: NameTextField, context: Context) {
        context.coordinator.parent = self
        // Лише якщо текст інший (інакше стрибає курсор) і не посеред складання.
        if field.markedTextRange == nil, field.text != text {
            field.text = text
        }
        field.wantsFocus = isFocused
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SwitchNameTextField

        init(parent: SwitchNameTextField) {
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard textField.markedTextRange == nil else { return true }
            switch SwitchName.edit(textField.text ?? "", range: range, replacement: string, allowsNewlineFinish: false) {
            case .accept:
                return true
            case .replace(let text, let cursor):
                apply(text, cursor: cursor, to: textField)
                return false
            case .reject, .finish:
                return false
            }
        }

        @objc func textDidChange(_ textField: UITextField) {
            guard textField.markedTextRange == nil else { return }
            let current = textField.text ?? ""
            // Звичайна правка вже пройшла делегат і приймається; сюди доходить зайве лише після складання.
            if case .replace(let text, let cursor) = SwitchName.edit(from: parent.text, to: current) {
                apply(text, cursor: cursor, to: textField)
            } else if parent.text != current {
                parent.text = current
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            textField.resignFirstResponder()
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused { parent.isFocused = false }
        }

        private func apply(_ text: String, cursor: Int, to textField: UITextField) {
            textField.text = text
            textField.placeCursor(at: cursor)
            if parent.text != text { parent.text = text }
        }
    }
}

/// Багаторядкове поле редагування назви на екрані перемикача: росте по висоті з текстом,
/// як назва в режимі перегляду. «Готово» (перенос рядка) викликає `onFinish`.
struct SwitchNameTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    /// Колір тексту й курсора.
    let textColor: Color
    let placeholderColor: Color
    let accessibilityIdentifier: String
    let onFinish: () -> Void

    func makeUIView(context: Context) -> NameTextView {
        let textView = NameTextView()
        textView.delegate = context.coordinator
        textView.font = .scaledSystemFont(.title1, weight: .bold)
        textView.adjustsFontForContentSizeCategory = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.returnKeyType = .done
        textView.placeholder = placeholder
        textView.accessibilityIdentifier = accessibilityIdentifier
        textView.accessibilityLabel = "Назва"
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: NameTextView, context: Context) {
        context.coordinator.parent = self
        if textView.markedTextRange == nil, textView.text != text {
            textView.text = text
            textView.invalidateIntrinsicContentSize()
        }
        // Кольори — лише коли змінилися: присвоєння `textColor` посеред складання (IME) зриває його.
        if context.coordinator.appliedTextColor != textColor {
            context.coordinator.appliedTextColor = textColor
            textView.textColor = UIColor(textColor)
            textView.tintColor = UIColor(textColor)
        }
        if context.coordinator.appliedPlaceholderColor != placeholderColor {
            context.coordinator.appliedPlaceholderColor = placeholderColor
            textView.placeholderColor = UIColor(placeholderColor)
        }
        textView.wantsFocus = isFocused
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView textView: NameTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        return CGSize(width: width, height: textView.fittingHeight(width: width))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SwitchNameTextView
        /// Кольори, уже присвоєні полю.
        var appliedTextColor: Color?
        var appliedPlaceholderColor: Color?

        init(parent: SwitchNameTextView) {
            self.parent = parent
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard textView.markedTextRange == nil else { return true }
            switch SwitchName.edit(textView.text, range: range, replacement: text, allowsNewlineFinish: true) {
            case .accept:
                return true
            case .replace(let text, let cursor):
                apply(text, cursor: cursor, to: textView)
                return false
            case .reject:
                return false
            case .finish:
                parent.onFinish()
                return false
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            // Висота змінюється й під час складання, тож — до перевірки.
            textView.invalidateIntrinsicContentSize()
            guard textView.markedTextRange == nil else { return }
            let current = textView.text ?? ""
            if case .replace(let text, let cursor) = SwitchName.edit(from: parent.text, to: current) {
                apply(text, cursor: cursor, to: textView)
            } else if parent.text != current {
                parent.text = current
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isFocused { parent.isFocused = false }
        }

        private func apply(_ text: String, cursor: Int, to textView: UITextView) {
            textView.text = text
            textView.placeCursor(at: cursor)
            textView.invalidateIntrinsicContentSize()
            if parent.text != text { parent.text = text }
        }
    }
}

/// `UITextField`, що бере фокус, щойно цього хоче прив'язка й поле вже у вікні.
final class NameTextField: UITextField {
    var wantsFocus = false {
        didSet { applyFocus() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyFocus()
    }

    private func applyFocus() {
        guard window != nil else { return }
        if wantsFocus, !isFirstResponder {
            becomeFirstResponder()
        } else if !wantsFocus, isFirstResponder {
            resignFirstResponder()
        }
    }
}

/// `UITextView` з підказкою в порожньому полі й фокусом, як у `NameTextField`.
final class NameTextView: UITextView {
    private let placeholderLabel = UILabel()

    var placeholder: String {
        get { placeholderLabel.text ?? "" }
        set {
            placeholderLabel.text = newValue
            updatePlaceholder()
        }
    }

    var placeholderColor: UIColor {
        get { placeholderLabel.textColor }
        set { placeholderLabel.textColor = newValue }
    }

    var wantsFocus = false {
        didSet { applyFocus() }
    }

    override var text: String! {
        didSet {
            applyHyphenation()
            updatePlaceholder()
        }
    }

    override var font: UIFont? {
        didSet { placeholderLabel.font = font }
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        placeholderLabel.numberOfLines = 0
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.isAccessibilityElement = false
        addSubview(placeholderLabel)
        applyHyphenation()
        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange), name: UITextView.textDidChangeNotification, object: self
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Висота для ширини `width`: увесь текст, а в порожньому полі — підказка.
    func fittingHeight(width: CGFloat) -> CGFloat {
        let textHeight = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        guard !placeholderLabel.isHidden else { return textHeight }
        let placeholderHeight = placeholderLabel.sizeThatFits(CGSize(width: placeholderWidth(for: width), height: .greatestFiniteMagnitude)).height
        return max(textHeight, placeholderHeight + textContainerInset.top + textContainerInset.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = placeholderWidth(for: bounds.width)
        let height = placeholderLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        placeholderLabel.frame = CGRect(
            x: textContainerInset.left + textContainer.lineFragmentPadding,
            y: textContainerInset.top,
            width: width,
            height: height
        )
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyFocus()
    }

    private func placeholderWidth(for width: CGFloat) -> CGFloat {
        max(0, width - textContainerInset.left - textContainerInset.right - 2 * textContainer.lineFragmentPadding)
    }

    /// Довге слово переноситься з дефісом, як у SwiftUI-полі, що було тут раніше.
    private func applyHyphenation() {
        let style = NSMutableParagraphStyle()
        style.hyphenationFactor = 1
        textStorage.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: textStorage.length))
        typingAttributes[.paragraphStyle] = style
    }

    @objc private func textDidChange() {
        updatePlaceholder()
    }

    /// Підказка видна лише в порожньому полі; VoiceOver її не бачить (`placeholderLabel` прихована
    /// від нього), тож у порожньому полі вона — `accessibilityHint` самого поля.
    private func updatePlaceholder() {
        placeholderLabel.isHidden = !text.isEmpty
        accessibilityHint = text.isEmpty ? placeholder : nil
    }

    private func applyFocus() {
        guard window != nil else { return }
        if wantsFocus, !isFirstResponder {
            becomeFirstResponder()
        } else if !wantsFocus, isFirstResponder {
            resignFirstResponder()
        }
    }
}

private extension UITextInput {
    /// Ставить курсор на `offset` (зсув UTF-16 від початку тексту).
    func placeCursor(at offset: Int) {
        guard let position = position(from: beginningOfDocument, offset: offset) else { return }
        selectedTextRange = textRange(from: position, to: position)
    }
}

private extension UIFont {
    /// Системний шрифт стилю `style` з вагою `weight`, що масштабується з Dynamic Type —
    /// як `Font.body.weight(.medium)` чи `Font.title.bold()` у SwiftUI.
    static func scaledSystemFont(_ style: TextStyle, weight: Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        return UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: base.pointSize, weight: weight))
    }
}
