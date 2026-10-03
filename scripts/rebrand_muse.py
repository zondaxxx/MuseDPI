from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {'.md', '.swift', '.kt', '.xml', '.strings', '.yml', '.sh', '.kts', '.py', '.pbxproj', '.plist', '.txt'}
SKIP = {'.git', '.build', 'build', '.gradle', '.cxx', 'packages', 'byedpi', 'hev-socks5-tunnel'}

for filename in ROOT.rglob('*'):
    if not filename.is_file() or filename.suffix not in TEXT_SUFFIXES or any(part in SKIP for part in filename.relative_to(ROOT).parts):
        continue
    if filename == Path(__file__).resolve():
        continue
    original = filename.read_text()
    updated = original.replace('github.com/zondaxxx/PalkaDPI', 'github.com/zondaxxx/MuseDPI')
    updated = updated.replace('raw.githubusercontent.com/zondaxxx/PalkaDPI', 'raw.githubusercontent.com/zondaxxx/MuseDPI')
    if filename.suffix in {'.md', '.strings', '.xml', '.plist', '.pbxproj', '.yml', '.sh', '.txt'}:
        updated = updated.replace('PalkaDPI', 'MuseDPI')
        updated = updated.replace('palka-banner.png', 'muse-banner.png')
        updated = updated.replace('palka-banner.svg', 'muse-icon.svg')
    elif filename.suffix in {'.swift', '.kt'}:
        updated = re.sub(r'"([^"\n]*)"', lambda match: '"' + match[1].replace('PalkaDPI', 'MuseDPI') + '"', updated)
    if updated != original:
        filename.write_text(updated)
