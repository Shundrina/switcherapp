import Testing
@testable import Switcher

/// Тестовий режим застосунку з аргументів запуску (`ProcessInfo.processInfo.arguments`):
/// `-UITesting` — сховище лише в пам'яті й онбординг пропущено;
/// `-UITesting -UITestingShowOnboarding` — сховище в пам'яті й онбординг показано.
/// Перший аргумент процесу — шлях до виконуваного файлу.
@MainActor
struct LaunchOptionsTests {
    private let executable = "/private/var/containers/Bundle/Application/X/Switcher.app/Switcher"

    // Звичайний запуск: сховище на диску, онбординг — за збереженим прапорцем.
    @Test func withoutArgumentsUsesDiskStoreAndStoredOnboardingFlag() {
        let options = LaunchOptions(arguments: [executable])

        #expect(options.isStoredInMemoryOnly == false)
        #expect(options.onboarding == .stored)
    }

    @Test func emptyArgumentsAreANormalLaunch() {
        let options = LaunchOptions(arguments: [])

        #expect(options.isStoredInMemoryOnly == false)
        #expect(options.onboarding == .stored)
    }

    @Test func uiTestingUsesMemoryStoreAndSkipsOnboarding() {
        let options = LaunchOptions(arguments: [executable, "-UITesting"])

        #expect(options.isStoredInMemoryOnly == true)
        #expect(options.onboarding == .skipped)
    }

    @Test func uiTestingWithShowOnboardingUsesMemoryStoreAndShowsOnboarding() {
        let options = LaunchOptions(arguments: [executable, "-UITesting", "-UITestingShowOnboarding"])

        #expect(options.isStoredInMemoryOnly == true)
        #expect(options.onboarding == .shown)
    }

    @Test func argumentOrderDoesNotMatter() {
        let options = LaunchOptions(arguments: [executable, "-UITestingShowOnboarding", "-UITesting"])

        #expect(options.isStoredInMemoryOnly == true)
        #expect(options.onboarding == .shown)
    }

    // Xcode і система додають свої аргументи («-ключ значення») — вони на режим не впливають.
    @Test func unrelatedArgumentsAreIgnored() {
        let normal = LaunchOptions(arguments: [executable, "-AppleLanguages", "(uk)", "-NSDoubleLocalizedStrings", "YES"])
        #expect(normal.isStoredInMemoryOnly == false)
        #expect(normal.onboarding == .stored)

        let testing = LaunchOptions(arguments: [executable, "-AppleLanguages", "(uk)", "-UITesting"])
        #expect(testing.isStoredInMemoryOnly == true)
        #expect(testing.onboarding == .skipped)
    }

    // Захисний: прапорець показу онбордингу сам по собі тестовий режим не вмикає —
    // без `-UITesting` це звичайний запуск зі сховищем на диску.
    @Test func showOnboardingWithoutUITestingIsANormalLaunch() {
        let options = LaunchOptions(arguments: [executable, "-UITestingShowOnboarding"])

        #expect(options.isStoredInMemoryOnly == false)
        #expect(options.onboarding == .stored)
    }

    // Аргумент має збігатися повністю: схожі рядки — не тестовий режим.
    @Test func onlyExactArgumentEnablesTestingMode() {
        for argument in ["UITesting", "-UITestingFoo"] {
            let options = LaunchOptions(arguments: [executable, argument])
            #expect(options.isStoredInMemoryOnly == false, "аргумент \(argument)")
            #expect(options.onboarding == .stored, "аргумент \(argument)")
        }
    }
}

/// Вибір першого екрана (`RootView`): список чи онбординг, і чи записувати прапорець `hasSeenOnboarding`.
/// `hasSeenOnboarding` — збережений прапорець (UserDefaults); `finishedThisLaunch` — онбординг
/// завершено в поточному запуску (стан лише на цей запуск, не зберігається).
@MainActor
struct OnboardingScreenTests {
    // MARK: .stored — звичайний запуск, поведінка як до появи тестового режиму

    // Список показано, якщо онбординг уже бачили (прапорець) або щойно завершили в цьому запуску;
    // онбординг — лише коли обидва false.
    @Test(arguments: [false, true], [false, true])
    func storedShowsListWhenSeenOrFinished(hasSeenOnboarding: Bool, finishedThisLaunch: Bool) {
        let showsList = LaunchOptions.Onboarding.stored.showsList(
            hasSeenOnboarding: hasSeenOnboarding,
            finishedThisLaunch: finishedThisLaunch
        )

        #expect(showsList == (hasSeenOnboarding || finishedThisLaunch))
    }

    @Test func storedFirstLaunchShowsOnboarding() {
        #expect(LaunchOptions.Onboarding.stored.showsList(hasSeenOnboarding: false, finishedThisLaunch: false) == false)
    }

    @Test func storedAfterOnboardingWasSeenShowsListImmediately() {
        #expect(LaunchOptions.Onboarding.stored.showsList(hasSeenOnboarding: true, finishedThisLaunch: false) == true)
    }

    @Test func storedPersistsCompletion() {
        #expect(LaunchOptions.Onboarding.stored.persistsCompletion == true)
    }

    // Сценарій звичайного першого запуску: онбординг → завершення записує прапорець →
    // список; наступний запуск (стан запуску скинуто) — одразу список.
    @Test func storedFirstLaunchFlowRemembersCompletionAcrossLaunches() {
        let mode = LaunchOptions.Onboarding.stored
        var hasSeenOnboarding = false

        #expect(mode.showsList(hasSeenOnboarding: hasSeenOnboarding, finishedThisLaunch: false) == false)

        // Користувач завершив онбординг.
        if mode.persistsCompletion { hasSeenOnboarding = true }
        #expect(mode.showsList(hasSeenOnboarding: hasSeenOnboarding, finishedThisLaunch: true) == true)

        // Наступний запуск.
        #expect(mode.showsList(hasSeenOnboarding: hasSeenOnboarding, finishedThisLaunch: false) == true)
    }

    // MARK: .skipped — `-UITesting`: одразу список, прапорець ні на що не впливає

    @Test(arguments: [false, true], [false, true])
    func skippedAlwaysShowsList(hasSeenOnboarding: Bool, finishedThisLaunch: Bool) {
        let showsList = LaunchOptions.Onboarding.skipped.showsList(
            hasSeenOnboarding: hasSeenOnboarding,
            finishedThisLaunch: finishedThisLaunch
        )

        #expect(showsList == true)
    }

    @Test func skippedDoesNotPersistCompletion() {
        #expect(LaunchOptions.Onboarding.skipped.persistsCompletion == false)
    }

    // MARK: .shown — `-UITesting -UITestingShowOnboarding`: онбординг незалежно від прапорця

    @Test(arguments: [false, true], [false, true])
    func shownShowsListOnlyAfterFinishingThisLaunch(hasSeenOnboarding: Bool, finishedThisLaunch: Bool) {
        let showsList = LaunchOptions.Onboarding.shown.showsList(
            hasSeenOnboarding: hasSeenOnboarding,
            finishedThisLaunch: finishedThisLaunch
        )

        #expect(showsList == finishedThisLaunch)
    }

    // Навіть якщо на пристрої онбординг уже бачили, тестовий режим його показує.
    @Test func shownIgnoresStoredFlag() {
        #expect(LaunchOptions.Onboarding.shown.showsList(hasSeenOnboarding: true, finishedThisLaunch: false) == false)
    }

    @Test func shownDoesNotPersistCompletion() {
        #expect(LaunchOptions.Onboarding.shown.persistsCompletion == false)
    }

    // Сценарій: прапорець не записано, тож наступний запуск у цьому режимі знову показує онбординг.
    @Test func shownFlowDoesNotRememberCompletionAcrossLaunches() {
        let mode = LaunchOptions.Onboarding.shown
        var hasSeenOnboarding = false

        #expect(mode.showsList(hasSeenOnboarding: hasSeenOnboarding, finishedThisLaunch: false) == false)

        // Користувач завершив онбординг.
        if mode.persistsCompletion { hasSeenOnboarding = true }
        #expect(mode.showsList(hasSeenOnboarding: hasSeenOnboarding, finishedThisLaunch: true) == true)
        #expect(hasSeenOnboarding == false)

        // Наступний запуск.
        #expect(mode.showsList(hasSeenOnboarding: hasSeenOnboarding, finishedThisLaunch: false) == false)
    }

    // MARK: Зв'язок з аргументами запуску

    // Звичайний запуск, у тому числі з одним лише `-UITestingShowOnboarding`, записує прапорець;
    // тестові режими — ні.
    @Test func onlyNormalLaunchPersistsCompletion() {
        let executable = "/private/var/containers/Bundle/Application/X/Switcher.app/Switcher"
        let cases: [([String], Bool)] = [
            ([executable], true),
            ([executable, "-UITestingShowOnboarding"], true),
            ([executable, "-UITesting"], false),
            ([executable, "-UITesting", "-UITestingShowOnboarding"], false),
        ]
        for (arguments, persists) in cases {
            let options = LaunchOptions(arguments: arguments)
            #expect(options.onboarding.persistsCompletion == persists, "аргументи \(arguments.dropFirst())")
        }
    }
}

/// Картка-зразок «Вигляд у списку» на екрані додавання (`LaunchOptions.addPreview`).
/// Звичайний запуск — картка сама вмикається й вимикається (крім Reduce Motion), як і раніше.
/// Тестовий режим (`-UITesting`) — картка не перемикається сама й стоїть увімкненою: це найгірший
/// для натискань стан (кольорове тло розтікається колом), тож екранні тести ловлять натискання,
/// які перехоплює картка, детерміновано, а не через раз.
@MainActor
struct AddPreviewLaunchModeTests {
    private let executable = "/private/var/containers/Bundle/Application/X/Switcher.app/Switcher"

    // MARK: Зв'язок з аргументами запуску

    @Test func normalLaunchAutoTogglesAddPreview() {
        #expect(LaunchOptions(arguments: [executable]).addPreview == .autoToggling)
    }

    @Test func emptyArgumentsAutoToggleAddPreview() {
        #expect(LaunchOptions(arguments: []).addPreview == .autoToggling)
    }

    @Test func uiTestingKeepsAddPreviewOn() {
        #expect(LaunchOptions(arguments: [executable, "-UITesting"]).addPreview == .alwaysOn)
    }

    @Test func uiTestingWithShowOnboardingKeepsAddPreviewOn() {
        #expect(LaunchOptions(arguments: [executable, "-UITesting", "-UITestingShowOnboarding"]).addPreview == .alwaysOn)
        #expect(LaunchOptions(arguments: [executable, "-UITestingShowOnboarding", "-UITesting"]).addPreview == .alwaysOn)
    }

    // Аргументи Xcode і системи на режим картки не впливають.
    @Test func unrelatedArgumentsAreIgnored() {
        let normal = LaunchOptions(arguments: [executable, "-AppleLanguages", "(uk)", "-NSDoubleLocalizedStrings", "YES"])
        #expect(normal.addPreview == .autoToggling)

        let testing = LaunchOptions(arguments: [executable, "-AppleLanguages", "(uk)", "-UITesting"])
        #expect(testing.addPreview == .alwaysOn)
    }

    // Без `-UITesting` — звичайний запуск, навіть із прапорцем онбордингу чи схожими рядками.
    @Test(arguments: ["-UITestingShowOnboarding", "UITesting", "-UITestingFoo"])
    func withoutExactUITestingArgumentAddPreviewAutoToggles(argument: String) {
        #expect(LaunchOptions(arguments: [executable, argument]).addPreview == .autoToggling)
    }

    // MARK: Поведінка картки

    // Звичайний запуск: як і раніше, картка відкривається вимкненою й далі перемикається сама.
    @Test func autoTogglingStartsOffAndTogglesItself() {
        let mode = LaunchOptions.AddPreview.autoToggling

        #expect(mode.startsOn == false)
        #expect(mode.togglesItself(reduceMotion: false) == true)
    }

    // З Reduce Motion картка сама не перемикається.
    @Test func autoTogglingRespectsReduceMotion() {
        #expect(LaunchOptions.AddPreview.autoToggling.togglesItself(reduceMotion: true) == false)
    }

    // Тестовий режим: картка увімкнена з самого відкриття екрана й не вимикається — незалежно від Reduce Motion.
    @Test(arguments: [false, true])
    func alwaysOnStartsOnAndNeverToggles(reduceMotion: Bool) {
        let mode = LaunchOptions.AddPreview.alwaysOn

        #expect(mode.startsOn == true)
        #expect(mode.togglesItself(reduceMotion: reduceMotion) == false)
    }
}

/// Сповіщення в тестовому режимі (`LaunchOptions.notifications`). Звичайний запуск — справжній центр
/// сповіщень і системний дозвіл. `-UITesting` — центр у пам'яті й дозвіл без системного вікна:
/// за замовчуванням дозволено, `-UITestingNotificationsDenied` — відмовлено,
/// `-UITestingNotificationsAllowed` — дозволено явно. Без `-UITesting` ці аргументи нічого не змінюють.
@MainActor
struct LaunchOptionsNotificationsTests {
    private let executable = "/private/var/containers/Bundle/Application/X/Switcher.app/Switcher"

    @Test func argumentNames() {
        #expect(LaunchOptions.notificationsDeniedArgument == "-UITestingNotificationsDenied")
        #expect(LaunchOptions.notificationsAllowedArgument == "-UITestingNotificationsAllowed")
    }

    @Test func normalLaunchUsesSystemNotifications() {
        #expect(LaunchOptions(arguments: [executable]).notifications == .system)
        #expect(LaunchOptions(arguments: []).notifications == .system)
    }

    @Test func uiTestingUsesInMemoryCenterAllowedByDefault() {
        #expect(LaunchOptions(arguments: [executable, "-UITesting"]).notifications == .inMemory(permission: .allowed))
    }

    @Test func uiTestingWithDeniedArgument() {
        let options = LaunchOptions(arguments: [executable, "-UITestingNotificationsDenied", "-UITesting"])

        #expect(options.notifications == .inMemory(permission: .denied))
    }

    @Test func uiTestingWithAllowedArgument() {
        let options = LaunchOptions(arguments: [executable, "-UITesting", "-UITestingNotificationsAllowed"])

        #expect(options.notifications == .inMemory(permission: .allowed))
    }

    // Захисний: без `-UITesting` дозвіл з аргументу не підміняє системний.
    @Test(arguments: ["-UITestingNotificationsDenied", "-UITestingNotificationsAllowed"])
    func notificationArgumentsWithoutUITestingAreIgnored(argument: String) {
        let options = LaunchOptions(arguments: [executable, argument])

        #expect(options.notifications == .system)
        #expect(options.isStoredInMemoryOnly == false)
    }

    // Режим сповіщень не змінює решти тестового режиму.
    @Test func deniedArgumentKeepsOtherTestingModes() {
        let options = LaunchOptions(arguments: [executable, "-UITesting", "-UITestingNotificationsDenied"])

        #expect(options.isStoredInMemoryOnly == true)
        #expect(options.onboarding == .skipped)
    }
}
