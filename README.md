# Ускорение Digma F4 (Android 8.1, 1 ГБ ОЗУ) без перепрошивки

Пошаговый гайд: как вычистить предустановленный мусор, отключить лишние
системные приложения, убрать анимации и освободить место на бюджетной
Android-читалке. Без root, без перепрошивки, всё обратимо.

> **Проверено на:** Digma F4, прошивка `WT576V1RU20250909`,
> Android 8.1 (SDK 27), `armeabi-v7a`, ОЗУ 1 ГБ, `/data` 4 ГБ.
> Другие прошивки на той же плате (WT576) должны подойти, но список пакетов
> может отличаться — сверяйтесь с шагом 0.

**Результат на тестовом устройстве:**

| Показатель | До | После |
|---|---|---|
| Свободно на `/data` | 1,04 ГБ | 1,34 ГБ |
| Отключено системных приложений | 0 | 16 |
| Удалено пользовательских приложений | 0 | 4 |
| Анимации интерфейса | 1× | 0× |
| ОЗУ под читалку (опционально) | ~309 МБ | 92–125 МБ |

---

## Содержание

- [Кому подходит и чего гайд не делает](#кому-подходит-и-чего-гайд-не-делает)
- [Требования](#требования)
- [Шаг 0. Зафиксируйте исходное состояние](#шаг-0-зафиксируйте-исходное-состояние)
- [Шаг 1. Сохраните APK на компьютер](#шаг-1-сохраните-apk-на-компьютер)
- [Шаг 2. Отключите фоновый мусор](#шаг-2-отключите-фоновый-мусор)
- [Шаг 3. Удалите лишние приложения](#шаг-3-удалите-лишние-приложения)
- [Шаг 4. Выключите анимации](#шаг-4-выключите-анимации)
- [Шаг 5. Почистите кэш](#шаг-5-почистите-кэш)
- [Шаг 6. Читалка: что реально ест память](#шаг-6-читалка-что-реально-ест-память)
- [Шаг 7. Проверьте результат](#шаг-7-проверьте-результат)
- [Как всё вернуть](#как-всё-вернуть)
- [Грабли и решения](#грабли-и-решения)
- [Приложение А. Список пакетов](#приложение-а-список-пакетов)
- [Приложение Б. Почему не перепрошивка](#приложение-б-почему-не-перепрошивка)

---

## Кому подходит и чего гайд не делает

**Подходит**, если устройство:
- тормозит при открытии книг и меню;
- имеет 1 ГБ ОЗУ и 4–8 ГБ памяти;
- набито предустановленными браузерами, магазинами, переводчиками.

**Не делает:**
- не перепрошивает устройство и не трогает загрузчик;
- не требует root;
- не удаляет ваши книги, документы и фотографии;
- не устанавливает и не конвертирует литературу — это отдельная задача.

**Главный принцип:** сначала *отключить* (`disable-user`), потом при
необходимости *удалить для пользователя* (`uninstall --user 0`).
Отключение не стирает файлы и откатывается одной командой.

---

## Требования

- ПК (Linux / macOS / Windows) и кабель USB.
- [Android platform-tools](https://developer.android.com/tools/releases/platform-tools) — нужен `adb`.
- На устройстве: **Настройки → О телефоне → 7 раз по «Номер сборки»**,
  затем **Для разработчиков → Отладка по USB**.
- Проверка связи:

```bash
adb devices
# List of devices attached
# ABC1234567890    device
```

Если вместо `device` написано `unauthorized` — подтвердите запрос на экране
читалки. Если `offline` — переподключите кабель и выполните `adb kill-server`.

---

## Шаг 0. Зафиксируйте исходное состояние

Сначала посмотрите, что вообще установлено и сколько это ест. Всё, что
понадобится для отката, сохраните в файлы.

```bash
mkdir -p ~/f4-backup && cd ~/f4-backup

adb shell getprop ro.product.model          > model.txt
adb shell getprop ro.build.display.id       > firmware.txt
adb shell getprop ro.build.version.release  > android.txt
adb shell getprop ro.product.cpu.abi        > abi.txt

adb shell pm list packages        > packages-all.txt
adb shell pm list packages -s     > packages-system.txt
adb shell pm list packages -3     > packages-user.txt
adb shell pm list packages -d     > packages-disabled-before.txt

adb shell df -h /data             > storage-before.txt
adb shell cat /proc/meminfo       > meminfo-before.txt
```

Или одной командой:

```bash
./scripts/audit.sh
```

> **Важно:** запомните, какие пакеты были отключены *до вас*. На некоторых
> прошивках часть приложений (например, NFC) уже выключена производителем —
> их не нужно «включать» при откате.

---

## Шаг 1. Сохраните APK на компьютер

Перед удалением чего угодно полезно вытащить установочные файлы. Без root
доступны только APK, но не данные приложений.

```bash
mkdir -p apk-backup

for pkg in $(adb shell pm list packages -3 | sed 's/package://' | tr -d '\r'); do
  path=$(adb shell pm path "$pkg" | tr -d '\r' | sed 's/package://' | head -1)
  [ -n "$path" ] && adb pull "$path" "apk-backup/${pkg}.apk"
done
```

Для системных приложений путь будет вида `/system/app/.../Base.apk` —
`adb pull` оттуда тоже работает.

---

## Шаг 2. Отключите фоновый мусор

### Какие приложения безопасно отключать

Правила простые:

1. **Не трогайте** то, что рисует интерфейс и открывает книги:
   лаунчер, `systemui`, клавиатуру, штатную читалку, файловый менеджер,
   провайдеры (`com.android.providers.*`, кроме календаря).
2. Отключайте только те пакеты, назначение которых понимаете.
3. После каждого блока проверяйте, что устройство живо и книги открываются.

### Список для этой прошивки

| Пакет | Что это | Зачем отключать |
|---|---|---|
| `com.yandex.browser` | Яндекс.Браузер | фоновые процессы, реклама |
| `ru.yandex.translate` | Переводчик | не нужен на читалке |
| `ru.vk.store` | RuStore | магазин приложений, автозапуск |
| `ru.litres.android` | ЛитРес | сам выскакивал сплэшем во время чтения |
| `ru.libapp` | MangaLib | 100+ МБ, автозапуск |
| `com.android.printspooler` | печать | на читалке не нужна |
| `com.android.printservice.recommendation` | подбор принтеров | то же |
| `com.android.bips` | встроенная печать | то же |
| `com.android.dreams.basic` | живые обои | фоновый рендер |
| `com.android.dreams.phototable` | живые обои | то же |
| `com.android.music` | музыкальный плеер | не нужен |
| `com.android.musicfx` | звуковые эффекты | не нужен |
| `com.android.providers.calendar` | календарь | фоновый процесс |
| `com.android.smspush` | SMS-пуш | на читалке не нужен |
| `com.DeviceTest` | инженерный тест | не нужен пользователю |
| `com.wetao.deviceguide` | инструкция | не нужна |
| `android.rockchip.update.service` | OTA-обновление | экономит фон; обновляться вручную |
| `com.google.android.tts` | синтез речи | не используется |
| `com.svox.pico` | синтез речи | не используется |

### Команда

```bash
for pkg in \
  com.yandex.browser ru.yandex.translate ru.vk.store ru.litres.android ru.libapp \
  com.android.printspooler com.android.printservice.recommendation com.android.bips \
  com.android.dreams.basic com.android.dreams.phototable \
  com.android.music com.android.musicfx \
  com.android.providers.calendar com.android.smspush \
  com.DeviceTest com.wetao.deviceguide android.rockchip.update.service \
  com.google.android.tts com.svox.pico
do
  adb shell pm disable-user --user 0 "$pkg"
done
```

Или готовым скриптом (по умолчанию — примерный прогон, без изменений):

```bash
./scripts/optimize.sh          # показать, что будет сделано
./scripts/optimize.sh --yes    # применить
```

Проверка:

```bash
adb shell pm list packages -d
```

> **Не отключайте `com.wetao.emreader`** на этой прошивке: именно к нему
> жёстко привязано открытие книг из раздела «Книги». Подробности — в
> [шаге 6](#шаг-6-читалка-что-реально-ест-память).

---

## Шаг 3. Удалите лишние приложения

`uninstall --user 0` убирает приложение для текущего пользователя, не трогая
системный раздел. Для вшитых приложений это освобождает только их данные,
для установленных из магазина — ещё и APK.

```bash
for pkg in ru.vk.store com.yandex.browser ru.litres.android ru.yandex.translate; do
  adb shell pm uninstall --user 0 "$pkg"
done
```

Проверка:

```bash
adb shell pm list packages | grep -E 'vk.store|litres|yandex|browser' || echo 'чисто'
```

### Что освобождается на самом деле

| Пакет | Где лежит | Что освободится |
|---|---|---|
| `ru.vk.store` | `/data/app` | APK + данные (~259 МБ) |
| вшитые в `/system/app` | системный раздел | только данные и кэш |

Вшитые приложения возвращаются без скачивания:

```bash
adb shell cmd package install-existing com.yandex.browser
```

---

## Шаг 4. Выключите анимации

Самый быстрый и самый заметный шаг: интерфейс начинает реагировать сразу.

```bash
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```

Проверка:

```bash
adb shell settings get global window_animation_scale
```

Это не ускоряет перерисовку e-ink (её предел — сама матрица), но убирает
задержки при открытии меню и переключении экранов.

---

## Шаг 5. Почистите кэш

Найдите, что занимает место:

```bash
adb shell du -sk /sdcard/* 2>/dev/null | sort -n | tail -10
adb shell du -sk /sdcard/Android/data/*/cache 2>/dev/null | sort -n | tail -10
```

Безопасно удалять кэш приложений и старые установщики:

```bash
adb shell 'rm -rf /sdcard/Android/data/com.example.reader/cache/*'
adb shell 'rm -f /sdcard/Download/*.apk'
```

> Не удаляйте `/sdcard/Android/data/<пакет>/files` — там могут быть книги,
> словари и настройки. Чистите только `cache`.

---

## Шаг 6. Читалка: что реально ест память

Этот шаг опционален, но на 1 ГБ ОЗУ он даёт больше всего.

### Как измерить

```bash
adb shell dumpsys meminfo | sed -n '/Total PSS by process/,/Total PSS by OOM/p' | head -20
adb shell ps -A -o PID,RSS,NAME | sort -n | tail -10
```

Смотрите не на «свободно», а на **PSS/RSS процессов читалки**. Некоторые
читалки держат несколько процессов и не выгружаются после закрытия.

### Пример с этой прошивки

| Читалка | Процессов | ОЗУ |
|---|---|---|
| AlReader (штатная) | 3 | ~309 МБ |
| KOReader | 1 | 92–125 МБ |

### Если меняете читалку — проверьте открытие книг

На прошивке `WT576V1RU20250909` обнаружен баг: раздел «Книги» и файловый
менеджер жёстко привязаны к штатной читалке.

1. Сначала они шлют интент **именно** в
   `com.wetao.emreader/.module.fb.core.FBReaderActivity` с путём
   `file:///storage/emulated/0/...` — работает.
2. Если штатная читалка отключена, они шлют всем остальным ссылку
   `content://com.wetao.elauncher.fileProvider/storage//emulated/0/...`
   **без `FLAG_GRANT_READ_URI_PERMISSION`**. Провайдер лаунчера не
   экспортирован (uid 1000), поэтому её не может открыть ни одна сторонняя
   программа:
   - штатная читалка → «Can't open file»;
   - KOReader → `SecurityException: Permission Denial ... not exported from UID 1000`.

**Вывод:** если оставляете штатную читалку — не отключайте её.
Если ставите другую — открывайте книги из её собственной полки, а не из
раздела «Книги» лаунчера. Лечится только root или новой прошивкой.

---

## Шаг 7. Проверьте результат

```bash
adb shell df -h /data
adb shell head -3 /proc/meminfo
adb shell dumpsys cpuinfo | head -12
adb shell dumpsys window | grep -m1 mCurrentFocus
```

Устройство в простое должно показывать 0–2 % CPU. Если что-то грузит
процессор — смотрите `dumpsys cpuinfo`, а не «оптимизаторы» из магазина.

Полезное для проверки, что всё живо:

```bash
adb shell input keyevent KEYCODE_HOME
adb exec-out screencap -p > screen.png
```

---

## Как всё вернуть

### Включить отключённые приложения

```bash
adb shell 'pm enable com.yandex.browser ru.yandex.translate ru.vk.store \
  ru.litres.android ru.libapp com.android.printspooler \
  com.android.printservice.recommendation com.android.bips \
  com.android.dreams.basic com.android.dreams.phototable com.android.music \
  com.android.musicfx com.android.providers.calendar com.android.smspush \
  com.DeviceTest com.wetao.deviceguide android.rockchip.update.service \
  com.google.android.tts com.svox.pico'
```

Или:

```bash
./scripts/rollback.sh
```

### Вернуть удалённые вшитые приложения

```bash
adb shell cmd package install-existing com.yandex.browser
```

Приложения из `/data/app` (например, RuStore) придётся установить заново.

### Вернуть анимации

```bash
adb shell settings put global window_animation_scale 1
adb shell settings put global transition_animation_scale 1
adb shell settings put global animator_duration_scale 1
```

### Вернуть заводские настройки

Если что-то пошло совсем не так — «Настройки → Восстановление и сброс».
Это вернёт все отключённые системные приложения, но удалит пользовательские
данные, поэтому книги лучше заранее скопировать на компьютер.

---

## Грабли и решения

| Симптом | Причина / решение |
|---|---|
| `adb: no devices/emulators found` | Проверьте кабель и «Отладку по USB». На Linux помогает `adb kill-server && adb start-server`. |
| `adb` отваливается после сна | Поднимите сервер вручную: `adb -a nodaemon server &` и не закрывайте терминал. |
| `error: device offline` | Переподключите кабель, подтвердите отладку на устройстве. |
| `INSTALL_FAILED_OLDER_SDK` | APK требует Android новее. Ищите сборку под SDK 27. |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | Нужен APK под `armeabi-v7a`, а не `arm64`. |
| `awk: not found`, `sort -h` не работает | В Android-shell урезанный busybox. Считайте на ПК или обходитесь `cut`/`sed`. |
| `sleep 0.4` → ошибка | Дробные секунды не поддерживаются, только целые. |
| `input text` не вводит кириллицу | Ограничение ADB. Вводите латиницей или используйте `adb shell am broadcast` с IME-приложением. |
| `/tmp` недоступен на устройстве | Используйте `/data/local/tmp`. |
| После чистки пропали обои/музыка | Это отключённые пакеты, верните нужный через `pm enable`. |
| Книга не открывается из «Книги» | См. [шаг 6](#шаг-6-читалка-что-реально-ест-память) — баг прошивки. |

---



## Приложение А. Список пакетов

### Отключаемые (обратимо)

```
com.yandex.browser
ru.yandex.translate
ru.vk.store
ru.litres.android
ru.libapp
com.android.printspooler
com.android.printservice.recommendation
com.android.bips
com.android.dreams.basic
com.android.dreams.phototable
com.android.music
com.android.musicfx
com.android.providers.calendar
com.android.smspush
com.DeviceTest
com.wetao.deviceguide
android.rockchip.update.service
com.google.android.tts
com.svox.pico
```

### Не трогать

```
com.wetao.elauncher          # лаунчер
com.android.systemui         # интерфейс
com.wetao.emreader           # штатная читалка, к ней привязан раздел «Книги»
com.wetao.storage            # файловый менеджер
com.android.inputmethod.latin# клавиатура
com.android.providers.*      # кроме calendar
com.android.packageinstaller # установка APK
com.android.externalstorage  # доступ к SD-карте
```

### Проверка «кто это»

```bash
adb shell dumpsys package <пакет> | grep -E 'versionName|firstInstallTime'
adb shell cmd package resolve-activity --brief <пакет>
adb shell pm path <пакет>
```

---

## Приложение Б. Почему не перепрошивка

Digma F4 построена на Rockchip с закрытым загрузчиком. Под эту модель нет
кастомных прошивок, а ошибка при прошивке не восстанавливается через
recovery. Поэтому «сделать как на Kindle» перепрошивкой — почти гарантированный
кирпич.

Всё, что даёт ощутимый прирост на такой читалке, делается на уровне
пользовательских настроек: отключение фона, анимации, лишние приложения и
более лёгкая читалка. Предел скорости перелистывания — сама e-ink матрица
(0,3–0,8 с), его софтом не обойти.

---

## Лицензия

MIT. Используйте на свой риск: список пакетов зависит от прошивки,
проверяйте его на своём устройстве.
