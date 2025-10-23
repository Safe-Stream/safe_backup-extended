#!/bin/bash

# Remnawave Full Server Backup & Restore - Installer
# Extended version for complete server migration

set -e

# Colors
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
CYAN=$'\e[36m'
RESET=$'\e[0m'
BOLD=$'\e[1m'

# Configuration
# По умолчанию используем локальный файл, если URL не указан
DEFAULT_SCRIPT_URL="https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/backup-restore-extended.sh"
SCRIPT_URL="${REMOTE_SCRIPT_URL:-$DEFAULT_SCRIPT_URL}"
INSTALL_DIR="/opt/rw-backup-restore"
SCRIPT_NAME="backup-restore-extended.sh"
LOCAL_SCRIPT_PATH="$(dirname "$0")/backup-restore-extended.sh"

print_message() {
    local type="$1"
    local message="$2"
    local color_code="$RESET"

    case "$type" in
        "INFO") color_code="$CYAN" ;;
        "SUCCESS") color_code="$GREEN" ;;
        "WARN") color_code="$YELLOW" ;;
        "ERROR") color_code="$RED" ;;
    esac

    echo -e "${color_code}[$type]${RESET} $message"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message "ERROR" "Этот скрипт должен быть запущен с правами root (sudo)"
        print_message "INFO" "Попробуйте: ${BOLD}sudo $0${RESET}"
        exit 1
    fi
}

check_dependencies() {
    print_message "INFO" "Проверка зависимостей..."
    
    local missing_deps=()
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        print_message "WARN" "Docker не установлен. Будет установлен автоматически при необходимости."
    fi
    
    # Check jq (for Google Drive support)
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    # Install missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_message "INFO" "Установка недостающих зависимостей: ${missing_deps[*]}"
        
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y "${missing_deps[@]}"
        elif command -v yum &> /dev/null; then
            yum install -y "${missing_deps[@]}"
        elif command -v dnf &> /dev/null; then
            dnf install -y "${missing_deps[@]}"
        else
            print_message "ERROR" "Не удалось определить менеджер пакетов"
            print_message "INFO" "Установите вручную: ${missing_deps[*]}"
            exit 1
        fi
    fi
    
    print_message "SUCCESS" "Все зависимости установлены"
}

download_script() {
    print_message "INFO" "Установка расширенного скрипта бэкапа..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Try to use local script first
    if [[ -f "$LOCAL_SCRIPT_PATH" ]]; then
        print_message "INFO" "Использование локального файла скрипта..."
        if cp "$LOCAL_SCRIPT_PATH" "$INSTALL_DIR/$SCRIPT_NAME"; then
            chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
            print_message "SUCCESS" "Скрипт установлен из локального файла: $INSTALL_DIR/$SCRIPT_NAME"
            return 0
        else
            print_message "WARN" "Не удалось скопировать локальный файл, пробуем загрузить..."
        fi
    fi
    
    # Download script from remote URL
    print_message "INFO" "Загрузка скрипта с удаленного сервера..."
    print_message "INFO" "URL: $SCRIPT_URL"
    
    if curl -fsSL "$SCRIPT_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
        chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
        print_message "SUCCESS" "Скрипт загружен: $INSTALL_DIR/$SCRIPT_NAME"
    else
        print_message "ERROR" "Не удалось загрузить скрипт"
        print_message "INFO" "Проверьте:"
        print_message "INFO" "  1. Интернет соединение"
        print_message "INFO" "  2. Корректность URL: $SCRIPT_URL"
        print_message "INFO" "  3. Доступность файла по указанному адресу"
        echo ""
        print_message "INFO" "Альтернативные способы установки:"
        print_message "INFO" "  1. Скачайте backup-restore-extended.sh вручную и поместите рядом с install.sh"
        print_message "INFO" "  2. Установите переменную REMOTE_SCRIPT_URL с корректным адресом:"
        print_message "INFO" "     export REMOTE_SCRIPT_URL=\"https://your-server.com/backup-restore-extended.sh\""
        print_message "INFO" "     sudo -E ./install.sh"
        exit 1
    fi
}

check_existing_installation() {
    print_message "INFO" "Проверка существующих установок..."
    
    # Check for original backup script
    local original_script="/opt/rw-backup-restore/backup-restore.sh"
    local original_symlink="/usr/local/bin/rw-backup"
    
    if [[ -f "$original_script" ]]; then
        print_message "WARN" "Обнаружен оригинальный скрипт бэкапа Remnawave"
        echo ""
        print_message "INFO" "Варианты действий:"
        echo " 1. Установить рядом с оригинальным (рекомендуется)"
        echo " 2. Создать резервную копию оригинального и заменить"
        echo " 3. Отменить установку"
        echo ""
        
        local choice
        read -rp "${GREEN}[?]${RESET} Выберите вариант (1-3): " choice
        echo ""
        
        case $choice in
            1)
                print_message "SUCCESS" "Установка рядом с оригинальным скриптом"
                print_message "INFO" "Оригинальный: ${CYAN}rw-backup${RESET}"
                print_message "INFO" "Расширенный: ${CYAN}rw-backup-extended${RESET}"
                return 0
                ;;
            2)
                backup_original_installation
                return 0
                ;;
            3)
                print_message "INFO" "Установка отменена пользователем"
                exit 0
                ;;
            *)
                print_message "ERROR" "Неверный выбор, отменяем установку"
                exit 1
                ;;
        esac
    fi
    
    return 0
}

backup_original_installation() {
    local backup_dir="/opt/rw-backup-restore-original-$(date +%Y%m%d-%H%M%S)"
    
    print_message "INFO" "Создание резервной копии оригинального скрипта..."
    
    if cp -r "/opt/rw-backup-restore" "$backup_dir"; then
        print_message "SUCCESS" "Резервная копия создана: $backup_dir"
        
        # Remove original symlink
        if [[ -L "/usr/local/bin/rw-backup" ]]; then
            rm -f "/usr/local/bin/rw-backup"
            print_message "INFO" "Удалена ссылка оригинального скрипта"
        fi
        
        # Clear original directory but preserve backups
        local backup_files_dir="/opt/rw-backup-restore/backup"
        if [[ -d "$backup_files_dir" ]]; then
            print_message "INFO" "Сохранение существующих бэкапов..."
            mkdir -p "/tmp/rw-backup-preserve"
            cp -r "$backup_files_dir"/* "/tmp/rw-backup-preserve/" 2>/dev/null || true
        fi
        
        rm -rf "/opt/rw-backup-restore"
        print_message "SUCCESS" "Оригинальный скрипт сохранен и удален из системы"
    else
        print_message "ERROR" "Не удалось создать резервную копию"
        exit 1
    fi
}

restore_preserved_backups() {
    if [[ -d "/tmp/rw-backup-preserve" ]]; then
        print_message "INFO" "Восстановление существующих бэкапов..."
        mkdir -p "$INSTALL_DIR/backup"
        cp -r /tmp/rw-backup-preserve/* "$INSTALL_DIR/backup/" 2>/dev/null || true
        rm -rf "/tmp/rw-backup-preserve"
        print_message "SUCCESS" "Существующие бэкапы восстановлены"
    fi
}

install_script() {
    print_message "INFO" "Установка скрипта..."
    
    # Check for existing installations
    check_existing_installation
    
    # Run the script to complete installation
    if "$INSTALL_DIR/$SCRIPT_NAME"; then
        # Restore any preserved backups
        restore_preserved_backups
        
        print_message "SUCCESS" "Установка завершена успешно!"
    else
        print_message "ERROR" "Ошибка при установке скрипта"
        exit 1
    fi
}

show_usage_info() {
    echo ""
    print_message "SUCCESS" "🚀 Remnawave Full Server Backup & Restore установлен!"
    echo ""
    echo "📋 ${BOLD}Доступные команды:${RESET}"
    echo "   ${GREEN}rw-backup-extended${RESET}              - Интерактивное меню"
    echo "   ${GREEN}rw-backup-extended --backup${RESET}     - Стандартный бэкап"
    echo "   ${GREEN}rw-backup-extended --backup full${RESET} - Полный бэкап сервера"
    echo "   ${GREEN}rw-backup-extended --restore${RESET}    - Стандартное восстановление"
    echo "   ${GREEN}rw-backup-extended --restore full${RESET} - Полное восстановление"
    echo "   ${GREEN}rw-backup-extended --detect${RESET}     - Обнаружение сервисов"
    echo ""
    echo "📁 ${BOLD}Расположение файлов:${RESET}"
    echo "   Скрипт: ${CYAN}$INSTALL_DIR/$SCRIPT_NAME${RESET}"
    echo "   Конфигурация: ${CYAN}$INSTALL_DIR/config.env${RESET}"
    echo "   Бэкапы: ${CYAN}$INSTALL_DIR/backup/${RESET}"
    echo ""
    echo "🔧 ${BOLD}Первые шаги:${RESET}"
    echo "   1. Запустите: ${GREEN}rw-backup-extended${RESET}"
    echo "   2. Настройте Telegram уведомления"
    echo "   3. Проверьте автоопределение сервисов"
    echo "   4. Создайте первый бэкап"
    echo ""
    echo "📖 ${BOLD}Документация:${RESET}"
    echo "   Полное руководство: ${CYAN}$INSTALL_DIR/MIGRATION_GUIDE.md${RESET}"
    echo ""
    print_message "INFO" "Готов к использованию! Запустите ${BOLD}${GREEN}rw-backup-extended${RESET} для начала работы."
}

main() {
    clear
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║          Remnawave Full Server Backup & Restore             ║${RESET}"
    echo -e "${GREEN}${BOLD}║                    Installer v3.0.0                         ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    print_message "INFO" "Установка расширенного скрипта полного бэкапа сервера..."
    echo ""
    
    # Check if we're running as root
    check_root
    
    # Check and install dependencies  
    check_dependencies
    
    # Download the main script
    download_script
    
    # Install and configure
    install_script
    
    # Show usage information
    show_usage_info
}

# Handle arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Установщик Remnawave Full Server Backup & Restore"
        echo ""
        echo "Использование: $0 [--help]"
        echo ""
        echo "Этот скрипт установит расширенную версию системы бэкапа,"
        echo "которая поддерживает полную миграцию сервера Remnawave"
        echo "со всеми дополнительными сервисами."
        echo ""
        echo "Поддерживаемые сервисы:"
        echo "  - remnawave (основная панель)"
        echo "  - remnawave-db (PostgreSQL)"
        echo "  - remnawave-redis (Redis/Valkey)"
        echo "  - remnawave-nginx (веб-сервер)"
        echo "  - remnawave-subscription-page (страница подписки)"
        echo "  - remnawave-telegram-mini-app (Telegram мини-приложение)"
        echo "  - remnawave-tg-shop (Telegram бот)"
        echo "  - remnawave-tg-shop-db (БД Telegram бота)"
        echo ""
        echo ""
        echo "Способы установки:"
        echo ""
        echo "1. Локальная установка (если backup-restore-extended.sh находится рядом):"
        echo "   sudo $0"
        echo ""
        echo "2. Установка с пользовательского URL:"
        echo "   export REMOTE_SCRIPT_URL=\"https://your-server.com/backup-restore-extended.sh\""
        echo "   sudo -E $0"
        echo ""
        echo "3. Прямая загрузка из GitHub:"
        echo "   curl -o install.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/install.sh"
        echo "   chmod +x install.sh"  
        echo "   sudo ./install.sh"
        exit 0
        ;;
    "")
        # No arguments - proceed with installation
        main
        ;;
    *)
        print_message "ERROR" "Неизвестная опция: $1"
        print_message "INFO" "Используйте --help для справки"
        exit 1
        ;;
esac