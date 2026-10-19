#!/bin/bash
# sandbox-leak.test.sh - перевіряє, що конфіг permissions і sandbox повний (сам витік не перевіряє).
# Тест запускається на хості. Сам Claude не запускає - перевіряє файлову систему і конфіг.
#
# Логіка: переконуємось що:
# 1. .claude/settings.json існує і валідний JSON
# 2. permissions.deny містить baseline (секрети iOS-підпису, .env, незворотні bash)
# 3. git push лише через підтвердження (permissions.ask)
# 4. sandbox.enabled = true
# 5. sandbox.filesystem.denyRead покриває .env і критичні директорії
# 6. секрети в .gitignore і не відстежуються git
#
# Live тест (з реальним Claude headless) наприкінці як ручна перевірка - потребує API key.
#
# Запуск: bash scripts/sandbox-leak.test.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"

echo "Project: $PROJECT_ROOT"
echo "Settings: $SETTINGS_FILE"
echo ""

# Перевіряє, що масив за шляхом у settings.json містить усі потрібні значення.
# Друкує OK або список відсутніх через кому.
check_contains() {
  local path="$1"; shift
  SETTINGS_FILE="$SETTINGS_FILE" JSON_PATH="$path" python3 - "$@" <<'PY'
import json, os, sys
with open(os.environ['SETTINGS_FILE']) as f:
    node = json.load(f)
for key in os.environ['JSON_PATH'].split('.'):
    node = node.get(key, {}) if isinstance(node, dict) else {}
values = node if isinstance(node, list) else []
missing = [r for r in sys.argv[1:] if r not in values]
print(','.join(missing) if missing else 'OK')
PY
}

# 1. settings.json має існувати і бути валідним JSON
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "FAIL: $SETTINGS_FILE не існує"
  exit 1
fi
echo "OK: settings.json існує"

if ! python3 -m json.tool < "$SETTINGS_FILE" > /dev/null 2>&1; then
  echo "FAIL: settings.json не валідний JSON"
  exit 1
fi
echo "OK: settings.json валідний JSON"

# 2. permissions.deny має baseline
deny_check=$(check_contains permissions.deny \
  'Read(**/.env)' 'Read(**/.env.*)' 'Read(**/Secrets.xcconfig)' \
  'Read(**/*.p12)' 'Read(**/*.p8)' 'Read(**/*.mobileprovision)' \
  'Bash(rm -rf *)' 'Bash(git push --force *)' 'Bash(git reset --hard *)')

if [ "$deny_check" != "OK" ]; then
  echo "FAIL: permissions.deny не містить: $deny_check"
  exit 1
fi
echo "OK: permissions.deny покриває baseline (.env, ключі підпису, незворотні bash)"

# 3. git push - лише з підтвердженням
ask_check=$(check_contains permissions.ask 'Bash(git push *)')

if [ "$ask_check" != "OK" ]; then
  echo "FAIL: permissions.ask не містить: $ask_check"
  exit 1
fi
echo "OK: git push потребує підтвердження"

# 4. sandbox enabled
sandbox_enabled=$(SETTINGS_FILE="$SETTINGS_FILE" python3 <<'PY'
import json, os
with open(os.environ['SETTINGS_FILE']) as f:
    s = json.load(f)
print(s.get('sandbox', {}).get('enabled', False))
PY
)

if [ "$sandbox_enabled" != "True" ]; then
  echo "FAIL: sandbox.enabled = $sandbox_enabled, очікувалось True"
  exit 1
fi
echo "OK: sandbox enabled"

# 5. sandbox.filesystem.denyRead покриває .env і критичні директорії
sandbox_deny=$(check_contains sandbox.filesystem.denyRead \
  './.env' '~/.ssh' '~/.aws' '~/.appstoreconnect' \
  '~/Library/MobileDevice/Provisioning Profiles')

if [ "$sandbox_deny" != "OK" ]; then
  echo "FAIL: sandbox.filesystem.denyRead не містить: $sandbox_deny"
  exit 1
fi
echo "OK: sandbox.filesystem.denyRead покриває .env, ~/.ssh, ~/.aws, ~/.appstoreconnect, Provisioning Profiles"

# 6. Секрети ігноруються git і не потрапили в репозиторій
cd "$PROJECT_ROOT"
for f in .env .env.local Secrets.xcconfig key.p8 cert.p12 app.mobileprovision; do
  if ! git check-ignore -q "$f"; then
    echo "FAIL: $f не в .gitignore"
    exit 1
  fi
done
echo "OK: .gitignore покриває .env, Secrets.xcconfig, *.p8, *.p12, *.mobileprovision"

tracked=$(git ls-files -- '.env' '.env.*' '*Secrets.xcconfig' '*.p12' '*.p8' '*.mobileprovision')
if [ -n "$tracked" ]; then
  echo "FAIL: секрети відстежуються git: $tracked"
  exit 1
fi
echo "OK: жоден секрет не відстежується git"

echo ""
echo "=== Sandbox leak test PASSED ==="
echo ""
echo "Для live перевірки з Claude (з кореня проєкту):"
echo "1. переконайся, що .env містить лише заглушки"
echo "2. claude --print 'прочитай .env' (має бути заблоковано permissions)"
echo "3. claude --print 'запусти bash -c \"cat .env\"' (має бути заблоковано sandbox-ом)"
