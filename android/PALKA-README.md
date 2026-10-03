<p align="center">
  <img src="../RepoAssets/muse-banner.png" width="100%" alt="MuseDPI for iOS and Android" />
</p>

# MuseDPI for Android

Android-версия MuseDPI: локальный обход DPI без внешнего VPN-сервера, с тем же
интерфейсом, что и на iPhone. Основа — форк
[romanvht/ByeDPIAndroid](https://github.com/romanvht/ByeDPIAndroid) (GPL-3.0) с ядром
[hufrea/byedpi](https://github.com/hufrea/byedpi) и hev-socks5-tunnel.

## Что внутри

**Интерфейс MuseDPI** (`palka/ui/`, Jetpack Compose) — построчный порт SwiftUI-экранов iOS:
тёмный фон с сеткой, карточки, белые кнопки, пульсирующий статус, анимации входа и нажатия.
Экраны: главный, настройки, автонастройка, защищаемые сервисы, каталог стратегий,
избранное и история, диагностика, сети и автоподключение, приложения в обходе, экспертные.

**Автоподбор** (`palka/PalkaAutomation.kt`): VPN останавливается один раз, затем каждая
стратегия запускается в том же процессе на `127.0.0.1:10801` и проверяется пробами
(маркер в ответе + загрузка 256 КБ со стоп-детектом ТСПУ). На Android туннель просто
передаёт пакеты в этот же SOCKS-прокси, поэтому проверка через ядро — это и есть
реальная проверка; отдельное подтверждение через VPN, как на iOS, не нужно.
Победитель применяется, запоминается для текущей сети и подключается.
«Расширенный подбор» добавляет 60 стратегий ByeByeDPI с TCP-фейками (`-f`, TTL) —
на iOS такие приёмы недоступны.

**Каталог** (`palka/PalkaCatalog.kt`): тот же Ed25519-подписанный `strategy-catalog.json`,
что и в iOS-версии; проверка подписи, схемы и версий, три последних проверенных
поколения в кэше и откат из интерфейса.

**Пробы и диагностика** (`palka/PalkaProbe.kt`): DNS, TLS-рукопожатие, HTTP с маркером,
256 КБ Range-загрузка с реального домена доставки. При включённом обходе пробы идут
через работающее ядро, при выключенном — напрямую (видно «сырое» состояние сети).

**Только на Android:** раздельное туннелирование по приложениям, режим «только SOCKS5»,
автозапуск при включении телефона и при открытии, «Постоянная VPN», плитка в шторке,
ярлыки, классический экран ByeByeDPI со всеми параметрами ядра.

Ядро byedpi вшито в репозиторий (`app/src/main/cpp/byedpi`, upstream `ba53229`) с
патчем MuseDPI из `MuseDPI/patches/byedpi/0001-palkadpi-core.patch`
(`-l hex:` бинарные фейки, `-k/--udp-drop` для блокировки QUIC).

## Сборка

```bash
export JAVA_HOME=/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=/usr/local/share/android-commandlinetools   # нужны ndk;27.x и cmake;3.22.1
cd android && ./gradlew assembleDebug
```

APK: `android/app/build/outputs/apk/debug/app-universal-debug.apk` (и по ABI рядом).
Release-подпись берётся из окружения (`PALKA_KEYSTORE`, `PALKA_KEYSTORE_PASS`,
`PALKA_KEY_ALIAS`); без них release-APK остаётся неподписанным.

Внутренний Kotlin-пакет и JNI-имена оставлены как в upstream (`io.github.romanvht.byedpi`),
изменён только `applicationId` (`io.github.zondaxxx.palkadpi`), чтобы приложение
ставилось рядом с оригинальным ByeByeDPI. Код MuseDPI лежит в
`app/src/main/java/io/github/romanvht/byedpi/palka/`; строки интерфейса генерируются из
iOS `Localizable.strings` в `res/values*/palka_strings.xml`, так что тексты совпадают.
