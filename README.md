# 📱 FieldAudit: Мобильный инспектор с офлайн-режимом

Native Android-приложение для сбора данных "в полях", разработанное на **Embarcadero Delphi 12 (FMX)**. Позволяет инспекторам фиксировать задачи, фотографировать объекты и привязывать координаты GPS без доступа к интернету. Данные хранятся локально и синхронизируются с сервером через защищенный REST API.

## ✨ Ключевые возможности

- 📋 **Локальный список задач** на базе SQLite (FireDAC LocalSQL).
- 📸 **Съёмка фото** через нативный API Android (`IFMXCameraService`) с автоматическим ресайзом.
- 📍 **Геолокация в реальном времени** с отображением на карте.
- 🗺️ **Гибридные карты**: интеграция Яндекс.Карт через `TWebBrowser` + JavaScript Bridge.
- 🔄 **Offline-First синхронизация**: надежная отправка накопленных данных на сервер при появлении сети.
- 🔐 **Сессионная аутентификация с user_id**: безопасный вход по логину/паролю с получением временного токена (GUID) и user_id сервера (Int64).
- 📡 **Graceful Degradation**: автоматический возврат к экрану входа при истечении сессии (401 Unauthorized).
- 🔒 **HTTPS с самоподписанными сертификатами**: поддержка работы с серверами, использующими Nginx Reverse Proxy.

---

## 🏗️ Архитектура проекта

```text
Android_Delphi/
├── dmLocalDb.pas                  # DataModule: SQLite (FireDAC), CRUD-операции, шифрование SQLCipher
├── frmMain.pas                    # UI: ListView, Camera, GPS, WebView, HTTP-синхронизация, загрузка фото, проверка PIN
├── frmPhotoView.pas               # Полноэкранный просмотр фото
├── uLogin.pas                     # UI и логика входа, запрос токена у сервера
├── SessionManager.pas             # Глобальное хранилище токена, user_id (Int64), URL сервера и пароля БД в памяти
├── DatabaseKeyManager.pas         # Ключевой менеджер: вывод пароля БД из PIN + DeviceID + Salt (SHA-256)
├── frmSetPIN.pas                  # Форма первичной установки PIN-кода (4–6 цифр)
├── frmEnterPIN.pas              # Форма ввода PIN для разблокировки зашифрованной базы
├── JpegUtils.pas                  # Сжатие фото перед отправкой (ресайз до 1920px + качество 85%)
├── map.html                       # Яндекс.Карты API + JS-функции для Native↔Web bridge
├── network_security_config.xml    # Конфигурация безопасности сети (разрешение самоподписанных сертификатов)
└── AndroidManifest.template.xml   # Кастомный манифест с правами и networkSecurityConfig
```

---

## 🛠️ Стек технологий

| Компонент | Назначение |
| :--- | :--- |
| **Delphi 12 Athens** | Кроссплатформенная FMX-разработка |
| **FireDAC + SQLite** | Локальное хранение данных, офлайн-режим |
| **Application-level encryption** | Шифрование чувствительных полей (title, description) через SHA-256 stream cipher + XOR, привязка к PIN и устройству |
| **System.Net.HttpClient (THTTPClient)** | Нативный HTTP-клиент Android для взаимодействия с сервером |
| **System.Net.URLClient** | Работа с URL и сетевыми запросами |
| **IFMXCameraService** | Прямой вызов системной камеры с контролем разрешения |
| **TLocationSensor** | Получение GPS/ГЛОНАСС координат |
| **TWebBrowser + JS** | Рендеринг Яндекс.Карт, `EvaluateJavaScript` для Native↔Web bridge |
| **Network Security Config** | Android-механизм для доверия самоподписанным сертификатам |

---

## 🚀 Запуск и настройка

### 1. Предварительные требования
- Embarcadero Delphi 11/12 с установленным **Android 64-bit SDK**.
- Android NDK `r25c` (25.2.x) или новее, JDK 17.
- Развернутый и запущенный бэкенд **DataSnapServer** с настроенным **Nginx Reverse Proxy** (см. соответствующий репозиторий).
- Права доступа в `Project Options → Application → Uses Permissions`:
  - ✅ `Camera`
  - ✅ `Access Coarse Location`
  - ✅ `Access Fine Location`
  - ✅ `Internet` (для синхронизации)

### 2. Настройка карт и сервера
1. **Карты**: Получите API-ключ **Яндекс.Карт**, откройте `map.html` и замените `ВАШ_YANDEX_API_KEY`.
2. **Сервер**: В модуле `SessionManager.pas` укажите актуальный URL вашего сервера (по умолчанию `https://192.168.1.113`). URL должен начинаться с `https://`, так как сервер работает через Nginx с SSL-терминацией.

### 3. Настройка Network Security Config

Файл `network_security_config.xml` уже настроен для работы с самоподписанными сертификатами:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchor>
            <certificates src="user"/>
            <certificates src="system"/>
        </trust-anchor>
    </base-config>
</network-security-config>
```

Этот файл автоматически включается в APK через **Project → Deployment** (Remote Path: `res\xml\`).

### 4. Сборка и деплой
- Подключите Android-устройство по USB (включите "Отладку по USB").
- В IDE выберите платформу Android 64-bit.
- Нажмите `Project → Clean`, затем `Run` (F9).
- При первом запуске разрешите доступ к камере и геолокации.
- **Войдите в систему**, используя учетные данные, созданные в PostgreSQL на сервере.

---

### Защита локальных данных (Application-level encryption + PIN-код)
Приложение использует **Application-level encryption** — шифрование чувствительных полей (title, description) на уровне приложения, а не на уровне базы данных. Это позволяет защитить данные без зависимости от нативных библиотек SQLCipher, которые не поддерживаются FireDAC на Android из коробки.

**Как это работает:**
1. **Первый запуск** — пользователь устанавливает PIN через форму `frmSetPIN`.
2. **Производный ключ** — `DatabaseKeyManager.GetFieldKey` вычисляет ключ шифрования по формуле: `SHA-256(PIN + DeviceID + Salt + 'FIELD_ENCRYPT')`, где:
   - **DeviceID** — ANDROID_ID устройства (Android) или имя компьютера (Windows).
   - **Salt** — случайное 16-символьное значение, генерируемое при первой установке PIN и хранящееся в Android SharedPreferences под ключом `pin_salt` (или в файле `fieldaudit_salt.txt` на Windows).
   - **DeviceID** — `ANDROID_ID` устройства (Android) или имя компьютера (Windows). Использование `ANDROID_ID` вместо IMEI обязательно на Android 10+, где доступ к IMEI запрещён для сторонних приложений.
3. **Шифрование при записи** — при создании аудит-записи поля `title` и `description` шифруются через `DatabaseKeyManager.EncryptField` перед записью в SQLite.
4. **Дешифрование при чтении** — при отображении списка задач (`LoadTasks`) и синхронизации (`acSynchronizeExecute`) поля расшифровываются через `DatabaseKeyManager.DecryptField`.
5. **PIN в памяти** — введённый PIN сохраняется только в оперативной памяти (`DatabaseKeyManager.FCurrentPIN`) и сбрасывается при выходе из приложения. Salt сохраняется на диск один раз при первой установке PIN и не меняется при последующих входах.

**Алгоритм шифрования:**
Stream cipher на основе SHA-256 (keystream + XOR). Реализован кроссплатформенно (Android + Windows), не требует нативных библиотек:
- Каждый блок из 32 байт генерируется как `SHA-256(Key + Counter)`
- Данные шифруются через XOR с keystream
- Результат кодируется в Base64 с префиксом `ENC:`
- Обратно совместим: незашифрованные данные (без префикса `ENC:`) возвращаются как есть

> ✅ **Протестировано на Android:** PIN-код защищает доступ к приложению, данные в SQLite зашифрованы, при чтении расшифровываются корректно, синхронизация с сервером работает (поля отправляются в plaintext, как ожидает сервер).

**Безопасность:**
- PIN нигде не хранится в открытом виде — хранится только его SHA-256 хеш (вместе с Salt).
- Ключ шифрования никогда не сохраняется на диск — только в памяти процесса.
- Привязка к DeviceID означает, что скопированная база данных на другое устройство не расшифруется даже с правильным PIN.
- Для production рекомендуется заменить на AES-256 через встроенный Android Keystore (JNI) или нативную библиотеку SQLCipher.

```pascal
// Пример из DatabaseKeyManager.pas
class function TDatabaseKeyManager.EncryptField(const PlainText: string): string;
var
  Key: string;
  KeyBytes, PlainBytes, ResultBytes: TBytes;
  I, Counter: Integer;
  Hash: THashSHA2;
  BlockHash: TBytes;
begin
  Key := GetFieldKey;  // SHA-256(PIN + DeviceID + Salt + 'FIELD_ENCRYPT')
  KeyBytes := TNetEncoding.Base64.DecodeStringToBytes(Key);
  PlainBytes := TEncoding.UTF8.GetBytes(PlainText);
  SetLength(ResultBytes, Length(PlainBytes));
  Counter := 0;
  for I := 0 to Length(PlainBytes) - 1 do
  begin
    if I mod 32 = 0 then
    begin
      Hash := THashSHA2.Create;
      Hash.Update(KeyBytes);
      Hash.Update(TEncoding.UTF8.GetBytes(IntToStr(Counter)));
      BlockHash := Hash.HashAsBytes;
      Inc(Counter);
    end;
    ResultBytes[I] := PlainBytes[I] xor BlockHash[I mod 32];
  end;
  Result := 'ENC:' + TNetEncoding.Base64.EncodeBytesToString(ResultBytes);
end;
```

---

## 💡 Архитектурные решения

### Асинхронный UI (Callback Pattern)
Вместо блокирующего `ShowModal` для экрана входа используется анонимный метод (`TProc` callback). Это единственный корректный способ работы с асинхронным UI в FireMonkey под Android, позволяющий автоматически возобновить прерванную синхронизацию после успешного входа.

```pascal
// Пример использования в frmMain.pas
frmLogin.OnLoginSuccess := procedure
begin
  acSynchronize.Execute; // Автоматический перезапуск после входа
end;
frmLogin.Show;
```

### Безопасное хранение токена
Токен сессии хранится только в оперативной памяти (`SessionManager`). При закрытии приложения он уничтожается, что исключает его кражу через файловую систему Android.

### Совместимость с bcrypt-аутентификацией
Клиент работает с сервером, который использует bcrypt-хеширование паролей (через `pgcrypto` PostgreSQL). При входе в систему:
1. Клиент отправляет username и password на endpoint `/Login`
2. Сервер проверяет пароль через `crypt(password, password_hash) = password_hash`
3. При успехе возвращается временный токен (GUID) и `user_id`
4. Клиент использует токен для последующих запросов через заголовок `X-Session-Token`

**Важно:** Клиент не хранит пароли — только временные токены в памяти.

### Оптимизация камеры
`RequiredResolution := TSize.Create(1024, 1024)` предотвращает `OutOfMemoryError` при съемке на камеры с высоким разрешением.

### Обработка самоподписанных сертификатов
Для работы с сервером, использующим самоподписанный сертификат (например, через Nginx), реализован двухуровневый механизм:

1. **Network Security Config** (`network_security_config.xml`): Разрешает Android доверять пользовательским сертификатам на уровне системы.
2. **ValidateCert** (в `uLogin.pas` и `frmMain.pas`): Программный обработчик `OnValidateServerCertificate` с `Accepted := True` для полного обхода проверки.

```pascal
procedure TfrmLogin.ValidateCert(const Sender: TObject; const ARequest: TURLRequest;
  const Certificate: TCertificate; var Accepted: Boolean);
begin
  Accepted := True; // Принимаем самоподписанный сертификат
end;
```

### Надежная обработка ошибок 401
Реализована автоматическая обработка истечения сессии:
1. При получении HTTP 401 токен очищается (`AppSession.Logout`).
2. Показывается форма входа.
3. После успешного входа автоматически возобновляется прерванная операция синхронизации.

### Гибридный паттерн карт
Независимый слой карт через HTML/JS упрощает замену провайдера и демонстрирует понимание Native-Web взаимодействия.

### Загрузка фотографий
Перед отправкой на сервер фотографии автоматически сжимаются через `JpegUtils.pas`:
- Максимальная ширина: 1920 пикселей
- Качество JPEG: 85%
- Пропорции сохраняются

Это уменьшает размер файла в 3-5 раз, что критично для мобильной сети.

```pascal
// Пример из frmMain.pas
// Content-Type устанавливается через CustomHeaders (корректно для THTTPClient)
HTTP.CustomHeaders['Content-Type'] := 'application/json';
HTTP.CustomHeaders['X-Session-Token'] := AppSession.Token;
if CompressPhoto(PhotoPath, CompressedPath, 1920, 85) then
  PhotoBytes := TFile.ReadAllBytes(CompressedPath)
else
  PhotoBytes := TFile.ReadAllBytes(PhotoPath);
```

Сжатое фото кодируется в Base64 и отправляется в JSON-запросе на endpoint `/upload` сервера.

---

## 🌐 Архитектура взаимодействия с сервером

Приложение работает с сервером через **Nginx Reverse Proxy** в локальной сети:

### Nginx + HTTP (локальная сеть)

```
[Android] --HTTP:80--> [Nginx] --HTTP:8082--> [Delphi Server]
                            ↑
                            |
                      Логирование запросов
                      Rate limiting (будущее)
                      HTTPS termination (будущее)
```

**Настройка Nginx:**
```nginx
server {
    listen       80;
    server_name  192.168.1.113 localhost;

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:8082;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
    }
}
```

**Преимущества Nginx как reverse proxy:**
- 🔑 **Логирование** — все запросы от клиентов пишутся в `logs/access.log` (IP, URL, статус, время ответа)
- 🛡️ **Единая точка входа** — порт 80 для всех клиентов, DataSnap скрыт внутри (порт 8082 только на localhost)
- ⚡ **Буферизация** — Nginx буферизует большие запросы (фото Base64) перед отправкой на DataSnap
- 🔒 **HTTPS в будущем** — достаточно добавить `listen 443 ssl` и сертификат, не меняя код приложения
- 📊 **Rate limiting** — можно ограничить количество запросов с одного IP (защита от перегрузки)

**Порт 80 по умолчанию** — в настройках приложения указывается только IP:
```
192.168.1.113
```
(порт 80 добавляется автоматически, т.к. это стандартный порт HTTP)

> ⚠️ **Только для разработки в доверенной локальной сети!** Для production с доступом из интернета требуется публичный IP + домен + Let's Encrypt (добавить `listen 443 ssl` в nginx.conf).

---

## 🧪 Автоматическое тестирование

Проект покрыт **37 автоматическими модульными тестами** на фреймворке **DUnitX** со **100% успешным прохождением**.

### Покрытие тестами

| Модуль | Тестов | Что проверяется |
|--------|:------:|------------------|
| `SessionManager.pas` | 8 | Управление токеном, URL, авторизацией |
| Парсинг JSON | 8 | Обработка ответов сервера во всех форматах |
| SQLite CRUD | 8 | Локальное хранение данных |
| `JpegUtils.pas` | 5 | Сжатие фото, ресайз до 1920px, сохранение пропорций |
| `SQLite Encryption` | **8** | SQLCipher через sqlite3mc.dll (Windows): создание зашифрованной БД, открытие с паролем, смена пароля, миграция, целостность данных |
| **Application-level encryption** | **Ручное (Android)** | Шифрование полей через `EncryptField/DecryptField`: PIN + ANDROID_ID + Salt + SHA-256 keystream. Протестировано на Android 10+ (установка PIN, создание записи, чтение, синхронизация) |
| **ИТОГО** | **37** | **100% прохождение** ✅ |

### Запуск тестов

```bash
cd Android_Delphi\Tests\Win32\Debug
TestRunner.exe
```

Подробная документация по тестированию доступна в [Tests/README.md](Tests/README.md).

---

## 🔮 Roadmap (Планы развития)

- [x] ~~Добавление `user_id: Int64` в SessionManager и передача в payload синхронизации~~ ✅ **Реализовано**
- [x] ~~Совместимость с bcrypt-аутентификацией сервера~~ ✅ **Реализовано** (парсинг `user_id` из ответа Login, передача в `/upload` и `SyncUpload`)
- [x] ~~Внедрение **SQLCipher** для шифрования локальной SQLite базы данных~~ ✅ **Реализовано** (PIN + DeviceID + Salt, AES-256, 8 тестов)
- [x] ~~Application-level encryption для Android~~ ✅ **Реализовано** (PIN + ANDROID_ID + Salt, SHA-256 stream cipher, поля title/description шифруются при записи, дешифруются при чтении и синхронизации)
- [ ] Фоновая синхронизация через Android WorkManager.
- [ ] Экспорт отчётов в PDF прямо на устройстве.
- [ ] Биометрическая аутентификация (отпечаток пальца / FaceID) для быстрого входа в приложение.
- [ ] Push-уведомления через Firebase Cloud Messaging (FCM) для получения задач от сервера.
- [ ] Офлайн-карты: загрузка тайлов Яндекс.Карт в локальный кэш для работы без интернета.
- [ ] Mock-тесты HTTP-запросов для проверки клиентской логики без реального сервера.
- [x] ~~Загрузка фотографий на сервер~~ ✅ **Реализовано** (сжатие через `JpegUtils.pas` + Base64 в JSON)
- [x] ~~Подключение теста `TestJpegUtils.pas` к `TestRunner.dpr`~~ ✅ **Выполнено** (29 тестов, 100% прохождение)

---

## 📚 Дополнительные материалы

---

## 📄 Лицензия
MIT License. Свободно используйте для обучения и портфолио.
