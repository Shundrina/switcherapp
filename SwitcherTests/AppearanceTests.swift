import SwiftUI
import Testing
import UIKit
@testable import Switcher

@MainActor
struct SwitchAppearanceTests {
    // Значок і колір зберігаються в SwiftData як рядки (`iconRaw`, `toneRaw`).
    // Якщо case перейменувати чи видалити, старі записи мовчки прочитаються як
    // значення за замовчуванням (`.check` / `.amber`), і користувач втратить вибір.
    // Тест фіксує поточні сирі значення: міняти списки можна лише разом з міграцією даних.
    @Test func iconRawValuesAreStable() {
        #expect(SwitchIcon.allCases.map(\.rawValue) == [
            "drop", "flame", "lock", "pill", "power", "bell", "clock", "check"
        ])
    }

    // Див. коментар до `iconRawValuesAreStable`.
    @Test func toneRawValuesAreStable() {
        #expect(SwitchTone.allCases.map(\.rawValue) == [
            "amber", "coral", "mint", "sky", "lilac", "pink"
        ])
    }

    @Test(arguments: SwitchIcon.allCases)
    func iconRoundTripsThroughRawValue(icon: SwitchIcon) {
        #expect(SwitchIcon(rawValue: icon.rawValue) == icon)
    }

    @Test(arguments: SwitchTone.allCases)
    func toneRoundTripsThroughRawValue(tone: SwitchTone) {
        #expect(SwitchTone(rawValue: tone.rawValue) == tone)
    }

    @Test func rawValuesAreUnique() {
        #expect(Set(SwitchIcon.allCases.map(\.rawValue)).count == SwitchIcon.allCases.count)
        #expect(Set(SwitchTone.allCases.map(\.rawValue)).count == SwitchTone.allCases.count)
    }

    @Test(arguments: SwitchIcon.allCases)
    func iconSymbolExistsInSFSymbols(icon: SwitchIcon) {
        #expect(UIImage(systemName: icon.symbolName) != nil, "Немає SF Symbol «\(icon.symbolName)»")
    }
}

/// Компоненти RGB кольору в діапазоні 0…255.
nonisolated struct RGB: Equatable, CustomStringConvertible {
    let red: Int
    let green: Int
    let blue: Int

    init(hex: UInt32) {
        red = Int((hex >> 16) & 0xFF)
        green = Int((hex >> 8) & 0xFF)
        blue = Int(hex & 0xFF)
    }

    init(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Int((r * 255).rounded())
        green = Int((g * 255).rounded())
        blue = Int((b * 255).rounded())
    }

    /// Розв'язує колір SwiftUI для світлої чи темної теми.
    static func resolve(_ color: Color, _ style: UIUserInterfaceStyle) -> RGB {
        RGB(UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style)))
    }

    var description: String { String(format: "#%02X%02X%02X", red, green, blue) }
}

@MainActor
struct ThemeColorTests {
    @Test func hexColorHasExpectedComponents() {
        #expect(RGB.resolve(Color(hex: 0xFFC83D), .light) == RGB(hex: 0xFFC83D))
        #expect(RGB.resolve(Color(hex: 0x000000), .light) == RGB(hex: 0x000000))
        #expect(RGB.resolve(Color(hex: 0xFFFFFF), .light) == RGB(hex: 0xFFFFFF))
        #expect(RGB.resolve(Color(hex: 0x16181D), .dark) == RGB(hex: 0x16181D))
    }

    @Test func toneColorsMatchPalette() {
        let expected: [SwitchTone: UInt32] = [
            .amber: 0xFFC83D, .coral: 0xFF8F70, .mint: 0x5FD9A0,
            .sky: 0x6FB6FF, .lilac: 0xB9A2FF, .pink: 0xFF9AD0
        ]
        for tone in SwitchTone.allCases {
            #expect(RGB.resolve(tone.color, .light) == RGB(hex: expected[tone]!), "\(tone)")
        }
    }

    @Test func lightDarkColorResolvesOnMainActor() {
        let color = Color(light: 0xF1F2F4, dark: 0x0F1114)
        #expect(RGB.resolve(color, .light) == RGB(hex: 0xF1F2F4))
        #expect(RGB.resolve(color, .dark) == RGB(hex: 0x0F1114))
    }

    // Регресійний тест: SwiftUI під час анімацій розв'язує кольори у фоновому потоці.
    // Якби замикання в `Color(light:dark:)` успадкувало ізоляцію головного актора,
    // виклик поза ним завершився б аварійно (перевірка ізоляції під час виконання).
    @Test func lightDarkColorResolvesOffMainActor() async {
        let (light, dark) = await Task.detached {
            let color = Color(light: 0x123456, dark: 0xABCDEF)
            return (RGB.resolve(color, .light), RGB.resolve(color, .dark))
        }.value

        #expect(light == RGB(hex: 0x123456))
        #expect(dark == RGB(hex: 0xABCDEF))
    }

    // Те саме для кольорів теми, створених на головному акторі, а розв'язаних у фоні —
    // саме так їх використовує SwiftUI.
    @Test func themeColorsResolveOffMainActor() async {
        let colors: [(Color, UInt32, UInt32)] = [
            (Theme.background, 0xF1F2F4, 0x0F1114),
            (Theme.surface, 0xFFFFFF, 0x1B1E24),
            (Theme.ink, 0x16181D, 0xF4F5F7),
            (Theme.muted, 0x5B616E, 0xA3A9B5),
            (Theme.line, 0xE3E5E9, 0x2A2E36),
            (Theme.bubble, 0xF1F2F4, 0x2A2E36),
            (Theme.track, 0x8A909C, 0x6B7280)
        ]
        let onTone = Theme.onTone

        let resolved = await Task.detached {
            (
                colors.map { (RGB.resolve($0.0, .light), RGB.resolve($0.0, .dark)) },
                RGB.resolve(onTone, .light),
                RGB.resolve(onTone, .dark)
            )
        }.value

        for (index, (light, dark)) in resolved.0.enumerated() {
            #expect(light == RGB(hex: colors[index].1))
            #expect(dark == RGB(hex: colors[index].2))
        }
        #expect(resolved.1 == RGB(hex: 0x16181D))
        #expect(resolved.2 == RGB(hex: 0x16181D))
    }
}
