# Инструкция по полной миграции сервера Remnawave

## 🚀 Подготовка к миграции

### На старом сервере:

1. **Установка расширенного скрипта бэкапа:**
   
   > **💡 Совместимость**: Если у вас уже установлен оригинальный скрипт бэкапа, расширенная версия может работать рядом с ним или импортировать существующие настройки.
   
   **Быстрая установка одной командой:**
   ```bash
   curl -o install.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/install.sh && chmod +x install.sh && sudo ./install.sh
   ```
   
   **Или пошагово:**
   ```bash
   # Скачать установщик
   curl -o install.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/install.sh
   
   # Сделать исполняемым
   chmod +x install.sh
   
   # Запустить установку с правами root
   sudo ./install.sh
   ```
   
   **При обнаружении оригинального скрипта вам будет предложено:**
   - ✅ **Установить рядом** (рекомендуется) - оба скрипта будут доступны
   - 🔄 **Заменить с резервированием** - создать бэкап оригинала и заменить
   - ❌ **Отменить установку**
   
   **Команды после установки:**
   - `rw-backup` - оригинальный скрипт (если оставлен)
   - `rw-backup-extended` - расширенная версия

2. **Создание полного бэкапа:**
   - Запустите скрипт: `rw-backup-extended`
   - Выберите пункт "1. Создание полного бэкапа сервера"
   - Скрипт автоматически обнаружит и заархивирует:
     - Все базы данных (remnawave-db, remnawave-tg-shop-db)
     - Redis/Valkey данные
     - Docker Compose конфигурации
     - Nginx настройки
     - SSL сертификаты
     - Все директории приложений

3. **Скачивание бэкапа:**
   - Бэкап будет сохранен в `/opt/rw-backup-restore/backup/`
   - Скачайте файл `remnawave_full_backup_YYYY-MM-DD_HH_MM_SS.tar.gz`

---

## 🔧 Настройка нового сервера

### На новом сервере:

1. **Базовая подготовка:**
   ```bash
   # Обновление системы
   sudo apt update && sudo apt upgrade -y
   
   # Установка необходимых пакетов
   sudo apt install -y curl wget git ufw
   ```

2. **Установка Docker (рекомендуется сделать заранее):**
   ```bash
   # Установка Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo systemctl enable docker
   sudo systemctl start docker
   
   # Добавление пользователя в группу docker (опционально)
   sudo usermod -aG docker $USER
   ```

3. **Предварительная настройка SSL (рекомендуется):**
   ```bash
   # Установка Certbot
   sudo snap install --classic certbot
   sudo ln -s /snap/bin/certbot /usr/bin/certbot
   
   # ВАЖНО: Сначала направьте домены на новый сервер!
   # Затем получите сертификаты:
   sudo certbot --nginx -d panel.yourdomain.com -d api.yourdomain.com -d shop.yourdomain.com
   ```

4. **Установка расширенного скрипта:**
   
   **Быстрая установка:**
   ```bash
   curl -o install.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/install.sh && chmod +x install.sh && sudo ./install.sh
   ```
   
   **Что происходит:**
   - Скачивается установщик с GitHub
   - Получает права на выполнение
   - Запускается с правами администратора

5. **Загрузка бэкапа на новый сервер:**
   ```bash
   # Создайте директорию для бэкапов
   sudo mkdir -p /opt/rw-backup-restore/backup
   
   # Загрузите файл бэкапа в эту директорию  
   sudo cp /path/to/remnawave_full_backup_*.tar.gz /opt/rw-backup-restore/backup/
   ```

---

## 📦 Процесс восстановления

### Запуск восстановления:

1. **Запустите скрипт восстановления:**
   ```bash
   rw-backup-extended
   ```

2. **Выберите пункт "2. Полное восстановление сервера"**

3. **Процесс восстановления включает:**
   - ✅ Автоматическую установку Docker (если не установлен)
   - ✅ Восстановление всех Docker Compose конфигураций
   - ✅ Восстановление всех баз данных
   - ✅ Восстановление Redis данных
   - ✅ Восстановление Nginx конфигураций
   - ✅ Восстановление SSL сертификатов
   - ✅ Восстановление всех приложений
   - ✅ Автоматический запуск всех сервисов

---

## 🌐 Финальные настройки

### После успешного восстановления:

1. **Изменение DNS записей:**
   - Зайдите в панель управления доменом (например, Cloudflare)
   - Измените A-записи всех поддоменов на IP нового сервера:
     - `panel.yourdomain.com` → новый IP
     - `api.yourdomain.com` → новый IP
     - `shop.yourdomain.com` → новый IP
     - И другие поддомены

2. **Настройка Firewall:**
   ```bash
   # Основные порты
   sudo ufw allow 22/tcp       # SSH
   sudo ufw allow 80/tcp       # HTTP
   sudo ufw allow 443/tcp      # HTTPS
   sudo ufw allow 2222/tcp     # Remnawave API (если нужен внешний доступ)
   
   # Включение firewall
   sudo ufw --force enable
   ```

3. **Проверка статуса сервисов:**
   ```bash
   docker ps
   ```
   
   Должны быть запущены все контейнеры:
   - remnawave
   - remnawave-db
   - remnawave-redis
   - remnawave-nginx
   - remnawave-subscription-page
   - remnawave-telegram-mini-app
   - remnawave-tg-shop
   - remnawave-tg-shop-db

4. **Проверка работы сервисов:**
   - Панель управления: `https://panel.yourdomain.com`
   - Страница подписки: `https://shop.yourdomain.com`
   - Telegram бот: должен отвечать на команды

---

## 🔧 Дополнительные настройки

### SSL сертификаты:

**Рекомендуемый подход - получить новые сертификаты:**
```bash
# 1. Сначала направьте все домены на новый сервер
# 2. Дождитесь обновления DNS (можно проверить: nslookup panel.yourdomain.com)
# 3. Получите новые сертификаты:
sudo certbot --nginx -d panel.yourdomain.com -d api.yourdomain.com -d shop.yourdomain.com

# Настройка автообновления
sudo crontab -e
# Добавьте строку: 0 12 * * * /usr/bin/certbot renew --quiet
```

**Если восстанавливали из бэкапа и сертификаты не работают:**
```bash
# Принудительное обновление сертификатов
sudo certbot renew --force-renewal

# Перезагрузка Nginx
sudo systemctl reload nginx
# или для Docker:
docker restart remnawave-nginx
```

### Настройка Telegram ботов:

**Проверка настроек бота:**
```bash
# Проверка логов бота
docker logs remnawave-tg-shop

# Проверка переменных окружения
docker exec remnawave-tg-shop env | grep -E "(BOT_TOKEN|API)"

# Тест бота - отправьте команду /start в Telegram
```

**Если бот не отвечает:**
```bash
# Проверка соединения с Telegram API
curl -s "https://api.telegram.org/bot<ВАШ_TOKEN>/getMe"

# Перезапуск бота
docker restart remnawave-tg-shop

# Проверка базы данных бота
docker exec -it remnawave-tg-shop-db psql -U postgres -c "\dt"
```

### Настройка логов:

```bash
# Проверка логов сервисов
docker logs remnawave
docker logs remnawave-nginx
docker logs remnawave-tg-shop
```

### Обновление внешних нод:

Если у вас есть внешние ноды, обновите правила firewall на каждой ноде:
```bash
# На каждой внешней ноде
sudo ufw delete allow from OLD_SERVER_IP to any port 2222
sudo ufw allow from NEW_SERVER_IP to any port 2222
```

---

## 📋 Контрольный список миграции

- [ ] Создан полный бэкап на старом сервере
- [ ] Скачан файл бэкапа
- [ ] Подготовлен новый сервер
- [ ] Установлен расширенный скрипт
- [ ] Загружен файл бэкапа на новый сервер
- [ ] Выполнено полное восстановление
- [ ] Изменены DNS записи
- [ ] Настроен firewall
- [ ] Проверена работа всех сервисов
- [ ] Обновлены внешние ноды (если есть)
- [ ] Проверены SSL сертификаты
- [ ] Протестирована работа Telegram бота
- [ ] Протестирована страница подписки

---

## ⚠️ Важные моменты

1. **Время простоя:** Миграция займет от 15 до 60 минут в зависимости от размера данных
2. **Backup:** Обязательно сохраните файл бэкапа в надежном месте
3. **DNS propagation:** Изменения DNS могут распространяться до 24 часов
4. **Testing:** После миграции протестируйте все функции
5. **Monitoring:** Следите за логами в первые дни после миграции

---

## 🆘 Устранение проблем

### Если сервисы не запускаются:
```bash
# Проверка Docker
sudo systemctl status docker
sudo systemctl start docker

# Перезапуск сервисов
cd /opt/remnawave  # или ваш путь к compose файлам
docker-compose down
docker-compose up -d
```

### Если база данных не восстанавливается:
```bash
# Проверка контейнеров БД
docker logs remnawave-db
docker logs remnawave-tg-shop-db

# Ручное восстановление (если нужно)
zcat backup_file.sql.gz | docker exec -i remnawave-db psql -U postgres
```

### Если SSL не работает:
```bash
# Проверка Nginx
docker logs remnawave-nginx

# Перегенерация сертификатов
sudo certbot --nginx --force-renewal
```

Этот процесс обеспечит полную миграцию вашего Remnawave сервера с сохранением всех настроек, данных и конфигураций!

---

## 🔄 Совместность с оригинальным скриптом

### Если у вас установлены оба скрипта:

**Оригинальный скрипт (стандартный бэкап):**
```bash
rw-backup                    # Интерактивное меню
/opt/rw-backup-restore/      # Директория
```

**Расширенный скрипт (полный бэкап сервера):**  
```bash
rw-backup-extended           # Интерактивное меню
/opt/rw-backup-restore/      # Та же директория (совместно)
```

### Общие ресурсы:
- ✅ **Папка с бэкапами**: `/opt/rw-backup-restore/backup/` - используется обоими
- ✅ **Настройки Telegram**: импортируются из оригинального скрипта
- ✅ **Существующие бэкапы**: остаются доступными для восстановления

### Рекомендации:
1. **Для ежедневных бэкапов**: используйте `rw-backup-extended --backup full`
2. **Для миграции серверов**: используйте `rw-backup-extended --restore full`  
3. **Старые бэкапы**: можно восстанавливать любым из скриптов
4. **Автоматизация**: настройте расписание в расширенной версии

### Удаление оригинального скрипта (если не нужен):
```bash
# Резервная копия создается автоматически при замене
# Найти: /opt/rw-backup-restore-original-YYYYMMDD-HHMMSS/

# Ручное удаление (если нужно):
sudo rm -f /usr/local/bin/rw-backup
```