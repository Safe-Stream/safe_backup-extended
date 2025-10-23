#!/bin/bash

# Простой тест синтаксиса скрипта
# Версия: 1.0.0

echo "🔍 Проверка синтаксиса скрипта backup-restore-extended.sh..."

SCRIPT_PATH="backup-restore-extended.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Файл $SCRIPT_PATH не найден"
    exit 1
fi

# Проверка синтаксиса bash
echo "📋 Проверка синтаксиса bash..."
if bash -n "$SCRIPT_PATH"; then
    echo "✅ Синтаксис bash корректен"
else
    echo "❌ Ошибки синтаксиса bash обнаружены"
    exit 1
fi

# Проверка на потенциальные проблемы
echo "🔎 Проверка на потенциальные проблемы..."

# Проверка на незакрытые кавычки
if grep -n "echo.*\$(if\s" "$SCRIPT_PATH"; then
    echo "⚠️  Обнаружены потенциально проблемные конструкции with echo \$(if"
fi

# Проверка на правильное использование [[ ]]
if grep -n "if \[.*\].*;" "$SCRIPT_PATH" | grep -v "\[\[.*\]\]"; then
    echo "⚠️  Обнаружены конструкции с одиночными скобками [ ] вместо [[ ]]"
fi

echo ""
echo "✅ Проверка завершена!"
echo ""
echo "📋 Для тестирования на сервере:"
echo "   1. Загрузите исправленный файл на GitHub"  
echo "   2. Запустите установку: curl -o install.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/install.sh"
echo "   3. Выполните: chmod +x install.sh && sudo ./install.sh"