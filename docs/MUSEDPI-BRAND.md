# MuseDPI

MuseDPI replaces the PalkaDPI product name. The mark is a lowercase **m** formed
by two wave crests, with a restrained sea-green horizon underneath.

- Deep water: `#06131c`
- Surface: `#122430`
- Sea glass: `#4dc4c2`
- Foam: `#dff5f1`

Both native apps use quiet wave contours, generous spacing and rounded surfaces.
Secondary text remains readable; decorative waves never intercept touches.
Brand assets are regenerated with `python3 scripts/muse_brand.py`.

## Upgrade compatibility

Existing application IDs, App Groups, preference keys, strategy IDs and catalog
verification keys are intentionally preserved. Renaming them would break signed
updates, saved profiles or existing provisioning. Internal `Palka*` symbols are
compatibility names, not user-facing branding. Signed catalog bytes are unchanged.

The repository is now `zondaxxx/MuseDPI`. Historical release files keep their
original filenames; new iOS builds produce `MuseDPI-unsigned.ipa`.
