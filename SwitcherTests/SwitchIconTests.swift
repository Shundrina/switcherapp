import Foundation
import SwiftData
import Testing
@testable import Switcher

// Емодзі з текстовим представленням за замовчуванням записано через екранування, щоб варіантний
// селектор U+FE0F було видно в коді й він не загубився під час редагування.
private let check = "\u{2714}\u{FE0F}"     // ✔️
private let wastebasket = "\u{1F5D1}\u{FE0F}" // 🗑️
private let bed = "\u{1F6CF}\u{FE0F}"       // 🛏️
private let plate = "\u{1F37D}\u{FE0F}"     // 🍽️
private let envelope = "\u{2709}\u{FE0F}"   // ✉️

/// Значок за емодзі з набору застосунку.
@MainActor
private func icon(_ emoji: String) throws -> SwitchIcon {
    try #require(SwitchIcon(rawValue: emoji), "Немає значка «\(emoji)» у наборі")
}

/// Набір значків-емодзі: основні сім для сітки й розділи екрана «Усі значки».
@MainActor
struct SwitchIconCatalogTests {
    @Test func featuredIconsInGridOrder() {
        #expect(SwitchIcon.featured.map(\.rawValue) == [check, "🔥", "🔒", "💊", "🔌", "🪴", "💧"])
    }

    @Test func sectionTitlesInOrder() {
        #expect(SwitchIcon.sections.map(\.title) == [
            "Дім", "Кухня", "Техніка", "Здоров'я", "Рослини й тварини", "Справи"
        ])
    }

    @Test func sectionContentsInOrder() {
        let expected: [[String]] = [
            ["🏠", "🔑", "🔒", "🚪", "🪟", "💡", "🛁", "🚿", "🧺", "🧹", wastebasket, bed],
            ["🔥", "🍳", "☕", "🫖", "🧊", plate, "🥛"],
            ["🔌", "📱", "💻", "🔋", "📺", "🎧", "📷"],
            ["💊", "💧", "🦷", "🏃", "🧘", "😴", "🩺", "🍩"],
            ["🪴", "🌵", "🌻", "🐕", "🐈", "🐟", "🐦"],
            [check, "📅", "⏰", "🔔", "📦", "💸", "🚗", "🚲", envelope, "🛒"]
        ]
        #expect(SwitchIcon.sections.map { $0.icons.map(\.rawValue) } == expected)
    }

    /// `allCases` — усі значки набору в порядку розділів.
    @Test func allCasesAreSectionsInOrder() {
        #expect(SwitchIcon.allCases == SwitchIcon.sections.flatMap(\.icons))
        #expect(SwitchIcon.allCases.count == 51)
    }

    @Test func catalogHasNoDuplicates() {
        let raw = SwitchIcon.allCases.map(\.rawValue)
        #expect(Set(raw).count == raw.count)
        #expect(Set(SwitchIcon.featured).count == SwitchIcon.featured.count)
    }

    @Test(arguments: SwitchIcon.featured)
    func featuredIconIsInCatalog(icon: SwitchIcon) {
        #expect(SwitchIcon.allCases.contains(icon), "Основного «\(icon.rawValue)» немає в «Усіх значках»")
    }

    @Test func defaultIconIsCheckMark() {
        #expect(SwitchIcon.check.rawValue == check)
        #expect(SwitchIcon.check.rawValue.unicodeScalars.map(\.value) == [0x2714, 0xFE0F])
        #expect(SwitchIcon.featured.first == .check)
    }

    /// Збережене значення має збігатися з тим, що видає клавіатура: емодзі з текстовим представленням
    /// за замовчуванням — з U+FE0F, решта — одним скаляром без селектора.
    @Test(arguments: SwitchIcon.allCases)
    func iconIsSingleFullyQualifiedEmoji(icon: SwitchIcon) throws {
        let value = icon.rawValue
        #expect(value.count == 1, "«\(value)» — не один символ")
        let scalars = Array(value.unicodeScalars)
        let base = try #require(scalars.first)
        #expect(base.properties.isEmoji, "«\(value)» — не емодзі")
        if base.properties.isEmojiPresentation {
            #expect(scalars == [base], "«\(value)» має бути без варіантного селектора")
        } else {
            #expect(scalars == [base, "\u{FE0F}"], "«\(value)» має закінчуватися U+FE0F")
        }
    }

    @Test func textStyleEmojiAreStoredWithVariationSelector() {
        let raw = Set(SwitchIcon.allCases.map(\.rawValue))
        for full in [check, wastebasket, bed, plate, envelope] {
            #expect(raw.contains(full), "Немає «\(full)» з U+FE0F")
            let bare = String(full.unicodeScalars.first!)
            #expect(!raw.contains(bare), "«\(bare)» записано без U+FE0F")
        }
    }

    @Test(arguments: SwitchIcon.allCases)
    func iconRoundTripsThroughRawValue(icon: SwitchIcon) {
        #expect(SwitchIcon(rawValue: icon.rawValue) == icon)
    }

    // Восьма комірка сітки: «…» (nil), поки вибрано одне з основних; інакше — сам вибраний значок.
    @Test(arguments: SwitchIcon.featured)
    func moreCellShowsEllipsisWhenFeaturedIsSelected(selection: SwitchIcon) {
        #expect(SwitchIcon.moreCellIcon(for: selection) == nil)
    }

    @Test(arguments: SwitchIcon.allCases.filter { !SwitchIcon.featured.contains($0) })
    func moreCellShowsSelectedIconOutsideFeatured(selection: SwitchIcon) {
        #expect(SwitchIcon.moreCellIcon(for: selection) == selection)
    }
}

/// Значок у моделі: старі назви SF Symbols з телефона читаються як емодзі, нові значення
/// зберігаються самим рядком емодзі.
@MainActor
struct SwitchIconStorageTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    private func makeItem(name: String = "Полила квіти") -> SwitchItem {
        let item = SwitchItem(name: name)
        context.insert(item)
        return item
    }

    @Test func newItemDefaultsToCheckEmoji() {
        let item = makeItem()

        #expect(item.icon == .check)
        #expect(item.iconRaw == check)
    }

    // Значення, які зберігала попередня версія (назви case старого enum `SwitchIcon`).
    @Test(arguments: [
        ("drop", "💧"), ("flame", "🔥"), ("lock", "🔒"), ("pill", "💊"),
        ("power", "🔌"), ("bell", "🔔"), ("clock", "⏰"), ("check", check)
    ])
    func legacyStoredIconReadsAsEmoji(legacy: String, emoji: String) throws {
        let item = makeItem()
        item.iconRaw = legacy
        try context.save()

        #expect(item.icon.rawValue == emoji)

        let stored = try #require(try ModelContext(container).fetch(FetchDescriptor<SwitchItem>()).first)
        #expect(stored.icon.rawValue == emoji)
    }

    @Test(arguments: ["rocket", "", "Check", "checkmark"])
    func unknownStoredIconReadsAsCheck(raw: String) {
        let item = makeItem()
        item.iconRaw = raw

        #expect(item.icon == .check)
    }

    @Test func newIconIsStoredAsEmoji() throws {
        let item = SwitchItem(name: "Прання", icon: try icon("🧺"), tone: .sky)
        context.insert(item)
        #expect(item.iconRaw == "🧺")

        item.icon = try icon(wastebasket)
        #expect(item.iconRaw == wastebasket)
        try context.save()

        let stored = try #require(try ModelContext(container).fetch(FetchDescriptor<SwitchItem>()).first)
        #expect(stored.iconRaw == wastebasket)
        #expect(stored.icon == (try icon(wastebasket)))
    }

    @Test(arguments: SwitchIcon.allCases)
    func everyCatalogIconSurvivesStorage(icon: SwitchIcon) {
        let item = makeItem()
        item.icon = icon

        #expect(item.iconRaw == icon.rawValue)
        #expect(item.icon == icon)
    }
}
