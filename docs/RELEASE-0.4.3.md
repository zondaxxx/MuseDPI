# MuseDPI 0.4.3

This release replaces the previous approximation with strategies that match the
capabilities of the Apple ByeDPI build.

## Fixed

- Every service probe has an independent eight-second deadline. Automatic
  selection advances even when `URLSession` never reports a timeout through a
  broken Packet Tunnel.
- All v1/v2 online strategies are revoked and installed legacy selections are
  migrated to a native TCP multisplit fallback.
- The default UDP fake no longer sends 64 zero bytes.

## Strategies

- The signed catalog contains six separate candidates so automatic selection
  tests one technique at a time.
- Two Flowseal-derived candidates embed the current 1200-byte QUIC Initial and
  Discord UDP decoy payloads.
- Raw-packet `fake`, sequence overlap, bad checksum, and WinDivert/NFQUEUE
  options are not claimed on iOS. TCP candidates use split, TLS record, OOB,
  HTTP morphing, and an explicitly experimental disorder fallback.

## Branding

- Added the MuseDPI fragmented-P app icon and repository mark.
- The main app, widget, VPN profile, tunnel display name, shortcuts, and
  user-facing expert labels consistently use MuseDPI.
