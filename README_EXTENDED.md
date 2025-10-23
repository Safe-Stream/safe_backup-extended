# 🚀 Remnawave Full Server Backup & Restore (Extended)

Расширенная версия скрипта резервного копирования и восстановления для полной экосистемы Remnawave, включая все дополнительные сервисы и компоненты.

![Version](https://img.shields.io/badge/version-3.0.0--extended-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Shell](https://img.shields.io/badge/shell-bash-yellow)

## 🌟 Особенности расширенной версии

### 🔄 **Полный бэкап сервера:**
- **Все базы данных**: remnawave-db, remnawave-tg-shop-db
- **Redis/Valkey данные**: полное сохранение кэша и сессий
- **Docker конфигурации**: все docker-compose.yml файлы и .env настройки
- **Docker Volumes**: данные всех контейнеров
- **Nginx конфигурации**: системные и контейнерные настройки
- **SSL сертификаты**: Let's Encrypt и пользовательские сертификаты
- **Приложения**: все директории с кодом и конфигурациями

### 📦 **Поддерживаемые сервисы:**
- ✅ **remnawave** - основная панель управления
- ✅ **remnawave-db** - база данных PostgreSQL
- ✅ **remnawave-redis** - кэш Redis/Valkey
- ✅ **remnawave-nginx** - веб-сервер и прокси
- ✅ **remnawave-subscription-page** - страница подписки
- ✅ **remnawave-telegram-mini-app** - мини-приложение Telegram
- ✅ **remnawave-tg-shop** - Telegram бот магазина
- ✅ **remnawave-tg-shop-db** - БД Telegram бота

### 🎯 **Новые функции:**
- 🔍 **Автоопределение сервисов** - автоматическое обнаружение всех установленных компонентов
- ⚡ **Полная миграция** - перенос всего сервера на новую машину одной командой
- 🛠️ **Гибкая настройка** - настройка путей бэкапа и исключений
- 📊 **Детальные логи** - подробная информация о процессе бэкапа и восстановления
- 💾 **Умное сжатие** - оптимизированное сжатие с исключением временных файлов

---

## 🚀 Быстрый старт

### Установка:
```bash
# Быстрая установка через установщик
curl -o install.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

### Альтернативная установка:
```bash
# Прямая загрузка основного скрипта
curl -o backup-restore-extended.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/backup-restore-extended.sh
chmod +x backup-restore-extended.sh
sudo ./backup-restore-extended.sh
```

### Быстрый доступ:
```bash
rw-backup-extended  # Интерактивное меню
```

### Командная строка:
```bash
# Полный бэкап сервера
rw-backup-extended --backup full

# Стандартный бэкап (только Remnawave)
rw-backup-extended --backup

# Полное восстановление
rw-backup-extended --restore full

# Обнаружение сервисов
rw-backup-extended --detect
```

---

## 📋 Сравнение версий

| Функция | Стандартная версия | Расширенная версия |
|---------|-------------------|-------------------|
| Бэкап основной панели | ✅ | ✅ |
| Бэкап основной БД | ✅ | ✅ |
| Бэкап Telegram бота | ✅ | ✅ |
| Бэкап всех БД | ❌ | ✅ |
| Бэкап Redis данных | ❌ | ✅ |
| Бэкап Docker volumes | ❌ | ✅ |
| Бэкап Nginx конфигов | ❌ | ✅ |
| Бэкап SSL сертификатов | ❌ | ✅ |
| Бэкап всех сервисов | ❌ | ✅ |
| Автоопределение сервисов | ❌ | ✅ |
| Полная миграция сервера | ❌ | ✅ |
| Автоустановка Docker | ❌ | ✅ |

---

## 🔧 Конфигурация

### Автоматическая настройка:
Скрипт автоматически обнаружит:
- Запущенные Docker контейнеры
- Пути к docker-compose файлам  
- Nginx конфигурации
- SSL сертификаты
- Пользовательские директории

### Ручная настройка:
```bash
rw-backup-extended --config
```

Настройте:
- Пути к конфигурациям
- Исключения для бэкапа
- Дополнительные директории
- Telegram уведомления
- Google Drive загрузку

---

## 📂 Структура бэкапа

```
remnawave_full_backup_2025-10-21_14_30_15.tar.gz
├── backup_metadata.txt          # Информация о бэкапе
├── databases/
│   ├── remnawave_db_*.sql.gz   # Основная БД
│   └── tg_shop_db_*.sql.gz     # БД Telegram бота
├── redis/
│   └── redis_dump_*.rdb        # Redis данные
├── docker/
│   ├── remnawave_config_*.tar.gz      # Docker Compose конфиги
│   └── volumes/
│       ├── volume1_*.tar.gz    # Docker volumes
│       └── volume2_*.tar.gz
├── nginx/
│   ├── container_nginx_*       # Nginx из контейнера
│   └── system_nginx_*.tar.gz   # Системные конфиги
├── ssl/
│   └── ssl_letsencrypt_*.tar.gz # SSL сертификаты
└── applications/
    ├── remnawave_main_*.tar.gz  # Основная панель
    └── custom_*.tar.gz          # Доп. приложения
```

---

## 🔄 Процесс полной миграции

### 1. На старом сервере:
```bash
# Создание полного бэкапа
rw-backup-extended --backup full
```

### 2. На новом сервере:
```bash
# Установка скрипта
curl -o install.sh https://raw.githubusercontent.com/Safe-Stream/safe_backup-extended/main/install.sh
chmod +x install.sh
sudo ./install.sh

# Загрузка файла бэкапа в /opt/rw-backup-restore/backup/

# Полное восстановление
rw-backup-extended --restore full
```

### 3. Финальные настройки:
- Изменить A-записи доменов
- Настроить firewall
- Проверить работу сервисов

**Время миграции: 15-60 минут** (в зависимости от размера данных)

---

## 📤 Методы отправки

### Telegram бот:
- Уведомления о статусе
- Отправка файлов бэкапа (до 50MB)
- Поддержка топиков в группах

### Google Drive:
- Автоматическая загрузка
- Организация по папкам
- Неограниченный размер файлов

---

## 🛡️ Безопасность

- ✅ Шифрование конфигурационных файлов (chmod 600)
- ✅ Проверка целостности бэкапов
- ✅ Безопасное хранение API ключей
- ✅ Логирование всех операций
- ✅ Автоочистка старых бэкапов

---

## 🔍 Устранение проблем

### Проверка статуса сервисов:
```bash
docker ps  # Статус всех контейнеров
docker logs remnawave  # Логи панели
docker logs remnawave-nginx  # Логи веб-сервера
```

### Ручной запуск сервисов:
```bash
cd /opt/remnawave  # или ваш путь
docker-compose down
docker-compose up -d
```

### Проблемы с SSL:
```bash
sudo certbot renew --force-renewal
sudo systemctl reload nginx
```

---

## 📊 Системные требования

- **ОС**: Ubuntu 18.04+, Debian 10+, CentOS 7+
- **RAM**: минимум 2GB (рекомендуется 4GB+)
- **Место**: свободное место = 2x размер данных
- **Права**: root доступ для установки
- **Сеть**: доступ к Docker Hub и репозиториям

---

## 🤝 Совместимость

| Remnawave версия | Поддержка |
|-----------------|-----------|
| 2.0+ | ✅ Полная |
| 1.x | ⚠️ Частичная |

| Docker версия | Поддержка |
|--------------|-----------|
| 20.0+ | ✅ Полная |
| 19.x | ⚠️ Базовая |

---

## 📝 Changelog

### v3.0.0-extended
- ✨ Добавлен полный бэкап всех сервисов
- ✨ Автоопределение установленных компонентов
- ✨ Поддержка Docker volumes
- ✨ Бэкап Nginx и SSL конфигураций
- ✨ Полная миграция сервера
- ✨ Улучшенное логирование
- 🔧 Гибкая настройка путей бэкапа
- 🐛 Исправлены проблемы с восстановлением Redis

---

## 📞 Поддержка

- 📖 **Документация**: [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
- 🐛 **Issues**: [GitHub Issues](https://github.com/Safe-Stream/safe_backup-extended/issues)
- � **Репозиторий**: [safe_backup-extended](https://github.com/Safe-Stream/safe_backup-extended)

---

## ⚖️ Лицензия

MIT License - использование на ваш страх и риск.

> **⚠️ Важно**: Всегда тестируйте восстановление на тестовом сервере перед применением в продакшене!