# MuseDPI 0.4.2

This release fixes the automatic strategy test lifecycle.

## Fixed

- A call to `startVPNTunnel()` is no longer treated as an established connection.
- Service probes begin only after iOS reports `NEVPNStatus.connected`.
- The next strategy begins only after iOS reports the previous tunnel as disconnected.
- Fixed 0.9/1.4-second delays were removed from automatic selection.
- Connection and disconnection now have explicit timeouts with visible errors.
- The automatic-selection screen shows its current VPN lifecycle stage.

The same state-aware lifecycle is now used by manual disconnect, smart recovery,
and per-network profile switching.
