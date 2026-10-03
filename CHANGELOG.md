# CHANGELOG

## MuseDPI rebrand — 03.10.2026

- Compact connection cards bring service responses closer to the first screen on both platforms.
- Home-screen HTTP checks skip bulk downloads; full diagnostics and strategy verification retain the 256 KB transfer test.
- Service descriptions reflect the selected services instead of always claiming Discord and YouTube are covered.
- iOS settings use proportional text, and primary buttons respect Reduce Motion.
- Existing GitHub release titles now distinguish MuseDPI iOS and Android without changing tags or historical binaries.
- iOS and Android now display MuseDPI, with a wave-shaped m, new icons and a marine palette.
- Repository renamed to zondaxxx/MuseDPI; catalog links and build artifact names updated.
- Preserve application IDs, saved settings and signed catalog compatibility.
- Android catalog downloads are bounded while reading, preventing oversized responses from exhausting memory.
- iOS download instructions no longer use the shared latest-release link, which can point to Android.

## MuseDPI for Android 0.5.0

### 23.09.2026

- New interface identical to the iOS app, rebuilt in Jetpack Compose: dark grid background, cards, white buttons, pulsing status, entrance and press animations; texts are generated from the iOS `Localizable.strings` (`scripts/sync_android_strings.py`)
- Home: connection card with tunnel traffic counters, smart recovery suggestion, automatic setup, service response (HTTP round trip), active preset, connection log
- Automatic setup: stops the VPN once, checks every signed catalog strategy through an in-process ByeDPI core on 127.0.0.1:10801 (marker probes + 256 KB bulk download with TSPU stall detection), applies the best, remembers it for the current network and connects
- Extended search (Android only): adds the 60 ByeByeDPI strategies with TCP fakes (`-f`, TTL) to automatic setup
- Protected services with custom domains, catalog with search/favorites/rollback, favorites and history with reliability, diagnostics (DNS/TLS/HTTP/256 KB) with a private JSON report
- Networks: Wi-Fi/mobile strategy profiles that switch automatically on network change, autostart on boot, connect on launch, Android always-on VPN and battery shortcuts, smart recovery and QUIC blocking
- Android only: split tunnelling by app, VPN or SOCKS5-proxy mode, quick settings tile; the classic ByeByeDPI screen and every engine parameter stay under expert settings (now dark themed)
- MuseDPI launcher icon, TV banner and the in-app icon replace the upstream ones
- The signed catalog loads in release builds again (in 0.1.0 R8 stripped the Gson models and the catalog failed with "unsupported schema 0")

## MuseDPI 0.4.7

### 14.09.2026

- Automatic setup can no longer stall: every step (VPN stop/start, pre-check, each tunnel test) has a hard deadline and moves on when a callback never arrives
- The pre-check core listens on 127.0.0.1:10801 so it never collides with the packet tunnel extension that is still releasing port 10800
- The next pre-check strategy waits for the previous ByeDPI core thread to exit before starting (fixes a race on the process-global listener)
- Pre-check shows live progress per strategy; a run log with timestamps is shown on the automation screen
- When none of the shortlisted strategies works through the tunnel, the remaining catalog strategies are tested instead of giving up

## MuseDPI 0.4.6

### 14.09.2026

- Added `-k, --udp-drop` to the embedded ByeDPI core and a "Block QUIC (UDP 443)" switch (on by default): HTTP/3 clients such as the YouTube app fall back to TCP immediately instead of hanging until QUIC times out
- Automatic setup now pre-checks every catalog strategy with the in-process SOCKS listener and confirms only the best three through the packet tunnel, cutting a full run roughly in half
- Diagnostics download a 256 KB object from the real delivery host of each service (ytimg, discord.com, instagram.com, tiktok.com, telegram.org) and detect the TSPU "connects, then freezes" pattern; stalled services are ranked below working ones and shown with throughput
- Screen lock no longer reports the tunnel as disconnected in the widget and home screen
- Smart recovery probes run every two minutes and only while the app is in the foreground
- Core changes now live in `Sources/ByeDPIC/patches/` and `update_byedpi.sh` re-applies them, so refreshing upstream byedpi no longer silently drops the hex payload support

## MuseDPI 0.4.5 / 0.4.4

### 22.08.2026

- Bundle branding, tunnel transport verification, runtime logs and bounded strategy tests (see git history)

## MuseDPI 0.4.3

### 22.08.2026

- Added an independent hard deadline to every HTTP probe so a dead packet tunnel cannot stall automatic selection
- Replaced zero-filled UDP fakes with the current Flowseal QUIC and Discord payloads
- Added inline hex payload support to the embedded Apple ByeDPI build
- Rebuilt the signed catalog as six distinct iOS strategies and revoked all ineffective v1/v2 profiles
- Migrated installed v1/v2 configurations to a safe native multisplit fallback
- Replaced the inherited app icon with the MuseDPI packet-split mark
- Renamed user-facing engine, proxy, editor, tunnel, and analyzer labels to MuseDPI
- Added exact Flowseal/bol-van payload attribution, checksums, and MIT license text

## MuseDPI 0.4.2

### 22.08.2026

- Fixed automatic selection starting probes before the system VPN had connected
- Wait for real NetworkExtension `connected` and `disconnected` states instead of fixed delays
- Show whether auto-selection is stopping, connecting, or probing through the tunnel
- Added explicit start/stop timeouts and surfaced lifecycle errors
- Fixed manual and network-profile reconnection flows to wait for actual VPN state transitions

## MuseDPI 0.4.1

### 22.08.2026

- Replaced ineffective v1 presets with independent upstream iOS-compatible strategies
- Added QUIC/UDP 443 fallback variants
- Require expected official service response content during automatic selection
- Reject HTTP error responses and cross-host block-page redirects
- Fixed the Telegram diagnostic endpoint

## MuseDPI 0.4.0

### 22.08.2026

- Automatic strategy selection and per-network profiles
- Discord, YouTube, Instagram, TikTok, X/Twitter, Telegram, and custom targets
- Multi-sample DNS/TLS/HTTP diagnostics and smart recovery
- On Demand rules for Wi-Fi and cellular
- Signed Ed25519 strategy catalog with compatibility, revocation, and rollback
- Search, favorites, application history, and local success statistics
- WidgetKit status widget and Siri/Shortcuts actions
- Privacy-preserving support report

## Version 0.17.3

### 10.04.2026

**Library changes**

- Added new test domains (Google Meet, AI, Play)
- Added new strategies (Retrieved from TG channels)
- Ephemeral HTTP/SOCKS proxy URLSession support
- byedpi (C) updater

**Example app changes**

- NE VPN status notifier (CFNotificationCenter)
- VPN start from system settings fix - use protocolConfiguration
- Multiple alert view modifies show fix
- Strategy test result card view update
- Use .id view modifier for list item views
- Static library build support (XCode) for leverage App Store Connect nested frameworks restriction (BBD: SwByeDPI - ByeDPIKit - ByeDPIC; BBDTun: ByeDPIKit - ByeDPIC)

### 01.04.2026

- Initial release
