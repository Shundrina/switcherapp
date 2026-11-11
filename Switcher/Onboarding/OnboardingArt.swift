import SwiftUI

/// Перший слайд: великий перемикач сам вмикається, і тло заливає жовтим.
struct ToggleArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOn = true
    @State private var isFloating = false

    var body: some View {
        ZStack {
            FloodBackground(
                isOn: isOn,
                color: OnboardingPalette.sun,
                origin: UnitPoint(x: 0.64, y: 0.5),
                base: OnboardingPalette.artBase
            )
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                chip("Полила квіти", angle: -8, duration: 2.5)
                    .position(x: width * 0.3, y: height * 0.16)
                chip("Двері зачинені", angle: 6, duration: 3.1)
                    .position(x: width * 0.7, y: height * 0.25)
                chip("Праска вимкнена", angle: 4, duration: 2.8)
                    .position(x: width * 0.45, y: height * 0.86)
                spark(size: 30, delay: 0.25)
                    .position(x: width * 0.86, y: height * 0.4)
                spark(size: 20, delay: 0.35)
                    .position(x: width * 0.8, y: height * 0.72)
                spark(size: 24, delay: 0.45)
                    .position(x: width * 0.12, y: height * 0.66)
            }
            bigToggle
        }
        .task {
            guard !reduceMotion else { return }
            isFloating = true
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.8))
                isOn.toggle()
            }
        }
    }

    private var bigToggle: some View {
        Capsule()
            .fill(isOn ? OnboardingPalette.cardInk : OnboardingPalette.muted)
            .frame(width: 196, height: 104)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: 88, height: 88)
                    .padding(8)
            }
            .shadow(color: OnboardingPalette.cardInk.opacity(0.25), radius: 20, y: 18)
            .animation(.spring(response: 0.45, dampingFraction: 0.55), value: isOn)
    }

    private func chip(_ text: String, angle: Double, duration: Double) -> some View {
        Text(text)
            .font(.footnote.weight(.bold))
            .foregroundStyle(OnboardingPalette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(OnboardingPalette.surface, in: Capsule())
            .shadow(color: OnboardingPalette.cardInk.opacity(0.18), radius: 10, y: 8)
            .rotationEffect(.degrees(angle))
            .offset(y: isFloating ? -10 : 0)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true), value: isFloating)
    }

    private func spark(size: CGFloat, delay: Double) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(OnboardingPalette.cardInk)
            .scaleEffect(isOn ? 1 : 0.01)
            .rotationEffect(.degrees(isOn ? 0 : -90))
            .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(isOn ? delay : 0), value: isOn)
    }
}

/// Другий слайд: записи з часом з'являються один за одним, крутиться годинник.
struct HistoryArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownCount = 3
    @State private var isSpinning = false

    private struct Entry: Identifiable {
        let id: Int
        let name: String
        let time: String
        let color: Color
    }

    private let entries = [
        Entry(id: 0, name: "Полила квіти", time: "08:15", color: OnboardingPalette.mint),
        Entry(id: 1, name: "Двері зачинені", time: "09:40", color: OnboardingPalette.sun),
        Entry(id: 2, name: "Газ вимкнено", time: "13:02", color: OnboardingPalette.tomato)
    ]

    var body: some View {
        ZStack {
            OnboardingPalette.sky
            clock
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 34, y: -34)
            VStack(spacing: 10) {
                ForEach(entries) { entry in
                    let isShown = entry.id < shownCount
                    row(entry)
                        .opacity(isShown ? 1 : 0)
                        .offset(y: isShown ? 0 : 40)
                        .scaleEffect(isShown ? 1 : 0.9)
                }
            }
            .padding(.horizontal, 24)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: shownCount)
        }
        .task {
            guard !reduceMotion else { return }
            isSpinning = true
            while !Task.isCancelled {
                shownCount = 0
                for count in 1...entries.count {
                    try? await Task.sleep(for: .seconds(0.3))
                    shownCount = count
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private var clock: some View {
        Circle()
            .fill(OnboardingPalette.cardInk.opacity(0.16))
            .frame(width: 170, height: 170)
            .overlay {
                hand(length: 40, duration: 48)
                hand(length: 62, duration: 4)
            }
    }

    private func hand(length: CGFloat, duration: Double) -> some View {
        Capsule()
            .fill(OnboardingPalette.cardInk)
            .frame(width: 6, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(.linear(duration: duration).repeatForever(autoreverses: false), value: isSpinning)
    }

    private func row(_ entry: Entry) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(entry.color)
                .frame(width: 14, height: 14)
            Text(entry.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingPalette.ink)
            Spacer()
            Text(entry.time)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(OnboardingPalette.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(OnboardingPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: OnboardingPalette.cardInk.opacity(0.18), radius: 12, y: 10)
    }
}
