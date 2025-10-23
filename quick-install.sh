#!/bin/bash

# Быстрый установщик Extended Backup для Remnawave
# Версия: 1.0.0
# Дата: 23 октября 2025

echo "🚀 Установка Extended Backup для Remnawave..."
echo "============================================="

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Этот скрипт должен запускаться с правами root"
    echo "   Используйте: sudo $0"
    exit 1
fi

# Создание директории для скриптов
SCRIPT_DIR="/opt/remnawave-backup"
mkdir -p "$SCRIPT_DIR"

# URL репозитория (будет обновлен когда репозиторий заработает)
REPO_URL="https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main"

echo "📁 Создание директории: $SCRIPT_DIR"

# Функция загрузки файла
download_file() {
    local file="$1"
    local url="$REPO_URL/$file"
    
    echo "📥 Загрузка $file..."
    
    # Попытка загрузки с GitHub
    if curl -fsSL "$url" -o "$SCRIPT_DIR/$file" 2>/dev/null; then
        echo "✅ $file загружен с GitHub"
        return 0
    fi
    
    # Если GitHub недоступен, создаем заглушку
    echo "⚠️  GitHub недоступен, создаем локальную версию $file"
    case "$file" in
        "backup-restore-extended.sh")
            cat > "$SCRIPT_DIR/$file" << 'EOF'
#!/bin/bash
echo "🔧 Extended Backup для Remnawave"
echo "Пожалуйста, загрузите актуальную версию с GitHub:"
echo "https://github.com/Safe-Stream/safe_backup-extended"
echo ""
echo "Или используйте команду:"
echo "curl -o backup-restore-extended.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/backup-restore-extended.sh"
EOF
            ;;
        "README.md")
            cat > "$SCRIPT_DIR/$file" << 'EOF'
# Extended Backup для Remnawave

Пожалуйста, посетите официальный репозиторий:
https://github.com/Safe-Stream/safe-backup-extended

Для получения актуальной версии и документации.
EOF
            ;;
    esac
    chmod +x "$SCRIPT_DIR/$file" 2>/dev/null
}

# Загрузка основных файлов
download_file "backup-restore-extended.sh"
download_file "README.md"

# Создание симлинка для удобства
echo "🔗 Создание симлинка..."
ln -sf "$SCRIPT_DIR/backup-restore-extended.sh" /usr/local/bin/rw-backup-extended
chmod +x "$SCRIPT_DIR/backup-restore-extended.sh"

echo ""
echo "✅ Установка завершена!"
echo ""
echo "📋 Доступные команды:"
echo "   rw-backup-extended          - Запуск extended backup"
echo "   $SCRIPT_DIR/backup-restore-extended.sh  - Полный путь"
echo ""
echo "📚 Документация:"
echo "   https://github.com/Safe-Stream/safe_backup-extended"
echo ""
echo "🔄 Обновление:"
echo "   curl -fsSL https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/quick-install.sh | sudo bash"
echo ""

# Проверка установки
if [ -f "/usr/local/bin/rw-backup-extended" ]; then
    echo "🎯 Установка успешна! Используйте: rw-backup-extended"
else
    echo "❌ Проблема с установкой. Проверьте права доступа."
fi