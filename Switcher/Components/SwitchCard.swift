import SwiftUI

/// Тло картки: коли перемикач увімкнено, колір розтікається колом від точки `origin`.
struct FloodBackground: View {
    let isOn: Bool
    let color: Color
    var origin = UnitPoint(x: 0.88, y: 0.5)
    var base = Theme.surface

    var body: some View {
        GeometryReader { geometry in
            // Діаметр, якого вистачає, щоб коло накрило найдальший кут картки.
            let diameter = 2 * hypot(geometry.size.width, geometry.size.height)
            Circle()
                .fill(color)
                .frame(width: diameter, height: diameter)
                .scaleEffect(isOn ? 1 : 0.001)
                .position(x: geometry.size.width * origin.x, y: geometry.size.height * origin.y)
        }
        .background(base)
        .animation(.easeInOut(duration: 0.55), value: isOn)
    }
}

/// Значок-емодзі перемикача в кружечку.
struct IconBubble: View {
    let icon: SwitchIcon
    let isOn: Bool
    var size: CGFloat = 48

    var body: some View {
        Text(icon.rawValue)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(isOn ? Theme.bubbleOnTone : Theme.bubble, in: Circle())
            .animation(.easeInOut(duration: 0.3), value: isOn)
            .accessibilityLabel(icon.title)
    }
}

/// Ліва частина картки перемикача: значок, назва й речення про останню зміну.
struct SwitchCardLabel: View {
    let name: String
    let status: String
    let icon: SwitchIcon
    let isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            IconBubble(icon: icon, isOn: isOn)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(isOn ? Theme.onTone : Theme.ink)
                Text(status)
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(isOn ? Theme.onTone.opacity(0.8) : Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.3), value: isOn)
    }
}

extension View {
    /// Обгортає вміст у картку перемикача з кольоровим тлом.
    func switchCard(isOn: Bool, tone: SwitchTone, cornerRadius: CGFloat = 24, origin: UnitPoint = UnitPoint(x: 0.88, y: 0.5)) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        // `clipShape` обрізає лише малювання: коло тла, що розтікається далеко за картку, і далі
        // перехоплювало б натискання на сусідні елементи. Зону натискання обмежує `contentShape`.
        return background(FloodBackground(isOn: isOn, color: tone.color, origin: origin))
            .clipShape(shape)
            .contentShape(shape)
    }
}
