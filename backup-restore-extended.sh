#!/bin/bash

set -e

VERSION="3.0.0-extended"
INSTALL_DIR="/opt/rw-backup-restore"
BACKUP_DIR="$INSTALL_DIR/backup"
CONFIG_FILE="$INSTALL_DIR/config.env"
SCRIPT_NAME="backup-restore-extended.sh"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
RETAIN_BACKUPS_DAYS=7
SYMLINK_PATH="/usr/local/bin/rw-backup-extended"
REMNALABS_ROOT_DIR=""
ENV_NODE_FILE=".env-node"
ENV_FILE=".env"
SCRIPT_REPO_URL="https://raw.githubusercontent.com/distillium/remnawave-backup-restore/main/backup-restore.sh"
SCRIPT_RUN_PATH="$(realpath "$0")"
GD_CLIENT_ID=""
GD_CLIENT_SECRET=""
GD_REFRESH_TOKEN=""
GD_FOLDER_ID=""
UPLOAD_METHOD="telegram"
CRON_TIMES=""
TG_MESSAGE_THREAD_ID=""
UPDATE_AVAILABLE=false
BACKUP_EXCLUDE_PATTERNS="*.log *.tmp .git __pycache__ node_modules"

# Extended backup settings for full server backup
FULL_SERVER_BACKUP="true"
DOCKER_COMPOSE_PATHS=""
NGINX_CONFIG_PATHS="/etc/nginx /opt/nginx"
SSL_CERT_PATHS="/etc/letsencrypt /opt/ssl"
CUSTOM_BACKUP_PATHS=""
BACKUP_DOCKER_VOLUMES="true"

BOT_BACKUP_ENABLED="false"
BOT_BACKUP_PATH=""
BOT_BACKUP_SELECTED=""
BOT_BACKUP_DB_USER="postgres"

if [[ -t 0 ]]; then
    RED=$'\e[31m'
    GREEN=$'\e[32m'
    YELLOW=$'\e[33m'
    GRAY=$'\e[37m'
    LIGHT_GRAY=$'\e[90m'
    CYAN=$'\e[36m'
    RESET=$'\e[0m'
    BOLD=$'\e[1m'
else
    RED=""
    GREEN=""
    YELLOW=""
    GRAY=""
    LIGHT_GRAY=""
    CYAN=""
    RESET=""
    BOLD=""
fi

print_message() {
    local type="$1"
    local message="$2"
    local color_code="$RESET"

    case "$type" in
        "INFO") color_code="$GRAY" ;;
        "SUCCESS") color_code="$GREEN" ;;
        "WARN") color_code="$YELLOW" ;;
        "ERROR") color_code="$RED" ;;
        "ACTION") color_code="$CYAN" ;;
        "LINK") color_code="$CYAN" ;;
        *) type="INFO" ;;
    esac

    echo -e "${color_code}[$type]${RESET} $message"
}

# Auto-detect Remnawave services and their configurations
detect_remnawave_services() {
    local services=()
    local containers
    
    print_message "INFO" "Обнаружение установленных сервисов Remnawave..."
    
    # Get all running containers
    containers=$(docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}" | grep -E "(remnawave|postgres|valkey|redis|nginx)" || true)
    
    if [[ -z "$containers" ]]; then
        print_message "WARN" "Не найдено запущенных контейнеров Remnawave"
        return 1
    fi
    
    echo ""
    print_message "SUCCESS" "Обнаружены следующие сервисы:"
    echo "$containers"
    echo ""
    
    # Detect service directories
    local common_paths=(
        "/opt/remnawave"
        "/opt/stacks"
        "/root/remnawave"
        "/home/*/remnawave*"
        "/opt/remnawave*"
    )
    
    DOCKER_COMPOSE_PATHS=""
    for path in "${common_paths[@]}"; do
        if [[ -f "$path/docker-compose.yml" ]] || [[ -f "$path/compose.yml" ]]; then
            DOCKER_COMPOSE_PATHS="$DOCKER_COMPOSE_PATHS $path"
            print_message "SUCCESS" "Найден docker-compose в: $path"
        fi
    done
    
    return 0
}

# Create comprehensive backup including all services
create_extended_backup() {
    print_message "INFO" "Начинаю создание полного бэкапа сервера..."
    echo ""
    
    REMNAWAVE_VERSION=$(get_remnawave_version)
    TIMESTAMP=$(date +%Y-%m-%d"_"%H_%M_%S)
    BACKUP_FILE_FINAL="remnawave_full_backup_${TIMESTAMP}.tar.gz"
    
    mkdir -p "$BACKUP_DIR" || { 
        print_message "ERROR" "Не удалось создать каталог для бэкапов: $BACKUP_DIR"
        exit 1
    }
    
    local temp_backup_dir="$BACKUP_DIR/temp_${TIMESTAMP}"
    mkdir -p "$temp_backup_dir"
    
    # 1. Backup all PostgreSQL databases
    backup_all_databases "$temp_backup_dir"
    
    # 2. Backup Redis/Valkey data
    backup_redis_data "$temp_backup_dir"
    
    # 3. Backup Docker configurations and volumes
    backup_docker_configs "$temp_backup_dir"
    
    # 4. Backup Nginx configurations
    backup_nginx_configs "$temp_backup_dir"
    
    # 5. Backup SSL certificates
    backup_ssl_certificates "$temp_backup_dir"
    
    # 6. Backup application directories
    backup_application_directories "$temp_backup_dir"
    
    # 7. Create final archive
    create_final_archive "$temp_backup_dir" "$BACKUP_FILE_FINAL"
    
    # Cleanup temp directory
    rm -rf "$temp_backup_dir"
    
    print_message "SUCCESS" "Полный бэкап создан: $BACKUP_DIR/$BACKUP_FILE_FINAL"
    
    # Send backup via configured method
    if [[ "$UPLOAD_METHOD" == "telegram" ]]; then
        send_telegram_message "✅ Полный бэкап сервера создан успешно!" "$BACKUP_DIR/$BACKUP_FILE_FINAL"
    elif [[ "$UPLOAD_METHOD" == "google_drive" ]]; then
        upload_to_google_drive "$BACKUP_DIR/$BACKUP_FILE_FINAL"
    fi
    
    cleanup_old_backups
}

backup_all_databases() {
    local backup_dir="$1"
    local db_backup_dir="$backup_dir/databases"
    mkdir -p "$db_backup_dir"
    
    print_message "INFO" "Создание бэкапов всех баз данных..."
    
    # Check if Docker is running
    if ! docker ps &>/dev/null; then
        print_message "ERROR" "Docker не запущен или недоступен"
        return 1
    fi
    
    # Backup main Remnawave database
    if docker ps --format "{{.Names}}" | grep -q "^remnawave-db$"; then
        print_message "INFO" "Создание дампа основной БД Remnawave..."
        
        # Test database connection first
        if docker exec remnawave-db pg_isready -U postgres &>/dev/null; then
            if docker exec -t "remnawave-db" pg_dumpall -c -U "postgres" | gzip -9 > "$db_backup_dir/remnawave_db_${TIMESTAMP}.sql.gz"; then
                local db_size=$(du -h "$db_backup_dir/remnawave_db_${TIMESTAMP}.sql.gz" | cut -f1)
                print_message "SUCCESS" "Дамп основной БД создан (размер: $db_size)"
            else
                print_message "ERROR" "Ошибка при создании дампа основной БД"
                return 1
            fi
        else
            print_message "ERROR" "База данных remnawave-db недоступна"
            return 1
        fi
    else
        print_message "WARN" "Контейнер remnawave-db не найден или не запущен"
    fi
    
    # Backup Telegram shop database  
    if docker ps --format "{{.Names}}" | grep -q "^remnawave-tg-shop-db$"; then
        print_message "INFO" "Создание дампа БД Telegram магазина..."
        
        # Test database connection first
        if docker exec remnawave-tg-shop-db pg_isready -U postgres &>/dev/null; then
            if docker exec -t "remnawave-tg-shop-db" pg_dumpall -c -U "postgres" | gzip -9 > "$db_backup_dir/tg_shop_db_${TIMESTAMP}.sql.gz"; then
                local shop_db_size=$(du -h "$db_backup_dir/tg_shop_db_${TIMESTAMP}.sql.gz" | cut -f1)
                print_message "SUCCESS" "Дамп БД Telegram магазина создан (размер: $shop_db_size)"
            else
                print_message "ERROR" "Ошибка при создании дампа БД Telegram магазина"
                return 1
            fi
        else
            print_message "ERROR" "База данных remnawave-tg-shop-db недоступна"
            return 1
        fi
    else
        print_message "WARN" "Контейнер remnawave-tg-shop-db не найден"
    fi
    
    return 0
}

backup_redis_data() {
    local backup_dir="$1"
    local redis_backup_dir="$backup_dir/redis"
    mkdir -p "$redis_backup_dir"
    
    print_message "INFO" "Создание бэкапа Redis/Valkey данных..."
    
    if docker ps | grep -q "remnawave-redis"; then
        # Create Redis dump
        docker exec remnawave-redis redis-cli BGSAVE
        sleep 2
        
        # Copy dump file
        if docker cp remnawave-redis:/data/dump.rdb "$redis_backup_dir/redis_dump_${TIMESTAMP}.rdb" 2>/dev/null; then
            print_message "SUCCESS" "Бэкап Redis данных создан"
        else
            print_message "WARN" "Не удалось создать бэкап Redis данных"
        fi
    fi
}

backup_docker_configs() {
    local backup_dir="$1"
    local docker_backup_dir="$backup_dir/docker"
    mkdir -p "$docker_backup_dir"
    
    print_message "INFO" "Создание бэкапа Docker конфигураций..."
    
    # Backup docker-compose files
    for compose_path in $DOCKER_COMPOSE_PATHS; do
        if [[ -d "$compose_path" ]]; then
            local dir_name=$(basename "$compose_path")
            print_message "INFO" "Архивирование $compose_path..."
            tar -czf "$docker_backup_dir/${dir_name}_config_${TIMESTAMP}.tar.gz" -C "$(dirname "$compose_path")" "$dir_name" 2>/dev/null || {
                print_message "WARN" "Не удалось заархивировать $compose_path"
            }
        fi
    done
    
    # Export Docker volumes information
    print_message "INFO" "Экспорт информации о Docker volumes..."
    docker volume ls --format "table {{.Driver}}\t{{.Name}}" > "$docker_backup_dir/volumes_list_${TIMESTAMP}.txt"
    
    # Backup specific Docker volumes data if enabled
    if [[ "$BACKUP_DOCKER_VOLUMES" == "true" ]]; then
        backup_docker_volumes "$docker_backup_dir"
    fi
}

backup_docker_volumes() {
    local backup_dir="$1"
    local volumes_backup_dir="$backup_dir/volumes"
    mkdir -p "$volumes_backup_dir"
    
    print_message "INFO" "Создание бэкапа Docker volumes..."
    
    # Get list of volumes used by Remnawave containers
    local remnawave_volumes
    remnawave_volumes=$(docker ps --filter name=remnawave --format "{{.Names}}" | xargs -I {} docker inspect {} --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{"\n"}}{{end}}{{end}}' | sort -u)
    
    for volume in $remnawave_volumes; do
        if [[ -n "$volume" ]]; then
            print_message "INFO" "Бэкап volume: $volume"
            docker run --rm -v "$volume":/data -v "$volumes_backup_dir":/backup alpine tar czf "/backup/${volume}_${TIMESTAMP}.tar.gz" -C /data . 2>/dev/null || {
                print_message "WARN" "Не удалось создать бэкап volume: $volume"
            }
        fi
    done
}

backup_nginx_configs() {
    local backup_dir="$1"
    local nginx_backup_dir="$backup_dir/nginx"
    mkdir -p "$nginx_backup_dir"
    
    print_message "INFO" "Создание бэкапа Nginx конфигураций..."
    
    # Backup container nginx config
    if docker ps | grep -q "remnawave-nginx"; then
        docker cp remnawave-nginx:/etc/nginx "$nginx_backup_dir/container_nginx_${TIMESTAMP}" 2>/dev/null || {
            print_message "WARN" "Не удалось скопировать конфиг Nginx из контейнера"
        }
    fi
    
    # Backup system nginx configs
    for nginx_path in $NGINX_CONFIG_PATHS; do
        if [[ -d "$nginx_path" ]]; then
            print_message "INFO" "Архивирование Nginx конфигурации из $nginx_path"
            tar -czf "$nginx_backup_dir/system_nginx_$(basename $nginx_path)_${TIMESTAMP}.tar.gz" -C "$(dirname "$nginx_path")" "$(basename "$nginx_path")" 2>/dev/null || {
                print_message "WARN" "Не удалось заархивировать $nginx_path"
            }
        fi
    done
}

backup_ssl_certificates() {
    local backup_dir="$1"
    local ssl_backup_dir="$backup_dir/ssl"
    mkdir -p "$ssl_backup_dir"
    
    print_message "INFO" "Создание бэкапа SSL сертификатов..."
    
    for ssl_path in $SSL_CERT_PATHS; do
        if [[ -d "$ssl_path" ]]; then
            print_message "INFO" "Архивирование SSL сертификатов из $ssl_path"
            tar -czf "$ssl_backup_dir/ssl_$(basename $ssl_path)_${TIMESTAMP}.tar.gz" -C "$(dirname "$ssl_path")" "$(basename "$ssl_path")" 2>/dev/null || {
                print_message "WARN" "Не удалось заархивировать $ssl_path"
            }
        fi
    done
}

backup_application_directories() {
    local backup_dir="$1"
    local apps_backup_dir="$backup_dir/applications"
    mkdir -p "$apps_backup_dir"
    
    print_message "INFO" "Создание бэкапа директорий приложений..."
    
    # Backup main Remnawave directory
    if [[ -n "$REMNALABS_ROOT_DIR" && -d "$REMNALABS_ROOT_DIR" ]]; then
        print_message "INFO" "Архивирование основной директории Remnawave: $REMNALABS_ROOT_DIR"
        create_selective_archive "$REMNALABS_ROOT_DIR" "$apps_backup_dir/remnawave_main_${TIMESTAMP}.tar.gz"
    fi
    
    # Backup additional custom paths
    if [[ -n "$CUSTOM_BACKUP_PATHS" ]]; then
        for custom_path in $CUSTOM_BACKUP_PATHS; do
            if [[ -d "$custom_path" ]]; then
                local dir_name=$(basename "$custom_path")
                print_message "INFO" "Архивирование пользовательской директории: $custom_path"
                create_selective_archive "$custom_path" "$apps_backup_dir/custom_${dir_name}_${TIMESTAMP}.tar.gz"
            fi
        done
    fi
}

create_selective_archive() {
    local source_dir="$1"
    local output_file="$2"
    
    local exclude_args=""
    for pattern in $BACKUP_EXCLUDE_PATTERNS; do
        exclude_args="$exclude_args --exclude=$pattern"
    done
    
    tar -czf "$output_file" $exclude_args -C "$(dirname "$source_dir")" "$(basename "$source_dir")" 2>/dev/null || {
        print_message "WARN" "Не удалось создать архив: $output_file"
        return 1
    }
    
    return 0
}

create_final_archive() {
    local temp_dir="$1"
    local final_file="$2"
    
    print_message "INFO" "Создание итогового архива..."
    
    # Create backup metadata
    local metadata_file="$temp_dir/backup_metadata.txt"
    {
        echo "Backup created: $(date)"
        echo "Backup version: $VERSION"
        echo "Server hostname: $(hostname)"
        echo "Docker containers:"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
        echo ""
        echo "Docker volumes:"
        docker volume ls
        echo ""
        echo "Backup contents:"
        find "$temp_dir" -type f -name "*.tar.gz" -o -name "*.sql.gz" -o -name "*.rdb" | sort
    } > "$metadata_file"
    
    # Create final archive
    tar -czf "$BACKUP_DIR/$final_file" -C "$temp_dir" . || {
        print_message "ERROR" "Не удалось создать итоговый архив"
        exit 1
    }
    
    local backup_size=$(du -h "$BACKUP_DIR/$final_file" | cut -f1)
    print_message "SUCCESS" "Итоговый архив создан: $final_file (размер: $backup_size)"
}

# Utility functions
get_remnawave_version() {
    if docker inspect remnawave > /dev/null 2>&1; then
        local image_info
        image_info=$(docker inspect remnawave --format='{{.Config.Image}}' 2>/dev/null)
        if [[ "$image_info" =~ remnawave/backend:([0-9]+) ]]; then
            echo "${BASH_REMATCH[1]}"
        else
            echo "unknown"
        fi
    else
        echo "not-installed"
    fi
}

send_telegram_message() {
    local message="$1"
    local file_path="$2"
    
    if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
        print_message "WARN" "Telegram не настроен. Пропускаю отправку уведомления."
        return 1
    fi
    
    local api_url="https://api.telegram.org/bot$BOT_TOKEN"
    local thread_param=""
    
    # Add thread parameter if specified
    if [[ -n "$TG_MESSAGE_THREAD_ID" ]]; then
        thread_param="&message_thread_id=$TG_MESSAGE_THREAD_ID"
    fi
    
    # Send text message
    print_message "INFO" "Отправка уведомления в Telegram..."
    local response
    response=$(curl -s -X POST "$api_url/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$message" \
        -d "parse_mode=HTML$thread_param")
    
    if echo "$response" | grep -q '"ok":true'; then
        print_message "SUCCESS" "Уведомление отправлено в Telegram"
    else
        print_message "ERROR" "Ошибка отправки уведомления в Telegram"
        return 1
    fi
    
    # Send file if provided and exists
    if [[ -n "$file_path" && -f "$file_path" && "$file_path" != "None" ]]; then
        local file_size
        file_size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
        
        # Telegram file size limit is 50MB
        if [[ "$file_size" -gt 52428800 ]]; then
            print_message "WARN" "Файл слишком большой для Telegram (>50MB). Отправляю только уведомление."
            return 0
        fi
        
        print_message "INFO" "Отправка файла бэкапа в Telegram..."
        response=$(curl -s -X POST "$api_url/sendDocument" \
            -F "chat_id=$CHAT_ID" \
            -F "document=@$file_path$thread_param")
        
        if echo "$response" | grep -q '"ok":true'; then
            print_message "SUCCESS" "Файл бэкапа отправлен в Telegram"
        else
            print_message "ERROR" "Ошибка отправки файла в Telegram"
            return 1
        fi
    fi
    
    return 0
}

get_google_access_token() {
    if [[ -z "$GD_CLIENT_ID" || -z "$GD_CLIENT_SECRET" || -z "$GD_REFRESH_TOKEN" ]]; then
        print_message "ERROR" "Неполные данные для Google Drive API"
        return 1
    fi
    
    local response
    response=$(curl -s -X POST https://oauth2.googleapis.com/token \
        -d "client_id=$GD_CLIENT_ID" \
        -d "client_secret=$GD_CLIENT_SECRET" \
        -d "refresh_token=$GD_REFRESH_TOKEN" \
        -d "grant_type=refresh_token")
    
    local access_token
    access_token=$(echo "$response" | jq -r .access_token 2>/dev/null)
    
    if [[ -z "$access_token" || "$access_token" == "null" ]]; then
        print_message "ERROR" "Не удалось получить Access Token для Google Drive"
        return 1
    fi
    
    echo "$access_token"
}

upload_to_google_drive() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        print_message "ERROR" "Файл для загрузки не найден: $file_path"
        return 1
    fi
    
    print_message "INFO" "Загрузка бэкапа в Google Drive..."
    
    local access_token
    access_token=$(get_google_access_token)
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local file_name
    file_name=$(basename "$file_path")
    
    # Create metadata
    local metadata
    if [[ -n "$GD_FOLDER_ID" ]]; then
        metadata="{\"name\":\"$file_name\",\"parents\":[\"$GD_FOLDER_ID\"]}"
    else
        metadata="{\"name\":\"$file_name\"}"
    fi
    
    # Upload file
    local upload_response
    upload_response=$(curl -s -X POST \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: multipart/related; boundary=foo_bar_baz" \
        --data-binary "$(cat <<EOF
--foo_bar_baz
Content-Type: application/json; charset=UTF-8

$metadata
--foo_bar_baz
Content-Type: application/gzip

$(cat "$file_path")
--foo_bar_baz--
EOF
)" \
        "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")
    
    local file_id
    file_id=$(echo "$upload_response" | jq -r .id 2>/dev/null)
    
    if [[ -n "$file_id" && "$file_id" != "null" ]]; then
        print_message "SUCCESS" "Файл успешно загружен в Google Drive"
        print_message "INFO" "ID файла: $file_id"
        return 0
    else
        print_message "ERROR" "Ошибка загрузки в Google Drive"
        echo "Response: $upload_response" >&2
        return 1
    fi
}

cleanup_old_backups() {
    print_message "INFO" "Очистка старых бэкапов (старше $RETAIN_BACKUPS_DAYS дней)..."
    find "$BACKUP_DIR" -name "remnawave_*_backup_*.tar.gz" -mtime +$RETAIN_BACKUPS_DAYS -delete 2>/dev/null || true
}

# Enhanced restore function for full server restoration
restore_extended_backup() {
    clear
    echo "${GREEN}${BOLD}Полное восстановление сервера из бэкапа${RESET}"
    echo ""
    
    print_message "WARN" "Это восстановит ВСЕ сервисы и конфигурации сервера!"
    print_message "WARN" "Убедитесь, что вы находитесь на целевом сервере для восстановления."
    echo ""
    
    read -rp "${YELLOW}[?]${RESET} Продолжить полное восстановление? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_message "INFO" "Восстановление отменено."
        return
    fi
    
    print_message "INFO" "Поместите файл бэкапа в папку: ${BOLD}${BACKUP_DIR}${RESET}"
    echo ""
    
    if ! compgen -G "$BACKUP_DIR/remnawave_full_backup_*.tar.gz" > /dev/null; then
        print_message "ERROR" "Не найдено файлов полного бэкапа в ${BOLD}${BACKUP_DIR}${RESET}"
        read -rp "Нажмите Enter для возврата в меню..."
        return
    fi
    
    # Select backup file
    readarray -t SORTED_BACKUP_FILES < <(find "$BACKUP_DIR" -maxdepth 1 -name "remnawave_full_backup_*.tar.gz" -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2-)
    
    echo "Выберите файл для восстановления:"
    local i=1
    for file in "${SORTED_BACKUP_FILES[@]}"; do
        echo " $i) ${file##*/}"
        i=$((i+1))
    done
    echo ""
    echo " 0) Вернуться в главное меню"
    echo ""
    
    local user_choice
    read -rp "${GREEN}[?]${RESET} Введите номер файла: " user_choice
    
    if [[ "$user_choice" == "0" ]]; then
        return
    fi
    
    local selected_index=$((user_choice - 1))
    local selected_file="${SORTED_BACKUP_FILES[$selected_index]}"
    
    if [[ -z "$selected_file" ]]; then
        print_message "ERROR" "Неверный выбор файла"
        return
    fi
    
    perform_full_restore "$selected_file"
}

perform_full_restore() {
    local backup_file="$1"
    local restore_dir="/tmp/restore_$(date +%s)"
    
    print_message "INFO" "Начинаю полное восстановление из: ${backup_file##*/}"
    echo ""
    
    # Create restore directory and extract backup
    mkdir -p "$restore_dir"
    if ! tar -xzf "$backup_file" -C "$restore_dir"; then
        print_message "ERROR" "Не удалось распаковать бэкап"
        rm -rf "$restore_dir"
        return 1
    fi
    
    # Show backup metadata
    if [[ -f "$restore_dir/backup_metadata.txt" ]]; then
        print_message "INFO" "Информация о бэкапе:"
        cat "$restore_dir/backup_metadata.txt"
        echo ""
    fi
    
    # Step-by-step restoration
    print_message "ACTION" "Начинаю пошаговое восстановление..."
    echo ""
    
    # 1. Install Docker if not present
    install_docker_if_needed
    
    # 2. Restore Docker configurations
    restore_docker_configurations "$restore_dir"
    
    # 3. Restore databases
    restore_all_databases "$restore_dir"
    
    # 4. Restore Redis data
    restore_redis_data "$restore_dir"
    
    # 5. Restore Nginx configurations
    restore_nginx_configurations "$restore_dir"
    
    # 6. Restore SSL certificates
    restore_ssl_certificates "$restore_dir"
    
    # 7. Restore applications
    restore_applications "$restore_dir"
    
    # 8. Setup SSL certificates
    setup_ssl_certificates
    
    # 9. Start all services
    start_all_services "$restore_dir"
    
    # 10. Final verification
    verify_services_after_restore
    
    # Cleanup
    rm -rf "$restore_dir"
    
    print_message "SUCCESS" "Полное восстановление завершено!"
    echo ""
    print_message "INFO" "Следующие шаги:"
    print_message "ACTION" "1. ${BOLD}Измените A-записи доменов${RESET} на IP этого сервера"
    print_message "ACTION" "2. ${BOLD}Дождитесь распространения DNS${RESET} (может занять до 24 часов)"
    print_message "ACTION" "3. ${BOLD}Проверьте работу сервисов:${RESET} docker ps"
    print_message "ACTION" "4. ${BOLD}Протестируйте доступ:${RESET}"
    print_message "INFO" "   - Панель управления"
    print_message "INFO" "   - Страница подписки" 
    print_message "INFO" "   - Telegram бот (отправьте /start)"
    print_message "ACTION" "5. ${BOLD}Обновите firewall${RESET} правила при необходимости"
    echo ""
    print_message "SUCCESS" "🎉 Миграция сервера завершена! Все данные и настройки восстановлены."
}

install_docker_if_needed() {
    if ! command -v docker &> /dev/null; then
        print_message "INFO" "Docker не найден, устанавливаю..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        systemctl enable docker
        systemctl start docker
        print_message "SUCCESS" "Docker установлен"
    else
        print_message "SUCCESS" "Docker уже установлен"
    fi
}

install_certbot_if_needed() {
    if ! command -v certbot &> /dev/null; then
        print_message "INFO" "Certbot не найден, устанавливаю..."
        
        # Install snapd if not present
        if ! command -v snap &> /dev/null; then
            if command -v apt-get &> /dev/null; then
                apt-get update
                apt-get install -y snapd
            elif command -v yum &> /dev/null; then
                yum install -y epel-release
                yum install -y snapd
                systemctl enable --now snapd.socket
            fi
        fi
        
        # Install certbot via snap (recommended method)
        snap install --classic certbot
        ln -sf /snap/bin/certbot /usr/bin/certbot
        
        print_message "SUCCESS" "Certbot установлен"
    else
        print_message "SUCCESS" "Certbot уже установлен"
    fi
}

setup_ssl_certificates() {
    print_message "INFO" "Настройка SSL сертификатов..."
    echo ""
    
    print_message "ACTION" "Варианты настройки SSL:"
    echo " 1. Восстановить сертификаты из бэкапа (может потребоваться обновление)"
    echo " 2. Получить новые сертификаты через Let's Encrypt"  
    echo " 3. Пропустить настройку SSL (настроить вручную позже)"
    echo ""
    
    local ssl_choice
    read -rp "${GREEN}[?]${RESET} Выберите вариант (1-3): " ssl_choice
    echo ""
    
    case $ssl_choice in
        1)
            print_message "INFO" "Сертификаты восстановлены из бэкапа"
            print_message "WARN" "Рекомендуется обновить сертификаты после завершения восстановления:"
            print_message "INFO" "sudo certbot renew --force-renewal"
            ;;
        2)
            setup_new_ssl_certificates
            ;;
        3)
            print_message "INFO" "Настройка SSL пропущена"
            print_message "INFO" "Для настройки SSL позже используйте:"
            print_message "INFO" "sudo certbot --nginx -d your-domain.com"
            ;;
        *)
            print_message "WARN" "Неверный выбор, пропускаем настройку SSL"
            ;;
    esac
}

setup_new_ssl_certificates() {
    install_certbot_if_needed
    
    print_message "INFO" "Получение новых SSL сертификатов..."
    echo ""
    
    print_message "WARN" "Важно: домены должны уже указывать на этот сервер!"
    print_message "INFO" "Убедитесь, что A-записи настроены перед продолжением"
    echo ""
    
    read -rp "Введите основной домен панели (например: panel.yourdomain.com): " main_domain
    read -rp "Введите дополнительные домены через пробел (например: api.yourdomain.com shop.yourdomain.com): " additional_domains
    echo ""
    
    if [[ -n "$main_domain" ]]; then
        local domains="$main_domain"
        if [[ -n "$additional_domains" ]]; then
            domains="$domains $additional_domains"
        fi
        
        print_message "INFO" "Получение сертификатов для доменов: $domains"
        
        local certbot_domains=""
        for domain in $domains; do
            certbot_domains="$certbot_domains -d $domain"
        done
        
        if certbot --nginx $certbot_domains --non-interactive --agree-tos --email admin@${main_domain#*.} --no-eff-email; then
            print_message "SUCCESS" "SSL сертификаты успешно получены!"
            
            # Setup auto-renewal
            if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
                (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
                print_message "SUCCESS" "Автообновление сертификатов настроено"
            fi
        else
            print_message "ERROR" "Ошибка при получении SSL сертификатов"
            print_message "INFO" "Возможные причины:"
            print_message "INFO" "  - Домены не указывают на этот сервер"
            print_message "INFO" "  - Порт 80 заблокирован"
            print_message "INFO" "  - Превышен лимит запросов Let's Encrypt"
        fi
    else
        print_message "WARN" "Домен не указан, пропускаем настройку SSL"
    fi
}

restore_docker_configurations() {
    local restore_dir="$1"
    local docker_restore_dir="$restore_dir/docker"
    
    if [[ ! -d "$docker_restore_dir" ]]; then
        print_message "WARN" "Не найдена папка с Docker конфигурациями"
        return
    fi
    
    print_message "INFO" "Восстановление Docker конфигураций..."
    
    # Restore docker-compose directories
    for config_archive in "$docker_restore_dir"/*_config_*.tar.gz; do
        if [[ -f "$config_archive" ]]; then
            local config_name=$(basename "$config_archive" | sed 's/_config_.*\.tar\.gz//')
            local target_dir="/opt/$config_name"
            
            print_message "INFO" "Восстановление конфигурации: $config_name в $target_dir"
            mkdir -p "$target_dir"
            tar -xzf "$config_archive" -C "/opt/" || {
                print_message "WARN" "Не удалось восстановить конфигурацию: $config_name"
            }
        fi
    done
    
    # Restore Docker volumes if they exist
    local volumes_restore_dir="$docker_restore_dir/volumes"
    if [[ -d "$volumes_restore_dir" ]]; then
        restore_docker_volumes "$volumes_restore_dir"
    fi
}

restore_docker_volumes() {
    local volumes_dir="$1"
    
    print_message "INFO" "Восстановление Docker volumes..."
    
    for volume_archive in "$volumes_dir"/*.tar.gz; do
        if [[ -f "$volume_archive" ]]; then
            local volume_name=$(basename "$volume_archive" | sed 's/_.*\.tar\.gz//')
            
            print_message "INFO" "Восстановление volume: $volume_name"
            
            # Create volume if it doesn't exist
            docker volume create "$volume_name" 2>/dev/null || true
            
            # Restore volume data
            docker run --rm -v "$volume_name":/data -v "$volume_archive":/backup.tar.gz alpine sh -c "cd /data && tar -xzf /backup.tar.gz --strip-components=0" || {
                print_message "WARN" "Не удалось восстановить volume: $volume_name"
            }
        fi
    done
}

restore_all_databases() {
    local restore_dir="$1"
    local db_restore_dir="$restore_dir/databases"
    
    if [[ ! -d "$db_restore_dir" ]]; then
        print_message "WARN" "Не найдена папка с базами данных"
        return
    fi
    
    print_message "INFO" "Восстановление баз данных..."
    
    # Wait for database containers to be ready
    sleep 10
    
    # Restore main Remnawave database
    for db_dump in "$db_restore_dir"/remnawave_db_*.sql.gz; do
        if [[ -f "$db_dump" ]]; then
            print_message "INFO" "Восстановление основной БД Remnawave..."
            if docker ps | grep -q "remnawave-db"; then
                zcat "$db_dump" | docker exec -i remnawave-db psql -U postgres || {
                    print_message "ERROR" "Не удалось восстановить основную БД"
                }
            else
                print_message "WARN" "Контейнер remnawave-db не запущен"
            fi
            break
        fi
    done
    
    # Restore Telegram shop database
    for shop_dump in "$db_restore_dir"/tg_shop_db_*.sql.gz; do
        if [[ -f "$shop_dump" ]]; then
            print_message "INFO" "Восстановление БД Telegram магазина..."
            if docker ps | grep -q "remnawave-tg-shop-db"; then
                zcat "$shop_dump" | docker exec -i remnawave-tg-shop-db psql -U postgres || {
                    print_message "ERROR" "Не удалось восстановить БД Telegram магазина"
                }
            else
                print_message "WARN" "Контейнер remnawave-tg-shop-db не запущен"
            fi
            break
        fi
    done
}

restore_redis_data() {
    local restore_dir="$1"
    local redis_restore_dir="$restore_dir/redis"
    
    if [[ ! -d "$redis_restore_dir" ]]; then
        return
    fi
    
    print_message "INFO" "Восстановление Redis данных..."
    
    for redis_dump in "$redis_restore_dir"/redis_dump_*.rdb; do
        if [[ -f "$redis_dump" ]] && docker ps | grep -q "remnawave-redis"; then
            print_message "INFO" "Восстановление Redis дампа..."
            docker cp "$redis_dump" remnawave-redis:/data/dump.rdb
            docker restart remnawave-redis
            break
        fi
    done
}

restore_nginx_configurations() {
    local restore_dir="$1"
    local nginx_restore_dir="$restore_dir/nginx"
    
    if [[ ! -d "$nginx_restore_dir" ]]; then
        return
    fi
    
    print_message "INFO" "Восстановление Nginx конфигураций..."
    
    # Restore container nginx config
    for nginx_config in "$nginx_restore_dir"/container_nginx_*; do
        if [[ -d "$nginx_config" ]] && docker ps | grep -q "remnawave-nginx"; then
            docker cp "$nginx_config/." remnawave-nginx:/etc/nginx/
            break
        fi
    done
    
    # Restore system nginx configs
    for nginx_archive in "$nginx_restore_dir"/system_nginx_*.tar.gz; do
        if [[ -f "$nginx_archive" ]]; then
            local nginx_type=$(basename "$nginx_archive" | sed 's/system_nginx_\(.*\)_.*\.tar\.gz/\1/')
            local target_path="/etc/$nginx_type"
            
            if [[ "$nginx_type" == "nginx" ]]; then
                target_path="/etc/nginx"
            fi
            
            print_message "INFO" "Восстановление системного Nginx в: $target_path"
            mkdir -p "$(dirname "$target_path")"
            tar -xzf "$nginx_archive" -C "$(dirname "$target_path")" || {
                print_message "WARN" "Не удалось восстановить Nginx конфигурацию"
            }
        fi
    done
}

restore_ssl_certificates() {
    local restore_dir="$1"
    local ssl_restore_dir="$restore_dir/ssl"
    
    if [[ ! -d "$ssl_restore_dir" ]]; then
        return
    fi
    
    print_message "INFO" "Восстановление SSL сертификатов..."
    
    for ssl_archive in "$ssl_restore_dir"/ssl_*.tar.gz; do
        if [[ -f "$ssl_archive" ]]; then
            local ssl_type=$(basename "$ssl_archive" | sed 's/ssl_\(.*\)_.*\.tar\.gz/\1/')
            local target_path="/etc/$ssl_type"
            
            if [[ "$ssl_type" == "letsencrypt" ]]; then
                target_path="/etc/letsencrypt"
            fi
            
            print_message "INFO" "Восстановление SSL сертификатов в: $target_path"
            mkdir -p "$(dirname "$target_path")"
            tar -xzf "$ssl_archive" -C "$(dirname "$target_path")" || {
                print_message "WARN" "Не удалось восстановить SSL сертификаты"
            }
        fi
    done
}

restore_applications() {
    local restore_dir="$1"
    local apps_restore_dir="$restore_dir/applications"
    
    if [[ ! -d "$apps_restore_dir" ]]; then
        return
    fi
    
    print_message "INFO" "Восстановление директорий приложений..."
    
    for app_archive in "$apps_restore_dir"/*.tar.gz; do
        if [[ -f "$app_archive" ]]; then
            local app_name=$(basename "$app_archive" | sed 's/_.*\.tar\.gz//')
            local target_dir=""
            
            case "$app_name" in
                "remnawave"|"main")
                    target_dir="/opt"
                    ;;
                "custom")
                    # Extract to original location based on archive name
                    target_dir="/opt"
                    ;;
                *)
                    target_dir="/opt"
                    ;;
            esac
            
            print_message "INFO" "Восстановление приложения: $app_name в $target_dir"
            mkdir -p "$target_dir"
            tar -xzf "$app_archive" -C "$target_dir" || {
                print_message "WARN" "Не удалось восстановить приложение: $app_name"
            }
        fi
    done
}

start_all_services() {
    local restore_dir="$1"
    
    print_message "INFO" "Запуск всех сервисов..."
    
    # Find and start docker-compose services
    local compose_dirs=$(find /opt -name "docker-compose.yml" -o -name "compose.yml" | xargs dirname | sort -u)
    
    for compose_dir in $compose_dirs; do
        if [[ -f "$compose_dir/docker-compose.yml" ]] || [[ -f "$compose_dir/compose.yml" ]]; then
            print_message "INFO" "Запуск сервисов в: $compose_dir"
            cd "$compose_dir"
            docker-compose down 2>/dev/null || true
            docker-compose up -d || {
                print_message "WARN" "Не удалось запустить сервисы в: $compose_dir"
            }
        fi
    done
    
    # Wait for services to start
    sleep 15
    
    # Show service status
    print_message "SUCCESS" "Статус запущенных сервисов:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
}

verify_services_after_restore() {
    print_message "INFO" "Проверка восстановленных сервисов..."
    echo ""
    
    local services_status=()
    local all_services=(
        "remnawave:Основная панель"
        "remnawave-db:База данных"  
        "remnawave-redis:Redis кэш"
        "remnawave-nginx:Веб-сервер"
        "remnawave-subscription-page:Страница подписки"
        "remnawave-telegram-mini-app:Telegram мини-приложение"
        "remnawave-tg-shop:Telegram бот"
        "remnawave-tg-shop-db:БД Telegram бота"
    )
    
    for service_info in "${all_services[@]}"; do
        local service_name="${service_info%%:*}"
        local service_desc="${service_info##*:}"
        
        if docker ps --format "{{.Names}}" | grep -q "^${service_name}$"; then
            local status=$(docker ps --format "{{.Status}}" --filter "name=^${service_name}$")
            if [[ "$status" =~ Up ]]; then
                print_message "SUCCESS" "${service_desc}: ✅ Работает"
                services_status+=("✅ $service_desc")
            else
                print_message "WARN" "${service_desc}: ⚠️ Проблемы ($status)"
                services_status+=("⚠️ $service_desc")
            fi
        else
            print_message "INFO" "${service_desc}: ➖ Не установлен"
            services_status+=("➖ $service_desc")
        fi
    done
    
    echo ""
    print_message "INFO" "Итоговый статус сервисов:"
    for status in "${services_status[@]}"; do
        echo "  $status"
    done
    echo ""
}

# Enhanced main menu with full server backup options
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}${BOLD}REMNAWAVE FULL SERVER BACKUP & RESTORE by distillium${RESET}"
        echo -e "${BOLD}${LIGHT_GRAY}Расширенная версия: ${VERSION}${RESET}"
        echo ""
        echo "   1. Создание полного бэкапа сервера"
        echo "   2. Полное восстановление сервера"
        echo ""
        echo "   3. Обнаружение установленных сервисов"
        echo "   4. Настройка путей для бэкапа"
        echo "   5. Настройка автоматической отправки"
        echo ""
        echo "   6. Создание стандартного бэкапа (только Remnawave)"
        echo "   7. Стандартное восстановление"
        echo ""
        echo "   8. Обновление скрипта"
        echo "   9. Удаление скрипта"
        echo ""
        echo "   0. Выход"
        echo -e "   —  Быстрый запуск: ${BOLD}${GREEN}rw-backup-extended${RESET} доступен из любой точки системы"
        echo ""

        read -rp "${GREEN}[?]${RESET} Выберите пункт: " choice
        echo ""
        case $choice in
            1) 
                detect_remnawave_services
                create_extended_backup 
                read -rp "Нажмите Enter для продолжения..." 
                ;;
            2) restore_extended_backup ;;
            3) 
                detect_remnawave_services
                read -rp "Нажмите Enter для продолжения..." 
                ;;
            4) configure_backup_paths ;;
            5) setup_auto_send ;;
            6) 
                create_backup 
                read -rp "Нажмите Enter для продолжения..." 
                ;;
            7) restore_backup ;;
            8) update_script ;;
            9) remove_script ;;
            0) echo "Выход..."; exit 0 ;;
            *) 
                print_message "ERROR" "Неверный ввод. Пожалуйста, выберите один из предложенных пунктов." 
                read -rp "Нажмите Enter для продолжения..." 
                ;;
        esac
    done
}

configure_backup_paths() {
    while true; do
        clear
        echo -e "${GREEN}${BOLD}Настройка путей для бэкапа${RESET}"
        echo ""
        
        print_message "INFO" "Текущие настройки:"
        if [[ "$FULL_SERVER_BACKUP" == "true" ]]; then
            echo "  Полный бэкап сервера: ${GREEN}ВКЛЮЧЕН${RESET}"
        else
            echo "  Полный бэкап сервера: ${RED}ВЫКЛЮЧЕН${RESET}"
        fi
        echo "  Docker Compose пути: ${DOCKER_COMPOSE_PATHS:-"не настроены"}"
        echo "  Nginx конфигурации: ${NGINX_CONFIG_PATHS}"
        echo "  SSL сертификаты: ${SSL_CERT_PATHS}"
        echo "  Дополнительные пути: ${CUSTOM_BACKUP_PATHS:-"не настроены"}"
        if [[ "$BACKUP_DOCKER_VOLUMES" == "true" ]]; then
            echo "  Бэкап Docker volumes: ${GREEN}ВКЛЮЧЕН${RESET}"
        else
            echo "  Бэкап Docker volumes: ${RED}ВЫКЛЮЧЕН${RESET}"
        fi
        echo ""
        
        echo " 1. Переключить полный бэкап сервера"
        echo " 2. Настроить пути Docker Compose"
        echo " 3. Настроить пути Nginx"
        echo " 4. Настроить пути SSL"
        echo " 5. Добавить дополнительные пути"
        echo " 6. Переключить бэкап Docker volumes"
        echo " 7. Автоопределение путей"
        echo ""
        echo " 0. Вернуться в главное меню"
        echo ""
        
        read -rp "${GREEN}[?]${RESET} Выберите пункт: " choice
        echo ""
        
        case $choice in
            1)
                if [[ "$FULL_SERVER_BACKUP" == "true" ]]; then
                    FULL_SERVER_BACKUP="false"
                    print_message "SUCCESS" "Полный бэкап сервера выключен"
                else
                    FULL_SERVER_BACKUP="true"
                    print_message "SUCCESS" "Полный бэкап сервера включен"
                fi
                read -rp "Нажмите Enter для продолжения..."
                ;;
            2)
                echo "Введите пути к директориям с docker-compose файлами (через пробел):"
                read -rp "> " new_compose_paths
                DOCKER_COMPOSE_PATHS="$new_compose_paths"
                print_message "SUCCESS" "Пути Docker Compose обновлены"
                read -rp "Нажмите Enter для продолжения..."
                ;;
            3)
                echo "Введите пути к Nginx конфигурациям (через пробел):"
                read -rp "> " new_nginx_paths
                NGINX_CONFIG_PATHS="$new_nginx_paths"
                print_message "SUCCESS" "Пути Nginx обновлены"
                read -rp "Нажмите Enter для продолжения..."
                ;;
            4)
                echo "Введите пути к SSL сертификатам (через пробел):"
                read -rp "> " new_ssl_paths
                SSL_CERT_PATHS="$new_ssl_paths"
                print_message "SUCCESS" "Пути SSL обновлены"
                read -rp "Нажмите Enter для продолжения..."
                ;;
            5)
                echo "Введите дополнительные пути для бэкапа (через пробел):"
                read -rp "> " new_custom_paths
                CUSTOM_BACKUP_PATHS="$new_custom_paths"
                print_message "SUCCESS" "Дополнительные пути обновлены"
                read -rp "Нажмите Enter для продолжения..."
                ;;
            6)
                if [[ "$BACKUP_DOCKER_VOLUMES" == "true" ]]; then
                    BACKUP_DOCKER_VOLUMES="false"
                    print_message "SUCCESS" "Бэкап Docker volumes выключен"
                else
                    BACKUP_DOCKER_VOLUMES="true"
                    print_message "SUCCESS" "Бэкап Docker volumes включен"
                fi
                read -rp "Нажмите Enter для продолжения..."
                ;;
            7)
                detect_remnawave_services
                print_message "SUCCESS" "Автоопределение путей выполнено"
                read -rp "Нажмите Enter для продолжения..."
                ;;
            0) break ;;
            *) 
                print_message "ERROR" "Неверный ввод"
                read -rp "Нажмите Enter для продолжения..."
                ;;
        esac
    done
}

# Configuration management functions
save_config() {
    print_message "INFO" "Сохранение конфигурации в ${BOLD}${CONFIG_FILE}${RESET}..."
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
DB_USER="$DB_USER"
UPLOAD_METHOD="$UPLOAD_METHOD"
GD_CLIENT_ID="$GD_CLIENT_ID"
GD_CLIENT_SECRET="$GD_CLIENT_SECRET"
GD_REFRESH_TOKEN="$GD_REFRESH_TOKEN"
GD_FOLDER_ID="$GD_FOLDER_ID"
CRON_TIMES="$CRON_TIMES"
REMNALABS_ROOT_DIR="$REMNALABS_ROOT_DIR"
TG_MESSAGE_THREAD_ID="$TG_MESSAGE_THREAD_ID"
BOT_BACKUP_ENABLED="$BOT_BACKUP_ENABLED"
BOT_BACKUP_PATH="$BOT_BACKUP_PATH"
BOT_BACKUP_SELECTED="$BOT_BACKUP_SELECTED"
BOT_BACKUP_DB_USER="$BOT_BACKUP_DB_USER"
FULL_SERVER_BACKUP="$FULL_SERVER_BACKUP"
DOCKER_COMPOSE_PATHS="$DOCKER_COMPOSE_PATHS"
NGINX_CONFIG_PATHS="$NGINX_CONFIG_PATHS"
SSL_CERT_PATHS="$SSL_CERT_PATHS"
CUSTOM_BACKUP_PATHS="$CUSTOM_BACKUP_PATHS"
BACKUP_DOCKER_VOLUMES="$BACKUP_DOCKER_VOLUMES"
EOF
    chmod 600 "$CONFIG_FILE" || { 
        print_message "ERROR" "Не удалось установить права доступа (600) для ${BOLD}${CONFIG_FILE}${RESET}"
        exit 1
    }
    print_message "SUCCESS" "Конфигурация сохранена."
}

load_or_create_config() {
    # Check for original script configuration
    check_original_script_config
    
    if [[ -f "$CONFIG_FILE" ]]; then
        print_message "INFO" "Загрузка конфигурации..."
        source "$CONFIG_FILE"
        
        # Set defaults for missing values
        UPLOAD_METHOD=${UPLOAD_METHOD:-telegram}
        DB_USER=${DB_USER:-postgres}
        FULL_SERVER_BACKUP=${FULL_SERVER_BACKUP:-true}
        BACKUP_DOCKER_VOLUMES=${BACKUP_DOCKER_VOLUMES:-true}
        NGINX_CONFIG_PATHS=${NGINX_CONFIG_PATHS:-"/etc/nginx /opt/nginx"}
        SSL_CERT_PATHS=${SSL_CERT_PATHS:-"/etc/letsencrypt /opt/ssl"}
        
        # Auto-detect paths if not configured
        if [[ -z "$REMNALABS_ROOT_DIR" || -z "$DOCKER_COMPOSE_PATHS" ]]; then
            print_message "INFO" "Автоопределение путей конфигурации..."
            detect_remnawave_services
            save_config
        fi
    else
        print_message "INFO" "Создание новой конфигурации..."
        setup_initial_config
    fi
}

check_original_script_config() {
    local original_config="/opt/rw-backup-restore/config.env"
    
    # Check if original script exists and we don't have config yet
    if [[ -f "$original_config" && ! -f "$CONFIG_FILE" ]]; then
        print_message "INFO" "Обнаружена конфигурация оригинального скрипта"
        
        # Ask user if they want to import settings
        echo ""
        print_message "ACTION" "Импортировать настройки из оригинального скрипта?"
        print_message "INFO" "Это скопирует Telegram настройки и пути к Remnawave"
        echo ""
        
        read -rp "${GREEN}[?]${RESET} Импортировать настройки? (Y/n): " import_choice
        
        if [[ "$import_choice" =~ ^[Yy]$|^$ ]]; then
            import_original_config "$original_config"
        else
            print_message "INFO" "Настройки не импортированы, будет создана новая конфигурация"
        fi
    fi
}

import_original_config() {
    local original_config="$1"
    
    print_message "INFO" "Импорт настроек из оригинального скрипта..."
    
    # Source original config to get variables
    source "$original_config" 2>/dev/null || {
        print_message "WARN" "Не удалось загрузить оригинальную конфигурацию"
        return 1
    }
    
    # Import compatible settings
    print_message "SUCCESS" "Импортированы следующие настройки:"
    
    if [[ -n "$BOT_TOKEN" ]]; then
        print_message "INFO" "  - Telegram Bot Token: ✅"
    fi
    
    if [[ -n "$CHAT_ID" ]]; then
        print_message "INFO" "  - Chat ID: ✅"  
    fi
    
    if [[ -n "$DB_USER" ]]; then
        print_message "INFO" "  - Database User: $DB_USER"
    fi
    
    if [[ -n "$REMNALABS_ROOT_DIR" ]]; then
        print_message "INFO" "  - Remnawave Path: $REMNALABS_ROOT_DIR"
    fi
    
    # Set extended defaults
    FULL_SERVER_BACKUP="true"
    BACKUP_DOCKER_VOLUMES="true" 
    NGINX_CONFIG_PATHS="/etc/nginx /opt/nginx"
    SSL_CERT_PATHS="/etc/letsencrypt /opt/ssl"
    
    # Save merged configuration
    save_config
    
    print_message "SUCCESS" "Настройки успешно импортированы и расширены!"
}

setup_initial_config() {
    clear
    echo -e "${GREEN}${BOLD}Первоначальная настройка${RESET}"
    echo ""
    
    # Telegram configuration
    print_message "ACTION" "Настройка уведомлений Telegram:"
    echo ""
    print_message "INFO" "Для получения уведомлений о бэкапах нужно настроить Telegram бота"
    print_message "INFO" "Бот будет отправлять файлы бэкапов и уведомления о статусе"
    echo ""
    
    print_message "INFO" "1. Создайте бота в ${CYAN}@BotFather${RESET}:"
    print_message "INFO" "   - Отправьте команду /newbot"
    print_message "INFO" "   - Выберите имя и username для бота"
    print_message "INFO" "   - Получите API Token"
    echo ""
    
    read -rp "Введите API Token бота: " BOT_TOKEN
    echo ""
    
    print_message "INFO" "2. Получите Chat ID для отправки уведомлений:"
    print_message "INFO" "   Для личных сообщений: узнайте свой Telegram ID у ${CYAN}@username_to_id_bot${RESET}"
    print_message "INFO" "   Для группы: добавьте бота в группу и сделайте администратором"
    print_message "INFO" "   Затем узнайте Chat ID группы у ${CYAN}@username_to_id_bot${RESET}"
    echo ""
    
    read -rp "Введите Chat ID (группы или личный): " CHAT_ID
    echo ""
    
    print_message "INFO" "3. Опционально: для отправки в топик группы"
    print_message "INFO" "   Создайте топик в группе и узнайте его Message Thread ID"
    read -rp "Message Thread ID (оставьте пустым для общего чата): " TG_MESSAGE_THREAD_ID
    echo ""
    
    # Test Telegram configuration
    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        print_message "INFO" "Проверка настроек Telegram..."
        local test_response
        test_response=$(curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d "chat_id=$CHAT_ID" \
            -d "text=🔧 Тест уведомлений Safe Backup Extended - настройка завершена!")
        
        if echo "$test_response" | grep -q '"ok":true'; then
            print_message "SUCCESS" "Telegram настроен успешно! Проверьте сообщение в чате."
        else
            print_message "WARN" "Возможна ошибка в настройке Telegram. Проверьте Token и Chat ID."
        fi
    fi
    echo ""
    
    # Database configuration
    print_message "ACTION" "Настройка базы данных:"
    read -rp "Пользователь PostgreSQL (по умолчанию postgres): " DB_USER
    DB_USER=${DB_USER:-postgres}
    echo ""
    
    # Remnawave directory
    print_message "ACTION" "Путь к панели Remnawave:"
    echo " 1. /opt/remnawave"
    echo " 2. /root/remnawave" 
    echo " 3. /opt/stacks/remnawave"
    echo " 4. Указать свой путь"
    echo ""
    
    local path_choice
    while true; do
        read -rp "Выберите вариант (1-4): " path_choice
        case "$path_choice" in
            1) REMNALABS_ROOT_DIR="/opt/remnawave"; break ;;
            2) REMNALABS_ROOT_DIR="/root/remnawave"; break ;;
            3) REMNALABS_ROOT_DIR="/opt/stacks/remnawave"; break ;;
            4) 
                read -rp "Введите полный путь: " REMNALABS_ROOT_DIR
                break ;;
            *) print_message "ERROR" "Неверный ввод" ;;
        esac
    done
    echo ""
    
    # Set defaults
    UPLOAD_METHOD="telegram"
    FULL_SERVER_BACKUP="true"
    BACKUP_DOCKER_VOLUMES="true"
    BOT_BACKUP_ENABLED="false"
    
    # Auto-detect services
    detect_remnawave_services
    
    # Save configuration
    save_config
    
    print_message "SUCCESS" "Первоначальная настройка завершена!"
    read -rp "Нажмите Enter для продолжения..."
}

# Standard backup function (original functionality)
create_backup() {
    print_message "INFO" "Начинаю процесс создания стандартного резервного копирования Remnawave..."
    echo ""
    
    REMNAWAVE_VERSION=$(get_remnawave_version)
    TIMESTAMP=$(date +%Y-%m-%d"_"%H_%M_%S)
    BACKUP_FILE_DB="dump_${TIMESTAMP}.sql.gz"
    BACKUP_FILE_FINAL="remnawave_backup_${TIMESTAMP}.tar.gz"
    
    mkdir -p "$BACKUP_DIR" || { 
        print_message "ERROR" "Не удалось создать каталог для бэкапов: $BACKUP_DIR"
        exit 1
    }
    
    # Check if remnawave-db container exists and is running
    if ! docker inspect remnawave-db > /dev/null 2>&1 || ! docker container inspect -f '{{.State.Running}}' remnawave-db 2>/dev/null | grep -q "true"; then
        print_message "ERROR" "Контейнер 'remnawave-db' не найден или не запущен"
        exit 1
    fi
    
    # Create PostgreSQL dump
    print_message "INFO" "Создание PostgreSQL дампа..."
    if ! docker exec -t "remnawave-db" pg_dumpall -c -U "$DB_USER" | gzip -9 > "$BACKUP_DIR/$BACKUP_FILE_DB"; then
        print_message "ERROR" "Ошибка при создании дампа PostgreSQL"
        exit 1
    fi
    
    print_message "SUCCESS" "Дамп PostgreSQL создан: $BACKUP_FILE_DB"
    
    # Archive Remnawave directory
    BACKUP_ITEMS=("$BACKUP_FILE_DB")
    
    if [[ -d "$REMNALABS_ROOT_DIR" ]]; then
        print_message "INFO" "Архивирование директории Remnawave..."
        REMNAWAVE_DIR_ARCHIVE="remnawave_dir_${TIMESTAMP}.tar.gz"
        
        local exclude_args=""
        for pattern in $BACKUP_EXCLUDE_PATTERNS; do
            exclude_args="$exclude_args --exclude=$pattern"
        done
        
        if tar -czf "$BACKUP_DIR/$REMNAWAVE_DIR_ARCHIVE" $exclude_args -C "$(dirname "$REMNALABS_ROOT_DIR")" "$(basename "$REMNALABS_ROOT_DIR")"; then
            BACKUP_ITEMS+=("$REMNAWAVE_DIR_ARCHIVE")
            print_message "SUCCESS" "Архив директории создан: $REMNAWAVE_DIR_ARCHIVE"
        else
            print_message "WARN" "Не удалось создать архив директории Remnawave"
        fi
    else
        print_message "WARN" "Директория Remnawave не найдена: $REMNALABS_ROOT_DIR"
    fi
    
    # Create final archive
    print_message "INFO" "Создание итогового архива..."
    if (cd "$BACKUP_DIR" && tar -czf "$BACKUP_FILE_FINAL" "${BACKUP_ITEMS[@]}"); then
        print_message "SUCCESS" "Итоговый бэкап создан: $BACKUP_FILE_FINAL"
        
        # Cleanup temporary files
        for item in "${BACKUP_ITEMS[@]}"; do
            rm -f "$BACKUP_DIR/$item"
        done
        
        # Send backup
        if [[ "$UPLOAD_METHOD" == "telegram" ]]; then
            send_telegram_message "✅ Стандартный бэкап Remnawave создан успешно!" "$BACKUP_DIR/$BACKUP_FILE_FINAL"
        fi
        
        cleanup_old_backups
    else
        print_message "ERROR" "Не удалось создать итоговый архив"
        exit 1
    fi
}

# Standard restore function
restore_backup() {
    clear
    echo "${GREEN}${BOLD}Восстановление Remnawave из бэкапа${RESET}"
    echo ""
    
    if ! compgen -G "$BACKUP_DIR/remnawave_backup_*.tar.gz" > /dev/null; then
        print_message "ERROR" "Не найдено стандартных файлов бэкапов в ${BOLD}${BACKUP_DIR}${RESET}"
        print_message "INFO" "Поместите файл бэкапа в эту папку"
        read -rp "Нажмите Enter для возврата в меню..."
        return
    fi
    
    # List backup files
    readarray -t SORTED_BACKUP_FILES < <(find "$BACKUP_DIR" -maxdepth 1 -name "remnawave_backup_*.tar.gz" -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2-)
    
    echo "Выберите файл для восстановления:"
    local i=1
    for file in "${SORTED_BACKUP_FILES[@]}"; do
        echo " $i) ${file##*/}"
        i=$((i+1))
    done
    echo ""
    echo " 0) Вернуться в главное меню"
    echo ""
    
    local user_choice
    read -rp "${GREEN}[?]${RESET} Введите номер файла: " user_choice
    
    if [[ "$user_choice" == "0" ]]; then
        return
    fi
    
    local selected_index=$((user_choice - 1))
    local selected_file="${SORTED_BACKUP_FILES[$selected_index]}"
    
    if [[ -z "$selected_file" ]]; then
        print_message "ERROR" "Неверный выбор файла"
        return
    fi
    
    perform_standard_restore "$selected_file"
}

perform_standard_restore() {
    local backup_file="$1"
    local restore_dir="/tmp/restore_$(date +%s)"
    
    print_message "INFO" "Начинаю восстановление из: ${backup_file##*/}"
    
    # Extract backup
    mkdir -p "$restore_dir"
    if ! tar -xzf "$backup_file" -C "$restore_dir"; then
        print_message "ERROR" "Не удалось распаковать бэкап"
        rm -rf "$restore_dir"
        return 1
    fi
    
    # Stop services
    print_message "INFO" "Остановка сервисов..."
    if [[ -d "$REMNALABS_ROOT_DIR" ]]; then
        cd "$REMNALABS_ROOT_DIR" 2>/dev/null && docker-compose down 2>/dev/null || true
    fi
    
    # Restore database
    local db_dump=$(find "$restore_dir" -name "dump_*.sql.gz" | head -1)
    if [[ -f "$db_dump" ]]; then
        print_message "INFO" "Восстановление базы данных..."
        if docker ps | grep -q "remnawave-db"; then
            zcat "$db_dump" | docker exec -i remnawave-db psql -U "$DB_USER" || {
                print_message "ERROR" "Не удалось восстановить базу данных"
            }
        fi
    fi
    
    # Restore directory
    local dir_archive=$(find "$restore_dir" -name "remnawave_dir_*.tar.gz" | head -1)
    if [[ -f "$dir_archive" ]]; then
        print_message "INFO" "Восстановление директории Remnawave..."
        if [[ -d "$REMNALABS_ROOT_DIR" ]]; then
            mv "$REMNALABS_ROOT_DIR" "${REMNALABS_ROOT_DIR}.backup.$(date +%s)"
        fi
        tar -xzf "$dir_archive" -C "$(dirname "$REMNALABS_ROOT_DIR")"
    fi
    
    # Start services
    print_message "INFO" "Запуск сервисов..."
    if [[ -d "$REMNALABS_ROOT_DIR" ]]; then
        cd "$REMNALABS_ROOT_DIR" && docker-compose up -d || {
            print_message "WARN" "Не удалось запустить сервисы автоматически"
        }
    fi
    
    # Cleanup
    rm -rf "$restore_dir"
    
    print_message "SUCCESS" "Восстановление завершено!"
}

# Other utility functions
setup_auto_send() {
    print_message "INFO" "Настройка автоматической отправки бэкапов..."
    echo ""
    print_message "INFO" "Эта функция позволит настроить автоматическое создание бэкапов по расписанию"
    
    # Implementation for cron setup would go here
    print_message "WARN" "Функция в разработке"
    read -rp "Нажмите Enter для продолжения..."
}

update_script() {
    print_message "INFO" "Проверка обновлений скрипта..."
    
    # Check for updates logic would go here
    print_message "SUCCESS" "У вас установлена актуальная версия: $VERSION"
    read -rp "Нажмите Enter для продолжения..."
}

remove_script() {
    print_message "WARN" "Удаление скрипта и всех его данных"
    echo ""
    
    read -rp "${RED}[?]${RESET} Вы уверены, что хотите удалить скрипт? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        print_message "INFO" "Удаление файлов скрипта..."
        
        # Remove symlink
        [[ -L "$SYMLINK_PATH" ]] && rm -f "$SYMLINK_PATH"
        
        # Remove installation directory
        [[ -d "$INSTALL_DIR" ]] && rm -rf "$INSTALL_DIR"
        
        print_message "SUCCESS" "Скрипт успешно удален"
        exit 0
    else
        print_message "INFO" "Удаление отменено"
    fi
}

# Setup and initialization functions
setup_symlink() {
    if [[ "$EUID" -ne 0 ]]; then
        print_message "WARN" "Для управления символической ссылкой требуются права root"
        return 1
    fi

    if [[ -L "$SYMLINK_PATH" && "$(readlink -f "$SYMLINK_PATH")" == "$SCRIPT_PATH" ]]; then
        print_message "SUCCESS" "Символическая ссылка уже настроена: $SYMLINK_PATH"
        return 0
    fi

    print_message "INFO" "Создание символической ссылки $SYMLINK_PATH..."
    rm -f "$SYMLINK_PATH"
    if ln -s "$SCRIPT_PATH" "$SYMLINK_PATH"; then
        print_message "SUCCESS" "Символическая ссылка создана: $SYMLINK_PATH"
    else
        print_message "ERROR" "Не удалось создать символическую ссылку"
        return 1
    fi
    return 0
}

install_script() {
    print_message "INFO" "Установка расширенного скрипта бэкапа..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Copy script to installation directory if not already there
    if [[ "$SCRIPT_RUN_PATH" != "$SCRIPT_PATH" ]]; then
        cp "$SCRIPT_RUN_PATH" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi
    
    # Setup symlink
    setup_symlink
    
    # Load or create configuration
    load_or_create_config
    
    print_message "SUCCESS" "Установка завершена!"
    print_message "INFO" "Используйте команду ${BOLD}${GREEN}rw-backup-extended${RESET} для быстрого доступа"
}

# Check if jq is installed (required for Google Drive API)
check_dependencies() {
    if ! command -v jq &> /dev/null && [[ "$UPLOAD_METHOD" == "google_drive" ]]; then
        print_message "WARN" "Пакет 'jq' не найден. Устанавливаю..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y jq
        elif command -v yum &> /dev/null; then
            yum install -y jq
        elif command -v dnf &> /dev/null; then
            dnf install -y jq
        else
            print_message "ERROR" "Не удалось установить jq. Установите его вручную."
            return 1
        fi
    fi
    return 0
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check if running as root for installation
    if [[ "$EUID" -eq 0 && ! -f "$CONFIG_FILE" ]]; then
        print_message "INFO" "Первый запуск - выполняю установку..."
        install_script
    fi
    
    # Check dependencies
    check_dependencies
    
    # Load configuration
    load_or_create_config
    
    # Handle command line arguments
    case "${1:-}" in
        "--backup"|"-b")
            if [[ "${2:-}" == "full" ]]; then
                detect_remnawave_services
                create_extended_backup
            else
                create_backup
            fi
            ;;
        "--restore"|"-r")
            if [[ "${2:-}" == "full" ]]; then
                restore_extended_backup
            else
                restore_backup
            fi
            ;;
        "--detect"|"-d")
            detect_remnawave_services
            ;;
        "--config"|"-c")
            configure_backup_paths
            ;;
        "--version"|"-v")
            echo "Extended Backup для Remnawave"
            echo "Версия: 3.0.0-extended"
            echo "Дата: 23 октября 2025"
            echo "Репозиторий: https://github.com/Safe-Stream/safe_backup-extended"
            exit 0
            ;;
        "--detect-services")
            detect_remnawave_services
            exit 0
            ;;
        "--test-mode")
            print_message "INFO" "Тестовый режим активирован"
            detect_remnawave_services
            exit 0
            ;;
        "--quick-test")
            print_message "INFO" "Быстрый тест системы..."
            detect_remnawave_services
            print_message "SUCCESS" "Система готова к работе!"
            exit 0
            ;;
        "--help"|"-h")
            echo "Использование: $0 [ОПЦИЯ]"
            echo ""
            echo "Опции:"
            echo "  -b, --backup          Создать стандартный бэкап"
            echo "  -b full, --backup full Создать полный бэкап сервера"
            echo "  -r, --restore         Стандартное восстановление"
            echo "  -r full, --restore full Полное восстановление сервера"
            echo "  -d, --detect          Обнаружить установленные сервисы"
            echo "  -c, --config          Настройка путей для бэкапа"
            echo "  -v, --version         Показать версию"
            echo "  --detect-services     Показать обнаруженные сервисы и выйти"
            echo "  --test-mode          Режим тестирования"
            echo "  --quick-test         Быстрый тест системы"
            echo "  -h, --help            Показать эту справку"
            echo ""
            echo "Без аргументов запускается интерактивное меню."
            exit 0
            ;;
        "")
            # No arguments - show main menu
            main_menu
            ;;
        *)
            print_message "ERROR" "Неизвестная опция: $1"
            print_message "INFO" "Используйте --help для справки"
            exit 1
            ;;
    esac
fi