from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
NAVY = '#06131c'
FOAM = '#dff5f1'
SEA = '#4dc4c2'

def mark(size, transparent=False):
    scale = 4
    canvas = Image.new('RGBA', (size * scale, size * scale), (0, 0, 0, 0) if transparent else NAVY)
    draw = ImageDraw.Draw(canvas)
    extent = size * scale
    points = []
    for index in range(401):
        position = index / 400
        horizontal = (0.23 + 0.54 * position) * extent
        vertical = (0.60 - 0.25 * abs(math.sin(position * math.pi * 2))) * extent
        points.append((horizontal, vertical))
    width = round(extent * 0.068)
    draw.line(points, fill=FOAM, width=width)
    for horizontal, vertical in points:
        radius = width / 2
        draw.ellipse((horizontal-radius, vertical-radius, horizontal+radius, vertical+radius), fill=FOAM)
    wave = [(extent * (0.23 + 0.54 * index / 400), extent * (0.72 + 0.024 * math.sin(index / 400 * math.pi * 2))) for index in range(401)]
    wave_width = round(extent * 0.018)
    draw.line(wave, fill=SEA, width=wave_width)
    for horizontal, vertical in wave:
        radius = wave_width / 2
        draw.ellipse((horizontal-radius, vertical-radius, horizontal+radius, vertical+radius), fill=SEA)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)

def main():
    assets = ROOT / 'RepoAssets'
    logo = mark(1024)
    logo.convert('RGB').save(assets / 'muse-icon.png')
    svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><rect width="1024" height="1024" rx="224" fill="#06131c"/><path d="M236 614 C236 274 512 274 512 614 C512 274 788 274 788 614" fill="none" stroke="#dff5f1" stroke-width="70" stroke-linecap="round"/><path d="M236 737 C420 687 604 787 788 737" fill="none" stroke="#4dc4c2" stroke-width="18" stroke-linecap="round"/></svg>'
    (assets / 'muse-icon.svg').write_text(svg)
    for name in ('palka-icon.svg', 'app.svg'):
        (assets / name).write_text(svg)
    for folder in (ROOT / 'Example').rglob('AppIcon.appiconset'):
        contents = json.loads((folder / 'Contents.json').read_text())
        for entry in contents['images']:
            if 'filename' in entry:
                dimension = round(float(entry['size'].split('x')[0]) * float(entry.get('scale', '1x')[:-1]))
                logo.resize((dimension, dimension), Image.Resampling.LANCZOS).convert('RGB').save(folder / entry['filename'])
    for filename in (ROOT / 'Example').rglob('appIconRounded.png'):
        logo.save(filename)
    resources = ROOT / 'android/app/src/main/res'
    for folder in resources.glob('mipmap-*dpi'):
        dimensions = {'mdpi':48, 'hdpi':72, 'xhdpi':96, 'xxhdpi':144, 'xxxhdpi':192}
        dimension = dimensions.get(folder.name.removeprefix('mipmap-'))
        if dimension:
            for name in ('ic_launcher.webp', 'ic_launcher_round.webp', 'ic_launcher_foreground.webp'):
                mark(dimension, transparent='foreground' in name).save(folder / name, lossless=True)
    mark(512).save(resources / 'drawable-nodpi/palka_app_icon.png')
    mark(432, transparent=True).save(resources / 'drawable-nodpi/palka_launcher_monochrome.png')
    banner = Image.new('RGB', (1600, 520), NAVY)
    banner.paste(mark(360).convert('RGB'), (75, 80))
    draw = ImageDraw.Draw(banner)
    font_path = '/System/Library/Fonts/Supplemental/Arial.ttf'
    draw.text((490, 140), 'MuseDPI', fill=FOAM, font=ImageFont.truetype(font_path, 108))
    draw.text((495, 283), 'A calmer connection.', fill=SEA, font=ImageFont.truetype(font_path, 35))
    draw.text((495, 355), 'iOS  /  Android  /  local DPI bypass', fill='#96b5c2', font=ImageFont.truetype(font_path, 24))
    banner.save(assets / 'muse-banner.png')
    banner.resize((320, 104)).save(resources / 'mipmap-xhdpi/ic_banner.png')

if __name__ == '__main__':
    main()
