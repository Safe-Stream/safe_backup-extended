# 🛡️ Safe Stream - Remnawave Backup Extended

![Version](https://img.shields.io/badge/version-3.0.0--extended-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Shell](https://img.shields.io/badge/shell-bash-yellow)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)

**Расширенная система резервного копирования и восстановления для полной экосистемы Remnawave**

> [!IMPORTANT]
> **ЭТОТ СКРИПТ ВЫПОЛНЯЕТ ПОЛНОЕ РЕЗЕРВНОЕ КОПИРОВАНИЕ И ВОССТАНОВЛЕНИЕ ВСЕГО СЕРВЕРА REMNAWAVE, ВКЛЮЧАЯ ВСЕ ДОПОЛНИТЕЛЬНЫЕ СЕРВИСЫ, БАЗЫ ДАННЫХ, КОНФИГУРАЦИИ И SSL СЕРТИФИКАТЫ. ОБЕСПЕЧИВАЕТ ПОЛНУЮ МИГРАЦИЮ СЕРВЕРА НА НОВУЮ МАШИНУ ОДНОЙ КОМАНДОЙ.**

---

## 🚀 Быстрый старт

### Установка одной командой:
```bash
curl -o install.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/install.sh && chmod +x install.sh && sudo ./install.sh
```

### Создание полного бэкапа:
```bash
rw-backup-extended --backup full
```

### Полное восстановление на новом сервере:
```bash
# Установить скрипт
curl -o install.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/install.sh && chmod +x install.sh && sudo ./install.sh

# Загрузить файл бэкапа в /opt/rw-backup-restore/backup/

# Восстановить всё
rw-backup-extended --restore full
```

---

## 📦 Поддерживаемые сервисы

| Сервис | Описание | Поддержка |
|--------|----------|-----------|
| **remnawave** | Основная панель управления | ✅ Полная |
| **remnawave-db** | База данных PostgreSQL | ✅ Полная |
| **remnawave-redis** | Кэш Redis/Valkey | ✅ Полная |
| **remnawave-nginx** | Веб-сервер и прокси | ✅ Полная |
| **remnawave-subscription-page** | Страница подписки | ✅ Полная |
| **remnawave-telegram-mini-app** | Telegram мини-приложение | ✅ Полная |
| **remnawave-tg-shop** | Telegram бот магазина | ✅ Полная |
| **remnawave-tg-shop-db** | БД Telegram бота | ✅ Полная |

---

## 🎯 Что включает полный бэкап

### 🗄️ **Базы данных (с полным содержимым):**
- **remnawave-db** - пользователи, подписки, серверы, конфигурации панели
- **remnawave-tg-shop-db** - клиенты бота, заказы, платежи, настройки магазина

### 💾 **Кэш и сессии:**
- **Redis/Valkey данные** - активные сессии, временные данные, кэш

### 📁 **Код и файлы приложений (включая все тексты и переводы):**
- **Исходный код ботов** - Python файлы, handlers, utils, middleware
- **Локализации и переводы** - .po, .json, .yaml файлы с текстами на всех языках
- **Конфигурационные файлы** - .env, config.py, settings.json с токенами и настройками
- **Статические файлы** - изображения, документы, медиа, шаблоны HTML
- **Зависимости** - requirements.txt, poetry.lock, package.json
- **Шаблоны сообщений** - текстовые шаблоны, клавиатуры, inline-кнопки
- **Кастомные модули** - собственные библиотеки, плагины, расширения

### 🐳 **Docker инфраструктура:**
- **Compose конфигурации** - docker-compose.yml всех сервисов с настройками
- **Переменные окружения** - .env файлы с токенами, API ключами, паролями
- **Docker volumes** - постоянные данные контейнеров, загруженные файлы
- **Сетевые настройки** - Docker networks configuration, порты

### 🌐 **Веб-сервер и SSL:**
- **Nginx конфигурации** - proxy settings, upstream, locations, rate limiting
- **SSL сертификаты** - Let's Encrypt автосертификаты, пользовательские сертификаты
- **Статические сайты** - страница подписки, веб-интерфейсы, лендинги

### 📊 **Системная информация:**
- **Метаданные бэкапа** - дата создания, версии сервисов, размеры данных
- **Список контейнеров** - версии Docker образов, статус, конфигурация запуска

## ✨ Основные функции:

### 🔄 **Бэкап и восстановление:**
- **Полный бэкап сервера** - все сервисы, БД, конфигурации одной командой
- **Селективный бэкап** - только нужные компоненты
- **Полное восстановление** - развертывание всего сервера на новой машине
- **Автоопределение сервисов** - скрипт сам находит все установленные компоненты

### 📤 **Уведомления и отправка:**
- **Telegram уведомления** - статус операций прямо в бот или группу
- **Отправка бэкапов в Telegram** - файлы до 50MB автоматически
- **Google Drive интеграция** - загрузка больших бэкапов в облако
- **Поддержка топиков** - организованная отправка в группы Telegram

### ⚡ **Автоматизация:**
- **Интерактивное меню** - удобный интерфейс управления
- **Планировщик задач** - автоматические бэкапы по расписанию
- **Политика хранения** - автоочистка старых бэкапов (7 дней)
- **Быстрый доступ** - команда `rw-backup-extended` из любой точки системы

### 🛠️ **Управление:**
- **Настройка конфигурации** - гибкая настройка путей и исключений
- **Обновление скрипта** - автоматическая проверка и установка обновлений
- **Логирование** - детальные логи всех операций
- **Безопасность** - шифрование конфигов, проверка целостности

## 🔄 Полная миграция сервера

### На старом сервере:
```bash
# 1. Установка (если не установлено)
curl -o install.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/install.sh
chmod +x install.sh && sudo ./install.sh

# 2. Создание полного бэкапа
rw-backup-extended --backup full

# 3. Скачивание файла бэкапа
# Файл будет в /opt/rw-backup-restore/backup/remnawave_full_backup_*.tar.gz
```

### На новом сервере:
```bash
# 1. Базовая подготовка
sudo apt update && sudo apt upgrade -y

# 2. Установка скрипта
curl -o install.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/install.sh
chmod +x install.sh && sudo ./install.sh

# 3. Загрузка бэкапа
sudo cp /path/to/backup.tar.gz /opt/rw-backup-restore/backup/

# 4. Полное восстановление
rw-backup-extended --restore full
```

### Финальные настройки:
```bash
# 1. Изменить A-записи всех доменов на новый IP
# 2. Проверить статус сервисов
docker ps

# 3. Тестирование
# - Панель: https://panel.yourdomain.com
# - Магазин: https://shop.yourdomain.com  
# - Telegram бот: должен отвечать на команды
```

**⏱️ Время миграции: 15-60 минут**

## 📋 Команды

```bash
# Интерактивное меню
rw-backup-extended

# Создание бэкапов
rw-backup-extended --backup          # Стандартный (только Remnawave)
rw-backup-extended --backup full     # Полный (весь сервер)

# Восстановление
rw-backup-extended --restore         # Стандартное
rw-backup-extended --restore full    # Полное (весь сервер)

# Утилиты
rw-backup-extended --detect          # Обнаружение сервисов
rw-backup-extended --config          # Настройка путей
rw-backup-extended --help            # Справка
```

---

## 🛠️ Установка и настройка

### Системные требования:
- **ОС**: Ubuntu 18.04+, Debian 10+, CentOS 7+
- **RAM**: минимум 2GB, рекомендуется 4GB+
- **Место**: свободное место ≥ 2x размер данных
- **Права**: root доступ
- **Сеть**: доступ к интернету

### Первоначальная настройка:
1. **Telegram бот** - создайте в @BotFather
2. **Chat ID** - получите у @username_to_id_bot
3. **Пути Remnawave** - автоопределяются или настраиваются вручную
4. **Google Drive** (опционально) - для загрузки больших бэкапов

---

## 📂 Структура файлов

```
/opt/rw-backup-restore/
├── backup-restore-extended.sh    # Основной скрипт
├── config.env                    # Конфигурация
├── backup/                       # Папка с бэкапами
│   ├── remnawave_backup_*.tar.gz           # Стандартные бэкапы
│   └── remnawave_full_backup_*.tar.gz      # Полные бэкапы
└── logs/                         # Логи (будущая функция)
```

---

## 🔐 Безопасность

- ✅ **Шифрование конфигов** (chmod 600)
- ✅ **Проверка целостности** бэкапов
- ✅ **Безопасное хранение** API ключей
- ✅ **Детальное логирование** операций
- ✅ **Автоочистка** старых бэкапов (7 дней)

---

## 📈 Сравнение с оригиналом

| Функция | Оригинал | Safe Backup Extended |
|---------|----------|---------------------|
| Бэкап панели | ✅ | ✅ |
| Бэкап основной БД | ✅ | ✅ |
| Бэкап Telegram бота | ✅ | ✅ |
| **Бэкап всех БД** | ❌ | ✅ |
| **Бэкап Redis данных** | ❌ | ✅ |
| **Бэкап Docker volumes** | ❌ | ✅ |
| **Бэкап Nginx конфигов** | ❌ | ✅ |
| **Бэкап SSL сертификатов** | ❌ | ✅ |
| **Полная миграция сервера** | ❌ | ✅ |
| **Автоустановка Docker** | ❌ | ✅ |
| **Автоопределение сервисов** | ❌ | ✅ |

---

## 📄 Документация

- 📖 **[Руководство по миграции](MIGRATION_GUIDE.md)** - Пошаговые инструкции
- 📋 **[Расширенный README](README_EXTENDED.md)** - Подробная документация
- 🚀 **[Быстрый старт](install.sh)** - Автоматический установщик

---

## 🆘 Поддержка

### Возникли проблемы?

1. **Проверьте логи**:
   ```bash
   docker logs remnawave
   docker logs remnawave-nginx
   ```

2. **Проверьте статус сервисов**:
   ```bash
   docker ps
   systemctl status docker
   ```

3. **Создайте Issue**: [GitHub Issues](https://github.com/Safe-Stream/safe_backup-extended/issues)

### Частые проблемы:

**Docker не запускается:**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

**Сервисы не восстанавливаются:**
```bash
cd /opt/remnawave  # ваш путь
docker-compose down && docker-compose up -d
```

**SSL не работает:**
```bash
sudo certbot renew --force-renewal
```

---

## ⚖️ Лицензия

MIT License - использование на ваш страх и риск.

> **⚠️ Важно**: Всегда тестируйте процедуру восстановления на тестовом окружении!

---

*Создано командой Safe Stream для сообщества Remnawave* 🚀
