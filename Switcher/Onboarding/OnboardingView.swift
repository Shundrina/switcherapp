import SwiftUI

/// Палітра онбордингу: яскравіша за основні екрани.
enum OnboardingPalette {
    static let background = Color(light: 0xF6F4FC, dark: 0x131026)
    static let ink = Color(light: 0x17132B, dark: 0xF4F1FF)
    static let muted = Color(light: 0x5A5674, dark: 0xA9A4C8)
    static let line = Color(light: 0xCFCBE2, dark: 0x342E55)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1E1A38)
    static let artBase = Color(light: 0xE4E0F3, dark: 0x2A2548)
    /// Темні деталі на кольорових ілюстраціях; однаковий в обох темах.
    static let cardInk = Color(hex: 0x17132B)
    static let sun = Color(hex: 0xFFC629)
    static let sky = Color(hex: 0x3D8BFF)
    static let mint = Color(hex: 0x23D18B)
    static let tomato = Color(hex: 0xFF5A3C)
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    private let pageCount = 2

    private var isLastPage: Bool {
        page == pageCount - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Пропустити", action: onFinish)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OnboardingPalette.muted)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 22)

            TabView(selection: $page) {
                OnboardingPage(
                    title: "Клац — і спокій",
                    text: "Вимкнула праску? Зачинила двері? Перемкніть — і більше не сумнівайтеся."
                ) {
                    ToggleArt()
                }
                .tag(0)
                OnboardingPage(
                    title: "Пам'ятає за вас",
                    text: "Кожне перемикання зберігається з датою й часом. Історія завжди під рукою."
                ) {
                    HistoryArt()
                }
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack {
                dots
                Spacer()
                nextButton
            }
            .frame(height: 60)
            .padding(.horizontal, 22)
            .padding(.top, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(OnboardingPalette.background.ignoresSafeArea())
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? OnboardingPalette.ink : OnboardingPalette.line)
                    .frame(width: index == page ? 30 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: page)
        .accessibilityHidden(true)
    }

    private var nextButton: some View {
        Button {
            if isLastPage {
                onFinish()
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    page += 1
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isLastPage {
                    Text("Почати")
                        .font(.headline)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                Image(systemName: "arrow.right")
                    .font(.title3.weight(.semibold))
            }
            .foregroundStyle(OnboardingPalette.background)
            .padding(.horizontal, 18)
            .frame(minWidth: 60, minHeight: 60)
            .background(OnboardingPalette.ink, in: Capsule())
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isLastPage)
        .accessibilityLabel(isLastPage ? "Почати" : "Далі")
    }
}

private struct OnboardingPage<Art: View>: View {
    let title: String
    let text: String
    @ViewBuilder let art: () -> Art

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            art()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(.title, weight: .heavy))
                    .fontWidth(.expanded)
                    .foregroundStyle(OnboardingPalette.ink)
                Text(text)
                    .font(.body)
                    .foregroundStyle(OnboardingPalette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
    }
}

#Preview {
    OnboardingView {}
}
