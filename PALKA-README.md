# MuseDPI for iOS

MuseDPI is a local, system-wide DPI bypass prototype for iOS 14 and newer. It
uses `NEPacketTunnelProvider`, `Tun2SocksKit`, and the native ByeDPI core. No
remote VPN server is used: outbound connections leave directly from the phone.

The app can target Discord, YouTube, Instagram, TikTok, X/Twitter, Telegram,
and user-supplied domains. Automatic setup tests signed catalog strategies on
the current network, keeps the best result, and can remember separate choices
for Wi-Fi and cellular. Other traffic is passed through without a DPI strategy.

## What you need to sign it

A certificate alone is not enough for the VPN target. Your Apple Developer
account must also have identifiers and provisioning profiles for:

- Host app: `<your bundle id>`
- Widget extension: `<your bundle id>.widget`
- Packet Tunnel extension: `<your bundle id>.tun`
- App Group: for example `group.<your bundle id>`
- App Groups capability on all three identifiers
- Network Extensions capability with `packet-tunnel-provider` on the tunnel only

Use the same App Group in all three provisioning profiles. A paid Apple Developer
Program membership is normally required for the packet-tunnel entitlement.

## Build and run from Xcode

1. Install full Xcode and open `SwByeDPI.xcodeproj`.
2. Select the `ByeByeDPI` scheme.
3. In Signing & Capabilities, choose your Team for `ByeByeDPI`, `PalkaWidget`,
   and `ByeByeDPITun`.
4. Replace `PALKA_BUNDLE_ID` and `PALKA_APP_GROUP` with your registered values.
   Extension IDs are generated as `$(PALKA_BUNDLE_ID).widget` and
   `$(PALKA_BUNDLE_ID).tun`.
5. Connect the iPhone, select it as the destination, and press Run.
6. On first start, tap the power button and accept the iOS VPN configuration.

You can also archive from Terminal without editing the project:

```bash
xcodebuild \
  -project SwByeDPI.xcodeproj \
  -scheme ByeByeDPI \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath packages/MuseDPI.xcarchive \
  -allowProvisioningUpdates \
  archive \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  PALKA_BUNDLE_ID=your.unique.palkadpi \
  PALKA_APP_GROUP=group.your.unique.palkadpi
```

## Build an unsigned IPA

With full Xcode selected:

```bash
PALKA_BUNDLE_ID=your.unique.palkadpi \
PALKA_APP_GROUP=group.your.unique.palkadpi \
./scripts/build_unsigned_ipa.sh
```

The result is `packages/MuseDPI-unsigned.ipa`. When signing manually, sign the
embedded `PalkaWidget.appex`, then `ByeByeDPITun.appex`, and the host app last.
All signatures must contain the same App Group; only the tunnel extension must
retain the `packet-tunnel-provider` entitlement.

## Test checklist

1. Test on a physical device (the iOS simulator cannot validate the tunnel).
2. Verify ordinary sites still work before testing blocked resources.
3. Select the required services, run Automatic setup, and verify its selected
   strategy on Wi-Fi and cellular.
4. Test media, login, calls, and messages separately where relevant.
5. Enable On Demand and confirm the saved Wi-Fi/cellular profiles switch after
   changing networks.
6. Add the MuseDPI widget and run the Siri/Shortcuts start, stop, toggle, and
   service-check actions.
7. If access fails, inspect Settings -> Diagnostics and try the offered fallback
   or a previous signed catalog generation.

## Known limits

- This is not a byte-for-byte port of Flowseal/zapret. iOS does not expose
  WinDivert, NFQUEUE, arbitrary raw TCP injection, or per-app VPN selection to a
  normal developer-signed app.
- QUIC uses UDP/443 and cannot be filtered by SNI with this core. By default
  MuseDPI drops UDP/443 inside the tunnel (`--udp-drop`, Settings -> "Block
  QUIC"), so HTTP/3 clients fall back to TCP/TLS at once; games, calls and other
  UDP apps use different ports and keep working. Turn it off if a site needs QUIC.
- DPI strategies depend on the ISP. The included strategy is a conservative
  starting point, not a universal guarantee.
- iOS 15 or newer is recommended because Network Extension has a larger memory
  allowance than older releases.

## License and provenance

This project is derived from
[mIwr/SwByeDPI](https://github.com/mIwr/SwByeDPI), which embeds
[hufrea/byedpi](https://github.com/hufrea/byedpi). The combined source is
distributed under the included AGPL-3.0 license; the embedded byedpi core keeps
its upstream MIT license notice.

MuseDPI has no accounts, analytics, or remote VPN service. See
[`docs/PRIVACY.md`](./docs/PRIVACY.md) for the exact local data and network
requests used by diagnostics and catalog updates.
