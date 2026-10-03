# Источники, зависимости и благодарности

Этот файл отделяет код, который входит в MuseDPI, от наборов данных,
транзитивных зависимостей и проектов, использованных только как источник идей.

## Производная работа и встроенный код

| Репозиторий | Как используется | Лицензия |
|---|---|---|
| [mIwr/SwByeDPI](https://github.com/mIwr/SwByeDPI) | Базовый репозиторий: Swift-обёртка, архитектура приложений, модели, генераторы ресурсов, диагностические экраны и исходная реализация Network Extension. MuseDPI является производной работой. | AGPL-3.0 |
| [hufrea/byedpi](https://github.com/hufrea/byedpi) | C-ядро DPI-обхода находится в `Sources/ByeDPIC/byedpi`. | MIT |

Главная лицензия производной работы — [AGPL-3.0](./LICENSE). Лицензия ядра
сохранена рядом с его исходниками:
[Sources/ByeDPIC/byedpi/LICENSE](./Sources/ByeDPIC/byedpi/LICENSE).

## Прямые зависимости приложения

| Репозиторий | Назначение | Лицензия |
|---|---|---|
| [EbrahimTahernejad/Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit) | Перевод IP-пакетов Packet Tunnel в локальный SOCKS-трафик. Репозиторий поддерживается EbrahimTahernejad; его README указывает первоначального автора `arror`. | MIT |
| [heiher/hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) | Нативное ядро, обёрткой и build workflow для которого является Tun2SocksKit. | MIT |
| [mac-cain13/R.swift](https://github.com/mac-cain13/R.swift) | Типобезопасный доступ к строкам, изображениям и цветам приложения. | MIT |
| [sochalewski/TextFieldAlert](https://github.com/sochalewski/TextFieldAlert) | Поля ввода внутри SwiftUI alert на iOS 14. | MIT |

## Транзитивные build-зависимости

Эти репозитории не вызываются кодом MuseDPI напрямую, но загружаются SwiftPM в
дереве R.swift:

| Репозиторий | Назначение | Лицензия |
|---|---|---|
| [tomlokhorst/XcodeEdit](https://github.com/tomlokhorst/XcodeEdit) | Чтение Xcode project-файлов генератором R.swift. | MIT |
| [apple/swift-argument-parser](https://github.com/apple/swift-argument-parser) | Разбор аргументов инструментов R.swift. | Apache-2.0 |

## Источники доменных списков и стратегий upstream

Содержимое `Assets/` было унаследовано от SwByeDPI. Его upstream-документация
указывает следующие источники:

| Источник | Какие данные использовались | Лицензия/условия |
|---|---|---|
| [romanvht/ByeByeDPI](https://github.com/romanvht/ByeByeDPI) | Тестовые домены и наборы стратегий ByeDPI. | GPL-3.0 |
| [hxehex/russia-mobile-internet-whitelist](https://github.com/hxehex/russia-mobile-internet-whitelist) | Списки SLD, используемые для bypass/исключений. | MIT |
| [itdoginfo/allow-domains](https://github.com/itdoginfo/allow-domains) | Тестовые домены. | Отдельная лицензия не объявлена GitHub; см. условия исходного репозитория. |
| [ByeDPI_Channel](https://t.me/ByeDPI_Channel) | Опубликованные сообществом тестовые домены и стратегии. | Условия отдельных публикаций; ссылка сохранена для атрибуции. |

Онлайн-каталог MuseDPI содержит небольшие Apple-совместимые комбинации
документированных аргументов ByeDPI. Профили `flowseal-*.v3` также включают в
виде hex две неизменённые UDP-приманки Flowseal/bol-van: QUIC Initial и Discord
UDP. Их контрольные суммы и MIT-лицензия сохранены в
[`THIRD_PARTY_LICENSES/Flowseal-zapret.txt`](./THIRD_PARTY_LICENSES/Flowseal-zapret.txt).
Каждая запись каталога также хранит собственную HTTPS-ссылку `sourceURL`.

## Источники перенесённых стратегий и идеи

| Репозиторий | Влияние |
|---|---|
| [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) | Пользовательский сценарий, актуальные параметры профилей и две UDP-приманки в подписанном каталоге. Raw-packet TCP-команды не переносятся. |
| [bol-van/zapret](https://github.com/bol-van/zapret) | Исходный проект payload-файлов и описание DPI desync; MIT-лицензия сохранена отдельно. |
| [BDManual/ByeByeDPI-Manual](https://github.com/BDManual/ByeByeDPI-Manual) | Пользовательская документация и рекомендации по подбору стратегий. |

MuseDPI **не включает** `winws`, WinDivert, batch-файлы или raw-packet код
Flowseal/zapret. Эти Windows-механизмы несовместимы с публичными iOS API. В
каталог включены только две неисполняемые UDP-приманки, которые отправляет
встроенное ядро ByeDPI с ограниченным TTL.

## Apple

Приложение использует системные фреймворки Apple SwiftUI, NetworkExtension,
Network, CryptoKit, WidgetKit, AppIntents, Foundation и UIKit в соответствии с
условиями Apple SDK и программы разработчика.

Если источник или автор указаны неточно, создайте issue с ссылкой на конкретный
файл/набор данных — атрибуция будет исправлена.
