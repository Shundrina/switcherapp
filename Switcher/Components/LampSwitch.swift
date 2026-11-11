import SwiftUI

/// Вигляд тумблера без поведінки: доріжка й повзунок.
struct LampSwitch: View {
    let isOn: Bool
    var large = false

    var body: some View {
        let width: CGFloat = large ? 64 : 52
        let height: CGFloat = large ? 40 : 32
        let inset: CGFloat = large ? 4 : 3

        Capsule()
            .fill(isOn ? Theme.onTone : Theme.track)
            .frame(width: width, height: height)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: height - inset * 2, height: height - inset * 2)
                    .padding(inset)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isOn)
    }
}

/// Стиль для `Toggle`, що малює його як `LampSwitch`.
struct LampToggleStyle: ToggleStyle {
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            LampSwitch(isOn: configuration.isOn, large: large)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: configuration.isOn)
        // Для VoiceOver це звичайний перемикач із назвою.
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}
