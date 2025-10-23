#!/bin/bash

# Быстрая переустановка с исправлениями
# Версия: 1.0.2

echo "🔧 Переустановка Extended Backup с исправлениями..."

# Удаление старой установки
echo "🗑️  Удаление старой установки..."
sudo rm -f /usr/local/bin/rw-backup-extended
sudo rm -f /opt/rw-backup-restore/backup-restore-extended.sh

# Пересоздание директории
sudo mkdir -p /opt/rw-backup-restore
sudo mkdir -p /opt/rw-backup-restore/logs
sudo mkdir -p /opt/rw-backup-restore/backups

# Скачивание нового файла
echo "📥 Скачивание исправленного скрипта..."
if curl -fsSL "https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/backup-restore-extended.sh" -o "/tmp/backup-restore-extended.sh"; then
    echo "✅ Скрипт скачан"
    
    # Проверка синтаксиса
    echo "🔍 Проверка синтаксиса..."
    if bash -n "/tmp/backup-restore-extended.sh"; then
        echo "✅ Синтаксис корректен"
        
        # Установка
        sudo mv "/tmp/backup-restore-extended.sh" "/opt/rw-backup-restore/backup-restore-extended.sh"
        sudo chmod +x "/opt/rw-backup-restore/backup-restore-extended.sh"
        sudo ln -sf "/opt/rw-backup-restore/backup-restore-extended.sh" "/usr/local/bin/rw-backup-extended"
        
        echo "✅ Установка завершена!"
        echo ""
        echo "🎯 Проверка:"
        if rw-backup-extended --version 2>/dev/null; then
            echo "✅ Команда --version работает"
        else
            echo "❌ Команда --version не работает"
        fi
        
        if rw-backup-extended --detect-services 2>/dev/null; then
            echo "✅ Команда --detect-services работает"
        else
            echo "❌ Команда --detect-services не работает"
        fi
        
    else
        echo "❌ Ошибки синтаксиса найдены!"
        rm -f "/tmp/backup-restore-extended.sh"
        exit 1
    fi
else
    echo "❌ Ошибка скачивания"
    exit 1
fi

echo ""
echo "🚀 Готово! Теперь можно тестировать:"
echo "   rw-backup-extended --help"
echo "   rw-backup-extended --detect-services"