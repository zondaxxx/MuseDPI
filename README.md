<p align="center">
  <img src="./RepoAssets/muse-banner.png" width="100%" alt="MuseDPI for iOS and Android" />
</p>

<p align="center">
  <a href="https://github.com/zondaxxx/MuseDPI/actions/workflows/build-release.yml"><img src="https://github.com/zondaxxx/MuseDPI/actions/workflows/build-release.yml/badge.svg" alt="iOS build" /></a>
  <a href="https://github.com/zondaxxx/MuseDPI/actions/workflows/android.yml"><img src="https://github.com/zondaxxx/MuseDPI/actions/workflows/android.yml/badge.svg" alt="Android build" /></a>
  <a href="https://github.com/zondaxxx/MuseDPI/releases"><img src="https://img.shields.io/github/v/release/zondaxxx/MuseDPI?color=ffffff&label=release&labelColor=09090d" alt="Latest release" /></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-ffffff?labelColor=09090d" alt="AGPL-3.0" /></a>
  <img src="https://img.shields.io/badge/iOS-14%2B-ffffff?labelColor=09090d" alt="iOS 14+" />
  <img src="https://img.shields.io/badge/Android-5%2B-ffffff?labelColor=09090d" alt="Android 5+" />
</p>

# MuseDPI

Локальный обход DPI для **iPhone и Android** с одинаковым интерфейсом. Приложение
поднимает системный VPN-туннель, направляет трафик в локальный SOCKS-прокси и
обрабатывает его ядром [ByeDPI](https://github.com/hufrea/byedpi) прямо на телефоне.
Внешний VPN-сервер не используется.

> MuseDPI не скрывает IP-адрес, не меняет страну и не добавляет VPN-шифрование.
> Системный VPN нужен только для маршрутизации трафика в локальное ядро.

[Визуальная система MuseDPI](./docs/MUSEDPI-BRAND.md): глубокий морской синий,
морское стекло, спокойные волны и логотип «m».

## Скриншоты

### Android · главный экран и диагностика

<p align="center">
  <img src="./RepoAssets/screens/muse-android-home.png" width="280" alt="MuseDPI Android: главный экран с HTTP-откликом Discord и YouTube" />
  <img src="./RepoAssets/screens/muse-android-diagnostics.png" width="280" alt="MuseDPI Android: реальные результаты DNS, TLS, HTTP и загрузки 256 КБ" />
</p>

### iPhone · настройки, сервисы и сети

<p align="center">
  <img src="./RepoAssets/screens/muse-ios-settings.png" width="260" alt="MuseDPI iPhone: быстрые настройки и стратегии" />
  <img src="./RepoAssets/screens/muse-ios-services.png" width="260" alt="MuseDPI iPhone: выбор защищаемых сервисов" />
  <img src="./RepoAssets/screens/muse-ios-networks.png" width="260" alt="MuseDPI iPhone: Wi-Fi, мобильная сеть, On Demand и восстановление" />
</p>

Снимки сделаны в Android Emulator и iPhone 17 Pro Max Simulator.
На Android показаны **реальные HTTP-измерения**, не демонстрационные значения:
оба сервиса ответили, полная диагностика выполнила по три успешных запроса
и проверила загрузку 256 КБ. Эмулятор использует подключение Mac с действующим VPN;
эти результаты не подтверждают обход DPI в LTE-сети телефона.
В iPhone Simulator проверка упёрлась в DNS, поэтому здесь показаны настройки,
а не выдуманные задержки. Старые файлы без префикса `muse-` показывают предыдущий интерфейс.

## Возможности

Общее для обеих платформ — один дизайн, один подписанный каталог, одни и те же пробы:

- одно понятное действие «Подключить» на главном экране;
- автоматический подбор стратегии по выбранным сервисам;
- Discord, YouTube, Instagram, TikTok, X/Twitter, Telegram и свои домены;
- подробная диагностика DNS, TLS и HTTP плюс загрузка 256 КБ с реального домена доставки:
  видно, когда ТСПУ пропускает рукопожатие и замораживает поток;
- умное восстановление: после двух неудачных проверок — предложение ранее рабочей стратегии;
- профили стратегий для Wi-Fi и мобильной сети;
- подписанный Ed25519 онлайн-каталог с поиском, избранным, историей и офлайн-откатом;
- блокировка QUIC (UDP 443), чтобы HTTP/3-клиенты сразу уходили на TCP-стратегию;
- журнал подключения и счётчики трафика туннеля на главном экране;
- приватный JSON-отчёт для поддержки без IP-адресов и содержимого трафика;
- работа без аккаунтов, аналитики и удалённого сервера; русский и английский интерфейс.

| | iOS | Android |
|---|---|---|
| Автоподбор | предпроверка без туннеля + подтверждение топ-3 через VPN | каждая стратегия проверяется прямо через локальное ядро — без перезапуска туннеля |
| Стратегии | split / disorder / OOB / TLS-record + UDP-фейки | всё то же **плюс TCP-фейки** (`-f`, TTL) и «Расширенный подбор» из 60 стратегий ByeByeDPI |
| Выбор приложений | — (iOS не умеет) | раздельное туннелирование: все / кроме / только выбранные |
| Режим | VPN | VPN или только SOCKS5-прокси |
| Автозапуск | VPN On Demand | при включении телефона, при открытии, «Постоянная VPN» Android |
| Быстрый доступ | виджет, Siri/Shortcuts | плитка в шторке, ярлыки |
| Экспертный режим | DNS, прокси, списки, тестер | классический экран ByeByeDPI: командная строка, UI-редактор, тестер |

## Быстрый старт

### Android

1. Скачайте APK из [релизов `android-v*`](https://github.com/zondaxxx/MuseDPI/releases)
   (`MuseDPI-*-universal-release.apk` подходит для всех телефонов).
2. Установите, откройте и нажмите «Подключить» — Android попросит разрешение на VPN.
3. Если сервисы не открываются — «Автоматическая настройка» → «Подобрать и подключить».

Сборка из исходников — в [android/PALKA-README.md](./android/PALKA-README.md).

### iOS

1. Скачайте unsigned IPA из [релизов iOS](https://github.com/zondaxxx/MuseDPI/releases) (теги `v*`, не `android-v*`). Старые сборки называются `PalkaDPI-unsigned.ipa`, новые — `MuseDPI-unsigned.ipa`.
2. Подпишите `PalkaWidget.appex`, затем `ByeByeDPITun.appex`, затем основное приложение.
3. Установите IPA на физический iPhone.
4. Выберите нужные сервисы и нажмите «Автонастройка» — приложение само проверит стратегии.
5. Разрешите добавление VPN-конфигурации и сохраните найденный вариант для текущей сети.

Нужны три App ID/provisioning profile: приложение, `.widget` и `.tun`. Все три
должны иметь один App Group; entitlement `packet-tunnel-provider` нужен только
туннелю. Одного сертификата разработчика недостаточно.

Подробная инструкция: [PALKA-README.md](./PALKA-README.md).

## Онлайн-стратегии

Приложение загружает [strategy-catalog.json](./strategy-catalog.json) и его
[отделённую подпись](./strategy-catalog.json.sig) напрямую из этого репозитория
по HTTPS. Каталог можно безопасно обновлять без перевыпуска IPA.

Перед применением MuseDPI проверяет Ed25519-подпись, схему, совместимость с
версией приложения и ядра, отозванные записи, HTTPS-источники и аргументы ByeDPI.
Три последних проверенных поколения доступны офлайн; из настроек можно выполнить
откат на предыдущее поколение.

Как добавить профиль: [docs/STRATEGY-CATALOG.md](./docs/STRATEGY-CATALOG.md).

## Диагностика сервисов

Главный экран делает несколько небольших HTTPS-запросов к официальным адресам
выбранных сервисов. Это не ICMP-ping: приложение показывает медианный HTTP round
trip, а подробный экран отдельно отображает DNS, TLS и HTTP. При активном туннеле
запросы проходят через текущую конфигурацию MuseDPI.

## Сборка

```bash
git clone https://github.com/zondaxxx/MuseDPI.git
cd MuseDPI
open SwByeDPI.xcodeproj
```

Выберите схему `ByeByeDPI`, укажите Team, Bundle ID и App Group для приложения,
виджета и Packet Tunnel extension. Для unsigned IPA с полным Xcode:

```bash
PALKA_BUNDLE_ID=your.unique.palkadpi \
PALKA_APP_GROUP=group.your.unique.palkadpi \
./scripts/build_unsigned_ipa.sh
```

Результат: `packages/MuseDPI-unsigned.ipa`.

Android (JDK 17, Android SDK с `ndk;27.x` и `cmake;3.22.1`):

```bash
cd android
./gradlew assembleRelease   # APK: android/app/build/outputs/apk/release/
```

## Структура

```text
Example/Sources/ByeByeDPI/       iOS-приложение и SwiftUI
Example/Sources/ByeByeDPITun/    Packet Tunnel extension
Example/Sources/PalkaWidget/     WidgetKit extension
android/app/src/main/java/.../palka/  Android: модель, пробы, автоподбор, каталог
android/app/src/main/java/.../palka/ui/  Android: Compose-интерфейс (порт SwiftUI 1:1)
Sources/ByeDPIC/                 встроенное C-ядро byedpi
Sources/ByeDPIKit/               Swift-обёртка над ядром
Sources/SwByeDPI/                модели, списки и диагностика
android/                         Android-приложение (Kotlin/Compose, byedpi + hev-socks5-tunnel)
strategy-catalog.json            обновляемый онлайн-каталог
strategy-catalog.json.sig        подпись каталога Ed25519
scripts/                         сборка и валидация
```

## Происхождение проекта

MuseDPI — производная работа от [mIwr/SwByeDPI](https://github.com/mIwr/SwByeDPI)
с ядром [hufrea/byedpi](https://github.com/hufrea/byedpi). iOS-профили основаны
на актуальных конфигурациях [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube)
и документации [bol-van/zapret](https://github.com/bol-van/zapret): доступные на
Apple TCP-приёмы переведены в split/TLS-record/OOB, а две UDP-приманки включены
с исходной MIT-лицензией. Windows-компоненты `winws`, zapret и WinDivert в
приложение не входят.

Полный перечень встроенного кода, зависимостей, источников доменных списков,
транзитивных проектов и лицензий находится в
[ACKNOWLEDGEMENTS.md](./ACKNOWLEDGEMENTS.md).

Политика обработки данных: [docs/PRIVACY.md](./docs/PRIVACY.md).

## Ограничения

- эффективность стратегии зависит от сети, оператора и текущего способа фильтрации;
- iOS не предоставляет WinDivert/NFQUEUE и произвольную raw TCP-инъекцию;
- QUIC/UDP 443 нельзя фильтровать по SNI тем же способом, что TCP/TLS, поэтому по умолчанию
  QUIC сбрасывается внутри туннеля (переключатель «Блокировать QUIC») и клиенты сразу
  уходят на TCP;
- тестировать туннель нужно на физическом устройстве;
- используйте приложение только в соответствии с применимым законодательством.

## Лицензия

Проект распространяется по [AGPL-3.0](./LICENSE). Встроенное ядро byedpi сохраняет
свою MIT-лицензию в [Sources/ByeDPIC/byedpi/LICENSE](./Sources/ByeDPIC/byedpi/LICENSE).

Android-приложение в [`android/`](./android/) — форк [romanvht/ByeDPIAndroid](https://github.com/romanvht/ByeDPIAndroid)
и распространяется по [GPL-3.0](./android/LICENSE).
