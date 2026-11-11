import Foundation
import Testing
@testable import Switcher

/// Сторінки онбордингу як дані: кількість сторінок, індикатор і кнопка «Далі»/«Почати»
/// мають бути похідними від `OnboardingSlide.allCases`, а не від окремої константи.
@MainActor
struct OnboardingSlideTests {
    // Третя сторінка — про видалення — іде після двох наявних.
    @Test func slidesAreToggleHistoryThenDeletion() {
        #expect(OnboardingSlide.allCases == [.toggle, .history, .deletion])
    }

    // Перенесення сторінок із View у дані не має змінити наявні заголовки й тексти.
    @Test func firstTwoSlidesKeepTheirTitles() {
        #expect(OnboardingSlide.toggle.title == "Клац — і спокій")
        #expect(OnboardingSlide.toggle.text == "Вимкнула праску? Зачинила двері? Перемкніть — і більше не сумнівайтеся.")
        #expect(OnboardingSlide.history.title == "Пам'ятає за вас")
        #expect(OnboardingSlide.history.text == "Кожне перемикання зберігається з датою й часом. Історія завжди під рукою.")
    }

    @Test func everySlideHasTitleAndText() {
        for slide in OnboardingSlide.allCases {
            #expect(!slide.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(slide): порожній заголовок")
            #expect(!slide.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(slide): порожній текст")
        }
    }

    // Формулювання вільне; перевіряється суть: жест ліворуч, те, що йдеться про видалення,
    // і те, що перед видаленням застосунок перепитає.
    @Test func deletionSlideTellsAboutSwipingLeftToDelete() {
        let slide = OnboardingSlide.deletion
        let content = "\(slide.title) \(slide.text)".lowercased()

        #expect(content.contains("ліворуч") || content.contains("вліво"), "Немає напрямку жесту: «\(content)»")
        #expect(content.contains("видал"), "Немає згадки про видалення: «\(content)»")
        #expect(
            content.contains("перепита") || content.contains("підтвердж"),
            "Не сказано, що перед видаленням застосунок перепитає: «\(content)»"
        )
    }

    // «Почати» — лише на останній сторінці, на решті — «Далі».
    @Test func onlyFinalSlideIsLast() {
        #expect(OnboardingSlide.allCases.map(\.isLast) == [false, false, true])
    }
}
