import SwiftUI

/// Ряд кольорових кружечків для вибору кольору перемикача.
struct TonePicker: View {
    @Binding var selection: SwitchTone

    var body: some View {
        HStack(spacing: 10) {
            ForEach(SwitchTone.allCases) { tone in
                let isSelected = tone == selection
                Button {
                    selection = tone
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Theme.ink, lineWidth: 3)
                            .opacity(isSelected ? 1 : 0)
                        Circle()
                            .fill(tone.color)
                            .padding(isSelected ? 7 : 0)
                    }
                    .frame(width: 44, height: 44)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tone.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Сітка значків для вибору значка перемикача.
struct IconPicker: View {
    @Binding var selection: SwitchIcon
    let tone: SwitchTone

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(SwitchIcon.allCases) { icon in
                let isSelected = icon == selection
                let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                Button {
                    selection = icon
                } label: {
                    Image(systemName: icon.symbolName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.onTone : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isSelected ? tone.color : Theme.surface, in: shape)
                        .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2).opacity(isSelected ? 1 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
