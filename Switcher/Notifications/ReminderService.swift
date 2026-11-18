import Combine
import Foundation
import Observation
import SwiftData
import UserNotifications

/// Підключення нагадувань до застосунку: спільний `ModelContainer`, центр сповіщень і дозвіл.
/// Переплановує після перемикань і змін правил, при поверненні в застосунок і після зміни поясу,
/// системного часу чи дня; виконує «Перемкнути» зі сповіщення.
@MainActor
@Observable
final class ReminderService {
    /// Дозвіл на сповіщення; оновлюється при запуску, поверненні в застосунок і після запиту.
    private(set) var permission = NotificationPermission.notDetermined

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let authorization: any NotificationAuthorizing
    @ObservationIgnored private let center: any ReminderNotificationCenter
    @ObservationIgnored private let scheduler: ReminderScheduler
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: () -> Calendar
    @ObservationIgnored private var timeChanges: AnyCancellable?
    @ObservationIgnored private var hasRepairedIdentities = false

    /// - Parameters:
    ///   - systemEvents: звідки приходять системні події часу (`CurrentDateRefresh.notificationNames`).
    ///   - now, calendar: годинник і календар для планування; тести їх підміняють.
    init(
        container: ModelContainer,
        center: any ReminderNotificationCenter,
        authorization: any NotificationAuthorizing,
        systemEvents: NotificationCenter = .default,
        now: @escaping () -> Date = { .now },
        calendar: @escaping () -> Calendar = { .current }
    ) {
        context = container.mainContext
        self.center = center
        self.authorization = authorization
        scheduler = ReminderScheduler(center: center)
        self.now = now
        self.calendar = calendar
        timeChanges = CurrentDateRefresh.publisher(center: systemEvents).sink { [weak self] in
            Task { await self?.timeDidChange() }
        }
    }

    /// При запуску: категорія з кнопкою «Перемкнути», лагодження дублікатів UUID, дозвіл (без питання)
    /// і план.
    func start() async {
        repairIdentitiesIfNeeded()
        await center.setNotificationCategories([ReminderNotifications.category])
        permission = await authorization.permission()
        await reschedule()
    }

    /// При поверненні в застосунок: дозвіл могли змінити в Параметрах, а час — піти вперед.
    func refresh() async {
        permission = await authorization.permission()
        await reschedule()
    }

    /// Після перемикання в застосунку: показані сповіщення цього перемикача вже неактуальні.
    func didToggle(_ item: SwitchItem) async {
        repairIdentitiesIfNeeded()
        let switchID = item.uuid
        await scheduler.removeDelivered(forSwitch: switchID)
        await reschedule()
    }

    /// Відповідь на сповіщення: «Перемкнути» перемикає (див. `ReminderToggle`); натискання на саме
    /// сповіщення чи його закриття нічого не змінюють.
    func handleNotificationResponse(actionIdentifier: String, userInfo: [AnyHashable: Any]) async {
        guard actionIdentifier == ReminderNotifications.toggleActionID,
              let payload = ReminderPayload(userInfo: userInfo)
        else { return }
        repairIdentitiesIfNeeded()
        // Не вдалося зберегти — перемикання лишається в контексті й збережеться автозбереженням.
        try? ReminderToggle.perform(userInfo: userInfo, in: context, at: now())
        await scheduler.removeDelivered(forSwitch: payload.switchID)
        await reschedule()
    }

    /// Після видалення перемикача: прибирає вже показані його сповіщення й перепланує.
    func didDelete(switchID: UUID) async {
        await scheduler.removeDelivered(forSwitch: switchID)
        await reschedule()
    }

    /// При збереженні правила: системне вікно — лише якщо ще не питали.
    func requestPermissionIfNeeded() async {
        permission = await authorization.permission()
        guard permission == .notDetermined else { return }
        permission = await authorization.requestPermission()
    }

    /// Переплановує всі нагадування — після змін правил і видалення перемикача.
    func reschedule() async {
        repairIdentitiesIfNeeded()
        // Не вдалося прочитати сховище — старий план лишається: порожній список прибрав би всі нагадування.
        guard let items = try? context.fetch(FetchDescriptor<SwitchItem>()) else { return }
        // Запит, який центр не прийняв, наступне перепланування спробує додати знову.
        try? await scheduler.reschedule(items, now: now(), calendar: calendar())
    }

    private func timeDidChange() async {
        // Без скидання `Calendar.current` лишився б зі старим поясом (див. `CurrentDateModifier`).
        NSTimeZone.resetSystemTimeZone()
        await reschedule()
    }

    /// Після легкої міграції всі старі перемикачі мають однаковий UUID: найстаріший (за `createdAt`)
    /// його зберігає, решта отримують нові — до першого планування й до першої дії зі сповіщення.
    private func repairIdentitiesIfNeeded() {
        guard !hasRepairedIdentities else { return }
        // Не вдалося прочитати — спробуємо знову при наступному виклику.
        let descriptor = FetchDescriptor<SwitchItem>(sortBy: [SortDescriptor(\.createdAt)])
        guard let items = try? context.fetch(descriptor) else { return }
        let before = items.map(\.uuid)
        SwitchIdentity.repairDuplicates(in: items)
        hasRepairedIdentities = true
        // Не вдалося зберегти — нові UUID лишаються в контексті й збережуться автозбереженням.
        if items.map(\.uuid) != before {
            try? context.save()
        }
    }
}
