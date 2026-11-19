import SwiftUI
import UIKit

/// Палітра основних екранів («Лампа»): нейтральне тло, а колір з'являється лише на ввімкненому перемикачі.
enum Theme {
    static let background = Color(light: 0xF1F2F4, dark: 0x0F1114)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1B1E24)
    static let ink = Color(light: 0x16181D, dark: 0xF4F5F7)
    static let muted = Color(light: 0x5B616E, dark: 0xA3A9B5)
    static let line = Color(light: 0xE3E5E9, dark: 0x2A2E36)
    static let bubble = Color(light: 0xF1F2F4, dark: 0x2A2E36)
    static let track = Color(light: 0x8A909C, dark: 0x6B7280)
    /// Текст і деталі на кольоровій картці; однаковий в обох темах.
    static let onTone = Color(hex: 0x16181D)
    /// Кружечок під значком-емодзі на кольоровій картці: світліший за картку, щоб темні емодзі
    /// (📱, 📷) не губилися; однаковий в обох темах.
    static let bubbleOnTone = Color(hex: 0xFFFFFF).opacity(0.55)
    /// Попередження (лічильник понад межу). Системний червоний на білому тлі й кольоровій картці
    /// має замалий контраст, тож свій: не менше 4,5:1 на `surface` і `background` в обох темах.
    static let warning = Color(light: 0xC62828, dark: 0xFF6B6B)
    /// Попередження на кольоровій картці: темно-червоний, не менше 4,5:1 на кожному `SwitchTone`.
    static let warningOnTone = Color(hex: 0x7A1010)
}

// SwiftUI під час анімацій обчислює кольори у фоновому потоці, тому цей код не можна прив'язувати до головного актора.
nonisolated extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Колір, що сам перемикається між світлою і темною темою.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

extension View {
    /// Дрібний заголовок великими літерами: дата, назва поля, день в історії.
    func capsStyle() -> some View {
        font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(Theme.muted)
    }
}

extension Text {
    /// Переносить текст лише між словами. Для українського тексту SwiftUI сам розставляє переноси
    /// посеред слова («уві-/мкнено»); правила англійської мови кирилиці не ділять, а на вигляд
    /// літер мова набору не впливає.
    func wrapsWholeWords() -> Text {
        typesettingLanguage(.explicit(Locale.Language(identifier: "en")))
    }
}
