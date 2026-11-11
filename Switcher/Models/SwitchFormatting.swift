import Foundation

/// Тексти про дату й час перемикань. Інтерфейс лише українською, тому локаль зафіксовано.
nonisolated enum SwitchFormatting {
    static let locale = Locale(identifier: "uk_UA")

    /// Час у форматі «08:15».
    static func time(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// «сьогодні», «вчора» або «6 листопада» — для речення про останню зміну.
    static func dayPhrase(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "сьогодні" }
        if isYesterday(date, now: now, calendar: calendar) { return "вчора" }
        return date.formatted(style(calendar).day().month(.wide))
    }

    /// «Сьогодні», «Вчора» або «Понеділок, 9 листопада» — заголовок дня в історії.
    static func dayTitle(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Сьогодні" }
        if isYesterday(date, now: now, calendar: calendar) { return "Вчора" }
        let text = date.formatted(style(calendar).weekday(.wide).day().month(.wide))
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// «Увімкнено сьогодні о 08:15», «Вимкнено вчора о 21:30» або «Ще не перемикали».
    static func status(isOn: Bool, lastToggledAt: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let date = lastToggledAt else { return "Ще не перемикали" }
        let state = isOn ? "Увімкнено" : "Вимкнено"
        // Перед «одинадцятою» прийменник «об», перед рештою годин — «о».
        let preposition = calendar.component(.hour, from: date) == 11 ? "об" : "о"
        let day = dayPhrase(date, now: now, calendar: calendar)
        return "\(state) \(day) \(preposition) \(time(date, calendar: calendar))"
    }

    private static func isYesterday(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return false }
        return calendar.isDate(date, inSameDayAs: yesterday)
    }

    private static func style(_ calendar: Calendar) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
}
