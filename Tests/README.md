# 🧪 Тесты для Android_Delphi (DUnitX)

Автоматические модульные тесты для клиентской части проекта FieldAudit, реализованные на фреймворке **DUnitX**.

Проект покрывает критически важные модули: управление сессиями, парсинг JSON и работу с локальной SQLite базой данных.

## 📊 Статистика покрытия

| Тестовый набор | Тестов | Назначение |
|----------------|:------:|------------|
| `TTestSessionManager` | 8 | Управление токеном, URL, авторизацией |
| `TTestClientJsonParsing` | 8 | Парсинг JSON ответов сервера |
| `TTestLocalDb` | 8 | CRUD операции с локальной SQLite |
| **ИТОГО** | **24** | **100% успешное прохождение** ✅ |

## 📁 Структура проекта

```
Tests/
├── TestRunner.dpr              # Главный файл проекта (открывать в Delphi)
├── TestRunner.dproj            # Настройки проекта (создаётся Delphi автоматически)
├── TestSessionManager.pas      # Тесты SessionManager
├── TestJsonParsing.pas         # Тесты парсинга JSON
├── TestLocalDb.pas             # Тесты SQLite CRUD
├── dunitx-results.xml          # Отчёт о последнем прогоне (NUnit XML)
└── README.md                   # Этот файл
```

## 🧪 Список тестов

### TTestSessionManager (8 тестов)
Проверяет модуль `SessionManager.pas`, отвечающий за управление сессией и конфигурацией.

| Имя теста | Что проверяет |
|-----------|---------------|
| `TestDefaultTokenIsEmpty` | Токен по умолчанию пустой |
| `TestDefaultServerURL` | URL по умолчанию корректный (`https://192.168.1.113`) |
| `TestSetAndGetToken` | Установка и получение токена |
| `TestIsLoggedInWithEmptyToken` | `IsLoggedIn = False` без токена |
| `TestIsLoggedInWithValidToken` | `IsLoggedIn = True` с токеном |
| `TestLogoutClearsToken` | `Logout` очищает токен |
| `TestServerURLAutoSave` | URL автоматически сохраняется в файл `server_url.txt` |
| `TestTokenNotPersistedToDisk` | Токен НЕ сохраняется на диск (безопасность!) |

### TTestClientJsonParsing (8 тестов)
Проверяет корректность парсинга JSON-ответов сервера.

| Имя теста | Что проверяет |
|-----------|---------------|
| `TestParseLoginResponse` | Парсинг ответа `Login` (успех) |
| `TestParseLoginResponseWithError` | Парсинг ответа `Login` (ошибка) |
| `TestParseLoginResponseWithInvalidFormat` | Невалидный формат ответа |
| `TestBuildSyncPayload` | Формирование JSON для синхронизации |
| `TestParseSyncResponse` | Парсинг ответа синхронизации |
| `TestParseSyncResponseWithError` | Ошибка синхронизации |
| `TestBuildPayloadWithMultipleItems` | Несколько элементов в пакете |
| `TestParseEmptyResultArray` | Пустой массив результатов |

### TTestLocalDb (8 тестов)
Проверяет модуль `dmLocalDb.pas`, отвечающий за локальное хранение данных.

| Имя теста | Что проверяет |
|-----------|---------------|
| `TestDatabaseConnection` | Подключение к SQLite |
| `TestCreateTask` | Создание задачи |
| `TestGetAllTasks` | Получение всех задач |
| `TestUpdateTask` | Обновление задачи |
| `TestDeleteTask` | Удаление задачи |
| `TestMarkAsSynced` | Пометка как синхронизированная |
| `TestGetUnsyncedTasks` | Получение несинхронизированных |
| `TestTaskWithCoordinates` | Задачи с координатами GPS |

## 📈 Результаты тестирования

Последний прогон (2026-06-18):

```
Total tests: 24
Passed:      24 ✅
Failed:      0
Ignored:     0
Time:        0.047s
```

## 🚀 Как запустить тесты

### Требования
- Embarcadero Delphi 11/12
- DUnitX (входит в стандартную поставку Delphi)
- Доступ к папке `Android_Delphi/` (тесты ссылаются на модули клиента)

### Пошаговая инструкция

1. **Откройте проект тестов:**
   - В Delphi: **File → Open**
   - Выберите файл `Android_Delphi/Tests/TestRunner.dpr`
   - *Примечание: отдельный `.dproj` создавать не нужно — Delphi использует `TestRunner.dpr` как главный файл проекта*

2. **Проверьте пути поиска модулей:**
   - **Project → Options → Delphi Compiler → Search path**
   - Должен содержать: `..\`

3. **Скомпилируйте проект:**
   - Нажмите **Ctrl+F9** (Build)
   - Исполняемый файл появится в `Tests/Win32/Debug/TestRunner.exe`

4. **Запустите тесты:**
   - **Из Delphi:** нажмите **Ctrl+Shift+F10** (Run)
   - **Из командной строки:**
     ```cmd
     cd Android_Delphi\Tests\Win32\Debug
     .\TestRunner.exe
     ```

5. **Посмотрите результаты:**
   - В консоли появится отчёт о прохождении тестов
   - XML-отчёт в формате NUnit сохранится в файл `dunitx-results.xml`

## 🔗 Интеграция с CI/CD

DUnitX генерирует отчёт в формате **NUnit XML** (`dunitx-results.xml`), который можно импортировать в популярные CI-системы:

### Jenkins
```groovy
pipeline {
    agent any
    stages {
        stage('Build & Test') {
            steps {
                bat '"C:\\Program Files (x86)\\Embarcadero\\Studio\\22.0\\bin\\rsvars.bat" && ' +
                    'msbuild Android_Delphi\\Tests\\TestRunner.dproj /t:Build'
                bat 'Android_Delphi\\Tests\\Win32\\Debug\\TestRunner.exe'
            }
            post {
                always {
                    nunit testResultsPattern: 'Android_Delphi/Tests/**/dunitx-results.xml'
                }
            }
        }
    }
}
```

### GitLab CI
```yaml
test:
  stage: test
  script:
    - msbuild Android_Delphi\Tests\TestRunner.dproj /t:Build
    - Android_Delphi\Tests\Win32\Debug\TestRunner.exe
  artifacts:
    reports:
      junit: Android_Delphi/Tests/**/dunitx-results.xml
```

### GitHub Actions
```yaml
name: Run DUnitX Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build tests
        run: msbuild Android_Delphi\Tests\TestRunner.dproj /t:Build
      - name: Run tests
        run: Android_Delphi\Tests\Win32\Debug\TestRunner.exe
      - name: Publish results
        uses: dorny/test-reporter@v1
        with:
          name: DUnitX Tests
          path: Android_Delphi/Tests/**/dunitx-results.xml
          reporter: java-junit
```

## 📝 Добавление новых тестов

1. Создайте новый файл `TestNewModule.pas`
2. Добавьте его в проект
3. Добавьте в `TestRunner.dpr` в секцию `uses`
4. Зарегистрируйте тестовый класс:

```pascal
initialization
  TDUnitX.RegisterTestFixture(TTestNewModule);
```

## ⚠️ Важные замечания

1. **Платформа:** Тесты компилируются для **Windows** (Win32/Win64), а не для Android
2. **SQLite:** Тесты `TestLocalDb` создают временную БД в `%TEMP%` и автоматически удаляют её
3. **SessionManager:** Тесты используют синглтон `AppSession`, поэтому важно очищать состояние в `Setup`/`TearDown`
4. **JSON:** Тесты парсинга не требуют сетевого подключения

## 🎯 Что НЕ тестируется (и почему)

| Модуль | Причина отсутствия тестов |
|--------|---------------------------|
| `uLogin.pas` (HTTP-запросы) | Требует реального сервера — это интеграционный тест |
| `frmMain.pas` (UI-логика) | UI сложно тестировать модульно |
| `dmLocalDb.pas` (FireDAC компоненты) | Требует настроенных компонентов FireDAC |

Для полноценного покрытия рекомендуется добавить:
- **Mock-тесты HTTP** для проверки клиентской логики без реального сервера
- **Интеграционные тесты** с mock-сервером

## 💡 Советы по расширению

1. **Добавьте mock-объекты** для `THTTPClient`, чтобы тестировать логику обработки ответов без реального сервера
2. **Используйте TestContainers** для запуска тестовой БД PostgreSQL в Docker
3. **Добавьте нагрузочные тесты** через JMeter или k6 для проверки производительности HTTP-запросов
4. **Настройте pre-commit hook** для автоматического запуска тестов перед каждым коммитом

## 📄 Лицензия

MIT License. Свободно используйте, модифицируйте и распространяйте.
