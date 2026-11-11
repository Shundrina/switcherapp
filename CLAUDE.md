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
- `scripts/` — службові shell-скрипти (не входять у Xcode-таргети)
- `.claude/agents/` — субагенти проєкту: `feature-developer`, `tester`, `code-reviewer`, `apple-api-researcher`
- `Switcher.xcodeproj` — теки синхронізуються з файловою системою, нові файли додавати до `.pbxproj` не треба

## Команди

```sh
# Збірка
xcodebuild build -project Switcher.xcodeproj -scheme Switcher \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

# Тести
xcodebuild test -project Switcher.xcodeproj -scheme Switcher \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

# Один тест (Swift Testing: Таргет/Структура/функція() — з дужками)
xcodebuild test -project Switcher.xcodeproj -scheme Switcher \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO \
  -only-testing:'SwitcherTests/SwitcherTests/appModuleLoads()'

# Перевірка конфігу permissions/sandbox і захисту секретів (після змін у .claude/settings.json або .gitignore)
bash scripts/sandbox-leak.test.sh
```

Якщо `xcode-select -p` вказує на CommandLineTools, перед командою треба задати `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Пісочниця Bash блокує служби симулятора (CoreSimulatorService), тому `xcodebuild test` і `xcrun simctl` треба запускати поза нею — інакше падіння з «Connection refused» / «Operation not permitted», і це не помилка в коді.

## Домовленості

- Тексти інтерфейсу — українською.
- Модель SwiftData тримати сумісною з CloudKit: усі поля зі значеннями за замовчуванням, без унікальних обмежень, зв'язки необов'язкові.
- `git push` — лише після підтвердження користувача.
- Класи `@Model` не ізольовані на головному акторі, попри типову ізоляцію: допоміжні типи, які вони викликають, позначати `nonisolated`. Так само `nonisolated` має бути код, який SwiftUI викликає з фонового потоку (наприклад, динамічні кольори в `Theme.swift`) — інакше застосунок падає під час анімацій.
