import SwiftUI

/// Верх аркуша: «Скасувати» ліворуч і головна дія-капсула праворуч. Якщо разом в один рядок
/// не влазять (великий шрифт), кожна кнопка стає на власний рядок — слова не рвуться й не обрізаються.
struct SheetHeader: View {
    let confirmTitle: String
    let isConfirmEnabled: Bool
    let cancelIdentifier: String
    let confirmIdentifier: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                cancelButton
                Spacer()
                confirmButton
            }
            VStack(alignment: .leading, spacing: 8) {
                cancelButton
                confirmButton
            }
        }
    }

    private var cancelButton: some View {
        Button("Скасувати", action: onCancel)
            .font(.body.weight(.medium))
            .frame(minHeight: 44)
            .accessibilityIdentifier(cancelIdentifier)
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            Text(confirmTitle)
                .font(.headline)
                .foregroundStyle(Theme.background)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .frame(minHeight: 44)
                .background(Theme.ink, in: Capsule())
        }
        .opacity(isConfirmEnabled ? 1 : 0.4)
        .disabled(!isConfirmEnabled)
        .accessibilityIdentifier(confirmIdentifier)
    }
}
