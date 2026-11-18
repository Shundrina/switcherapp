# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Switcher

iOS-застосунок для перемикачів-нагадувань: користувач вмикає перемикач («полила квіти», «газ горить», «двері зачинені»), застосунок записує дату й час і зберігає історію.

## Стек

- Swift 6, SwiftUI, SwiftData (лише локальне зберігання), Swift Testing
- Заплановано: UserNotifications (локальні), WidgetKit + App Intents
- Без сторонніх залежностей
- Мінімальна версія iOS — 18.0; API з новіших версій лише через `if #available`
- Типова ізоляція акторів у застосунку — `MainActor`, увімкнено Approachable Concurrency (`SWIFT_APPROACHABLE_CONCURRENCY`): код без анотацій виконується на головному акторі, фонову роботу позначати явно (`nonisolated`, `@concurrent`)
- Лише iPhone (`TARGETED_DEVICE_FAMILY = 1`)

## Структура

- `Switcher/` — код застосунку
- `SwitcherTests/` — модульні тести; запускаються всередині застосунку (`TEST_HOST`), доступ до коду через `@testable import Switcher`
- `SwitcherUITests/` — екранні тести (XCUITest): запускають застосунок у симуляторі й натискають, свайпають, вводять текст. Код застосунку їм недоступний — лише те, що на екрані
- `scripts/` — службові shell-скрипти (не входять у Xcode-таргети)
- `.claude/agents/` — субагенти проєкту: `apple-api-researcher`, `test-author`, `implementer`, `reviewer`, `tester`, `market-analyst` (порядок роботи — у розділі «Робота з агентами»)
- `Switcher.xcodeproj` — теки синхронізуються з файловою системою, нові файли додавати до `.pbxproj` не треба

## Команди

```sh
# Збірка
xcodebuild build -project Switcher.xcodeproj -scheme Switcher \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

# Модульні тести (швидкі — після кожної зміни)
xcodebuild test -project Switcher.xcodeproj -scheme Switcher \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO \
  -collect-test-diagnostics never -only-testing:SwitcherTests

# Один модульний тест (Swift Testing: Таргет/Структура/функція() — з дужками)
xcodebuild test -project Switcher.xcodeproj -scheme Switcher \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO \
  -collect-test-diagnostics never -only-testing:'SwitcherTests/SwitcherTests/appModuleLoads()'

# Екранні тести (повільні — після змін в інтерфейсі й перед злиттям гілки) — на iPhone 17e, з екранною клавіатурою
xcodebuild test -project Switcher.xcodeproj -scheme Switcher \
  -destination 'platform=iOS Simulator,name=iPhone 17e' CODE_SIGNING_ALLOWED=NO \
  -collect-test-diagnostics never -only-testing:SwitcherUITests

# Один екранний тест (XCTest: Таргет/Клас/метод — без дужок)
xcodebuild test -project Switcher.xcodeproj -scheme Switcher \
  -destination 'platform=iOS Simulator,name=iPhone 17e' CODE_SIGNING_ALLOWED=NO \
  -collect-test-diagnostics never -only-testing:SwitcherUITests/AppLaunchUITests/testAppLaunches

# Екранні тести на iPhone користувачки (телефон розблокований, «Не турбувати» увімкнено, Параметри → Розробник → «Увімкнути автоматизацію UI»)
xcodebuild test -project Switcher.xcodeproj -scheme Switcher \
  -destination 'id=00008130-000C30920EB8001C' -allowProvisioningUpdates DEVELOPMENT_TEAM=ZGQ55HHNXQ \
  -collect-test-diagnostics never -only-testing:SwitcherUITests

# Перевірка конфігу permissions/sandbox і захисту секретів (після змін у .claude/settings.json або .gitignore)
bash scripts/sandbox-leak.test.sh
```

Якщо `xcode-select -p` вказує на CommandLineTools, перед командою треба задати `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Пісочниця Bash блокує служби симулятора (CoreSimulatorService), тому `xcodebuild test` і `xcrun simctl` треба запускати поза нею — інакше падіння з «Connection refused» / «Operation not permitted», і це не помилка в коді.

Без `-collect-test-diagnostics never` xcodebuild після падіння тесту ще близько 10 хвилин збирає діагностику симулятора і здається завислим.

Якщо екранні тести падають з «Failed to prepare device … for impending launch» ще до запуску застосунку — це збій стану симулятора: `xcrun simctl shutdown "iPhone 17e" && xcrun simctl boot "iPhone 17e"` і запустити знову.

Екранні тести мають бачити екранну клавіатуру, як на iPhone: вона закриває пів екрана, і тести з апаратною клавіатурою Mac цього не помічають. Тому вони йдуть на «iPhone 17e» (розміром близький до iPhone 15 Pro користувачки), де «Connect Hardware Keyboard» вимкнено для цього пристрою (`defaults write com.apple.iphonesimulator DevicePreferences -dict-add <UDID> '<dict><key>ConnectHardwareKeyboard</key><false/></dict>'`, UDID — з `xcrun simctl list devices`). «iPhone 17» лишається для ручної перевірки. У тестах натискати лише на видимі над клавіатурою місця й прокручувати жестом над клавіатурою (`scrollSwitchScreenUpAboveKeyboard()`); порожнє поле на пристрої має `value == nil` — перевіряти через `waitForEmptyValue`.

## Домовленості

- Тексти інтерфейсу — українською.
- Модель SwiftData тримати сумісною з CloudKit: усі поля зі значеннями за замовчуванням, без унікальних обмежень, зв'язки необов'язкові.
- `git push` — лише після підтвердження користувача.
- Модульні тести — на Swift Testing. Екранні тести — на XCTest (`XCTestCase`, методи `test…` з `@MainActor`), бо Swift Testing не керує екраном.
- Класи `@Model` не ізольовані на головному акторі, попри типову ізоляцію: допоміжні типи, які вони викликають, позначати `nonisolated`. Так само `nonisolated` має бути код, який SwiftUI викликає з фонового потоку (наприклад, динамічні кольори в `Theme.swift`) — інакше застосунок падає під час анімацій.

## Робота з агентами

Кожна задача (фіча чи баг) іде ланцюжком:

1. `apple-api-researcher` — лише якщо задача на незнайомому API Apple: з якої версії iOS, чи працює без платного акаунта.
2. `test-author` — пише тести, які зараз падають, і переконується, що падають з потрібної причини.
3. `implementer` — пише код, щоб тести пройшли, і проганяє всі тести. Тести послаблювати не можна; якщо тест здається хибним — зупиняється й питає.
4. `reviewer` — спершу звіряє зміни з вимогами задачі (зокрема, чи не послаблено тести), потім дивиться якість коду.

Знахідки `reviewer` виправляє `implementer`. `reviewer` можна запускати й окремо — для додаткової перевірки гілки.

Для задач з інтерфейсом `test-author` пише ще й екранні тести в `SwitcherUITests/` на сценарії з натисканнями, а `implementer` проганяє їх разом із модульними.

`tester` — перед злиттям гілки або після змін в інтерфейсі: проганяє екранні тести, запускає застосунок у симуляторі, робить знімки екрана й дивиться на те, що тести не ловлять (вигляд, тексти, темна тема).

`market-analyst` — поза ланцюжком, коли треба вирішити, що робити: вивчає конкурентів і схожі застосунки, порівнює функції й ціни, збирає теми з відгуків, шукає ніші. Код не змінює.

Агенти, які збирають проєкт паралельно, мають використовувати різні `-derivedDataPath`.
