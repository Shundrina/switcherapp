import SwiftUI

/// Значок перемикача — емодзі з набору застосунку. У SwiftData зберігається самим емодзі (`rawValue`).
nonisolated struct SwitchIcon: Hashable, Identifiable, CaseIterable, RawRepresentable {
    /// Емодзі. Ті, що за замовчуванням показуються як текст, записано з варіантним селектором U+FE0F —
    /// так само, як їх видає клавіатура.
    let rawValue: String
    /// Назва для VoiceOver.
    let title: String

    var id: String { rawValue }

    private init(_ rawValue: String, _ title: String) {
        self.rawValue = rawValue
        self.title = title
    }

    /// Значок із набору; `nil`, якщо такого емодзі в наборі немає.
    init?(rawValue: String) {
        guard let icon = Self.byRawValue[rawValue] else { return nil }
        self = icon
    }

    /// Значок за назвою, яку зберігала попередня версія (case старого enum із SF Symbols).
    init?(legacyName: String) {
        let emoji: String? = switch legacyName {
        case "drop": "💧"
        case "flame": "🔥"
        case "lock": "🔒"
        case "pill": "💊"
        case "power": "🔌"
        case "bell": "🔔"
        case "clock": "⏰"
        case "check": Self.check.rawValue
        default: nil
        }
        guard let emoji else { return nil }
        self.init(rawValue: emoji)
    }

    /// Значок за замовчуванням: ✔️.
    static let check = SwitchIcon("\u{2714}\u{FE0F}", "Позначка")

    /// Сім основних значків — перші комірки сітки вибору.
    static let featured: [SwitchIcon] = [check.rawValue, "🔥", "🔒", "💊", "🔌", "🪴", "💧"]
        .compactMap(SwitchIcon.init(rawValue:))

    /// Увесь набір за розділами — екран «Усі значки». Кожен значок — лише в одному розділі.
    static let sections: [SwitchIconSection] = [
        SwitchIconSection(title: "Дім", icons: [
            SwitchIcon("🏠", "Дім"), SwitchIcon("🔑", "Ключ"), SwitchIcon("🔒", "Замок"),
            SwitchIcon("🚪", "Двері"), SwitchIcon("🪟", "Вікно"), SwitchIcon("💡", "Лампочка"),
            SwitchIcon("🛁", "Ванна"), SwitchIcon("🚿", "Душ"), SwitchIcon("🧺", "Прання"),
            SwitchIcon("🧹", "Віник"), SwitchIcon("\u{1F5D1}\u{FE0F}", "Смітник"), SwitchIcon("\u{1F6CF}\u{FE0F}", "Ліжко")
        ]),
        SwitchIconSection(title: "Кухня", icons: [
            SwitchIcon("🔥", "Вогонь"), SwitchIcon("🍳", "Сковорідка"), SwitchIcon("☕", "Кава"),
            SwitchIcon("🫖", "Чайник"), SwitchIcon("🧊", "Лід"), SwitchIcon("\u{1F37D}\u{FE0F}", "Тарілка"),
            SwitchIcon("🥛", "Молоко")
        ]),
        SwitchIconSection(title: "Техніка", icons: [
            SwitchIcon("🔌", "Живлення"), SwitchIcon("📱", "Телефон"), SwitchIcon("💻", "Ноутбук"),
            SwitchIcon("🔋", "Батарея"), SwitchIcon("📺", "Телевізор"), SwitchIcon("🎧", "Навушники"),
            SwitchIcon("📷", "Фотоапарат")
        ]),
        SwitchIconSection(title: "Здоров'я", icons: [
            SwitchIcon("💊", "Ліки"), SwitchIcon("💧", "Крапля"), SwitchIcon("🦷", "Зуб"),
            SwitchIcon("🏃", "Біг"), SwitchIcon("🧘", "Медитація"), SwitchIcon("😴", "Сон"),
            SwitchIcon("🩺", "Стетоскоп"), SwitchIcon("🍩", "Пончик")
        ]),
        SwitchIconSection(title: "Рослини й тварини", icons: [
            SwitchIcon("🪴", "Вазон"), SwitchIcon("🌵", "Кактус"), SwitchIcon("🌻", "Соняшник"),
            SwitchIcon("🐕", "Собака"), SwitchIcon("🐈", "Кіт"), SwitchIcon("🐟", "Риба"),
            SwitchIcon("🐦", "Пташка")
        ]),
        SwitchIconSection(title: "Справи", icons: [
            check, SwitchIcon("📅", "Календар"), SwitchIcon("⏰", "Будильник"),
            SwitchIcon("🔔", "Дзвоник"), SwitchIcon("📦", "Посилка"), SwitchIcon("💸", "Гроші"),
            SwitchIcon("🚗", "Автомобіль"), SwitchIcon("🚲", "Велосипед"), SwitchIcon("\u{2709}\u{FE0F}", "Лист"),
            SwitchIcon("🛒", "Покупки")
        ])
    ]

    /// Усі значки набору в порядку розділів.
    static let allCases = sections.flatMap(\.icons)

    private static let byRawValue = Dictionary(uniqueKeysWithValues: allCases.map { ($0.rawValue, $0) })

    /// Що показати у восьмій комірці сітки: `nil` — «…», поки вибрано один з основних;
    /// інакше — сам вибраний значок.
    static func moreCellIcon(for selection: SwitchIcon) -> SwitchIcon? {
        featured.contains(selection) ? nil : selection
    }
}

/// Розділ екрана «Усі значки».
nonisolated struct SwitchIconSection: Identifiable {
    let title: String
    let icons: [SwitchIcon]

    var id: String { title }
}

/// Колір увімкненого перемикача. Усі кольори достатньо світлі для темного тексту.
nonisolated enum SwitchTone: String, CaseIterable, Identifiable {
    case amber, coral, mint, sky, lilac, pink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .amber: Color(hex: 0xFFC83D)
        case .coral: Color(hex: 0xFF8F70)
        case .mint: Color(hex: 0x5FD9A0)
        case .sky: Color(hex: 0x6FB6FF)
        case .lilac: Color(hex: 0xB9A2FF)
        case .pink: Color(hex: 0xFF9AD0)
        }
    }

    var title: String {
        switch self {
        case .amber: "Бурштин"
        case .coral: "Корал"
        case .mint: "М'ята"
        case .sky: "Небо"
        case .lilac: "Бузок"
        case .pink: "Рожевий"
        }
    }
}
