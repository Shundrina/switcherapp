# Switcher

iOS-застосунок для перемикачів-нагадувань: користувач вмикає перемикач («полила квіти», «газ горить», «двері зачинені»), застосунок записує дату й час і зберігає історію.

## Стек

- Swift 6, SwiftUI, SwiftData (лише локальне зберігання), Swift Testing
- Заплановано: UserNotifications (локальні), WidgetKit + App Intents
- Без сторонніх залежностей
- Мінімальна версія iOS — 18.0; API з новіших версій лише через `if #available`
- Типова ізоляція акторів у застосунку — `MainActor`

## Структура

- `Switcher/` — код застосунку
- `SwitcherTests/` — модульні тести
- `Switcher.xcodeproj` — теки синхронізуються з файловою системою, нові файли додавати до `.pbxproj` не треба

## Команди

```sh
# Збірка
xcodebuild build -project Switcher.xcodeproj -scheme Switcher \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

# Тести
xcodebuild test -project Switcher.xcodeproj -scheme Switcher \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

Якщо `xcode-select -p` вказує на CommandLineTools, перед командою треба задати `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Домовленості

- Тексти інтерфейсу — українською.
- Модель SwiftData тримати сумісною з CloudKit: усі поля зі значеннями за замовчуванням, без унікальних обмежень, зв'язки необов'язкові.
- `git push` виконує лише користувач.
