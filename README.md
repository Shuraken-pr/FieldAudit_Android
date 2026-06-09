# 📱 FieldAudit: Мобильный инспектор с офлайн-режимом

Native Android-приложение для сбора данных "в полях", разработанное на **Embarcadero Delphi 12 (FMX)**. Позволяет инспекторам фиксировать задачи, фотографировать объекты и привязывать координаты GPS без доступа к интернету. Данные хранятся локально и готовы к синхронизации с серверной аналитикой.

## ✨ Ключевые возможности
- 📋 **Локальный список задач** на базе SQLite (FireDAC LocalSQL)
- 📸 **Съёмка фото** через нативный API Android (`IFMXCameraService`) с автоматическим ресайзом и сохранением в БД
- 📍 **Геолокация в реальном времени** с отображением на карте
- 🗺️ **Гибридные карты**: интеграция Яндекс.Карт через `TWebBrowser` + JavaScript Bridge
- 🖼️ **Master-Detail просмотр**: выбор записи → просмотр фото в полноэкранном режиме
- 📡 **Offline-First архитектура**: полная работоспособность без сети

## 🏗️ Архитектура проекта
├── dmLocalDb.pas # DataModule: SQLite, FireDAC, CRUD-операции
├── frmMain.pas # UI: ListView, Camera Service, GPS, WebView, Photo Viewer
├── map.html # Яндекс.Карты API + JS-функции для взаимодействия с Delphi
├── AndroidManifest.template.xml # Кастомный манифест с правами и метаданными
└── assets/internal/ # (Deployment) map.html копируется в DocumentsPath

## 🛠️ Стек технологий
| Компонент | Назначение |
|-----------|------------|
| **Delphi 12 Athens** | Кроссплатформенная FMX-разработка |
| **FireDAC + SQLite** | Локальное хранение данных, офлайн-режим |
| **IFMXCameraService** | Прямой вызов системной камеры с контролем разрешения |
| **TLocationSensor** | Получение GPS/ГЛОНАСС координат в фоне |
| **TWebBrowser + JS** | Рендеринг Яндекс.Карт, `EvaluateJavaScript` для Native↔Web bridge |
| **Android SDK/NDK** | Сборка под Android 10+ (API 34, NDK 25.2) |

## 🚀 Запуск и настройка

### 1. Предварительные требования
- Embarcadero Delphi 11/12 с установленным **Android 64-bit SDK**
- Android NDK `r25c` (25.2.x) или новее
- JDK 17
- Установленные права доступа в `Project Options → Application → Uses Permissions`:
  - ✅ `Camera`
  - ✅ `Access Coarse Location`
  - ✅ `Access Fine Location`

### 2. Настройка карт
1. Получите бесплатный API-ключ для **JavaScript API Яндекс.Карт**: [developer.tech.yandex.ru](https://developer.tech.yandex.ru/)
2. Откройте файл `map.html` и замените `ВАШ_YANDEX_API_KEY` на полученный ключ:
   ```html
   <script src="https://api-maps.yandex.ru/2.1/?apikey=ВАШ_YANDEX_API_KEY&lang=ru_RU" type="text/javascript"></script>
   ```html
3. В Delphi: Project → Deployment → убедитесь, что map.html имеет Remote Path: assets\internal\
### 3. Сборка и деплой
- Подключите Android-устройство по USB (включите "Отладку по USB" и режим MTP)
- В IDE выберите платформу Android 64-bit
- Нажмите Project → Clean, затем Run (F9)
- При первом запуске разрешите приложению доступ к камере и геолокации
### 💡 Архитектурные решения для портфолио
- Ограничение разрешения камеры: RequiredResolution := TSize.Create(1024, 1024) предотвращает OutOfMemoryError на мобильных устройствах.
- Гибридный паттерн: Вместо привязки к TMapView (Google-only) реализован независимый слой карт через HTML/JS. Это упрощает замену провайдера и демонстрирует понимание Native-Web взаимодействия.
- Безопасное хранение: Все файлы сохраняются в TPath.GetDocumentsPath (приватная директория приложения), что соответствует современным требованиям Android 10+ Scoped Storage без лишних разрешений.
- Потокобезопасный UI: Все обновления интерфейса (ListView, Image) происходят в основном потоке, работа с БД и файловой системой изолирована.
### 🔮 Roadmap (Планы развития)
- REST-синхронизация с PostgreSQL-бэкендом (через TRESTClient)
- Оффлайн-очередь синхронизации с разрешением конфликтов
- Экспорт отчётов в PDF прямо на устройстве
- Фоновая синхронизация через Android WorkManager
### 📄 Лицензия
- MIT License. Свободно используйте для обучения и портфолио.