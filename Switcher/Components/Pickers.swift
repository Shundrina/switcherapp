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
                .accessibilityIdentifier("toneOption_\(tone.rawValue)")
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Сітка значків 4×2: сім основних і восьма комірка, яка відкриває «Усі значки». Значок не з основних
/// після вибору показується у восьмій комірці замість «…».
struct IconPicker: View {
    @Binding var selection: SwitchIcon
    let tone: SwitchTone
    @State private var isShowingAllIcons = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(SwitchIcon.featured) { icon in
                let isSelected = icon == selection
                Button {
                    selection = icon
                } label: {
                    IconCell(isSelected: isSelected, tone: tone, height: 56) {
                        Text(icon.rawValue)
                            .font(.system(size: 28))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("iconOption_\(icon.rawValue)")
            }
            moreCell
        }
        .sensoryFeedback(.selection, trigger: selection)
        .sheet(isPresented: $isShowingAllIcons) {
            AllIconsView(selection: $selection, tone: tone)
        }
    }

    /// Восьма комірка: «…» або вибраний значок не з основних. Натискання відкриває «Усі значки».
    private var moreCell: some View {
        let shown = SwitchIcon.moreCellIcon(for: selection)
        return Button {
            isShowingAllIcons = true
        } label: {
            IconCell(isSelected: shown != nil, tone: tone, height: 56) {
                if let shown {
                    Text(shown.rawValue)
                        .font(.system(size: 28))
                } else {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(shown?.title ?? "Усі значки")
        .accessibilityHint(shown == nil ? "" : "Відкрити всі значки")
        .accessibilityAddTraits(shown != nil ? .isSelected : [])
        .accessibilityIdentifier(shown.map { "iconOption_\($0.rawValue)" } ?? "iconOptionMore")
    }
}

/// Екран «Усі значки»: увесь набір за розділами. Натискання вибирає значок і закриває екран.
struct AllIconsView: View {
    @Binding var selection: SwitchIcon
    let tone: SwitchTone
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button("Скасувати") { dismiss() }
                        .font(.body.weight(.medium))
                        .frame(minHeight: 44)
                    Spacer()
                }
                Text("Усі значки")
                    .font(.title.bold())
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
                ForEach(SwitchIcon.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .capsStyle()
                            .padding(.horizontal, 4)
                            .accessibilityAddTraits(.isHeader)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(section.icons) { icon in
                                option(icon)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .tint(Theme.ink)
        .presentationBackground(Theme.background)
        .presentationDragIndicator(.visible)
    }

    private func option(_ icon: SwitchIcon) -> some View {
        let isSelected = icon == selection
        return Button {
            selection = icon
            dismiss()
        } label: {
            IconCell(isSelected: isSelected, tone: tone, height: 52) {
                Text(icon.rawValue)
                    .font(.system(size: 28))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("allIconsOption_\(icon.rawValue)")
    }
}

/// Комірка сітки значків: вибрана — з тлом кольору перемикача й рамкою.
/// Емодзі кольором не перефарбовуються.
private struct IconCell<Content: View>: View {
    let isSelected: Bool
    let tone: SwitchTone
    let height: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        content
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(isSelected ? tone.color : Theme.surface, in: shape)
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: 2).opacity(isSelected ? 1 : 0))
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
