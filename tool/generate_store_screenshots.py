#!/usr/bin/env python3
"""App Store tanıtım görsellerini üretir.

Girdi: gerçek iPhone ekran görüntüleri, `store/screenshots/raw/<dil>/`.
Çıktı: `store/screenshots/<dil>/iphone-NN-<ad>.png`, 1320×2868 (App Store'un
6,9 inç iPhone boyutu). Her görselde uygulamanın renklerinde bir zemin, üstte
başlık ve kısa açıklama, ortada telefon çerçevesi içinde ekran görüntüsü
vardır. Ekran görüntüsünün kendisine dokunulmaz (montaj değildir); yalnızca
widget görüntüsünde başka uygulamaların simgeleri (Dock) duvar kâğıdının
rengiyle örtülür, çünkü mağaza görselinde başka markaların simgesi
bulunmamalı.

    pip install Pillow
    python3 tool/generate_store_screenshots.py

Başlıklar aşağıdaki CAPTIONS tablosundadır; her iddia uygulamada gerçekten
olan bir şeyi anlatmalı (ör. "internetsiz": vakitler cihazda hesaplanır).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "store" / "screenshots" / "raw"
OUT = ROOT / "store" / "screenshots"

WIDTH, HEIGHT = 1320, 2868

GOLD = (242, 191, 89)
CREAM = (245, 240, 227)
TOP = (9, 26, 43)
MIDDLE = (14, 40, 66)
BOTTOM = (8, 38, 33)

TITLE_FONT = ROOT / "assets" / "fonts" / "Amiri-Bold.ttf"
BODY_FONTS = [
    Path("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"),
    Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    Path("/Library/Fonts/Arial Unicode.ttf"),
]

# Mağazadaki sıra. Ad, raw/<dil>/<ad>.jpg dosyasıdır.
ORDER = [
    "home",
    "quran-meal",
    "prayer-guide",
    "widget",
    "home-times",
    "leaf",
    "quran-list",
    "tracker",
]

CAPTIONS = {
    "tr": {
        "home": ("Namaz vakitleri", "Bulunduğunuz yere göre, internetsiz hesaplanır"),
        "quran-meal": (
            "Kur'ân-ı Kerîm ve meali",
            "Arapça metin ve Elmalılı Hamdi Yazır'ın 1935 aslından meal",
        ),
        "prayer-guide": (
            "Namaz nasıl kılınır",
            "Resimli anlatım ve adım adım kıldıran namaz hocası",
        ),
        "widget": (
            "Ana ekranda widget",
            "Sıradaki vakit, kalan süre ve tek dokunuşla kısayollar",
        ),
        "home-times": (
            "Günün bütün vakitleri",
            "Sıradaki namaza ne kadar kaldığı hep önünüzde",
        ),
        "leaf": (
            "Günün takvim yaprağı",
            "Hicrî ve Rumî tarih, Hızır ve Kasım günleri",
        ),
        "quran-list": (
            "114 sûre, 30 cüz",
            "Mushaf sayfalarıyla okuyun, kaldığınız yerden devam edin",
        ),
        "tracker": (
            "Namaz takibi",
            "Kıldığınız vakitleri işaretleyin; kayıt cihazınızda kalır",
        ),
    },
}

# Widget görüntüsünde Dock ve arama düğmesinin başladığı yer (ekran
# görüntüsünün yüksekliğine oranı). Altı duvar kâğıdının rengiyle örtülür.
WIDGET_COVER_FROM = 0.80


def body_font(size: int) -> ImageFont.FreeTypeFont:
    for path in BODY_FONTS:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    sys.exit("Açıklama yazı tipi bulunamadı (Liberation Sans ya da DejaVu Sans).")


def gradient() -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(image)
    for y in range(HEIGHT):
        t = y / (HEIGHT - 1)
        if t < 0.45:
            a, b, u = TOP, MIDDLE, t / 0.45
        else:
            a, b, u = MIDDLE, BOTTOM, (t - 0.45) / 0.55
        color = tuple(round(a[i] + (b[i] - a[i]) * u) for i in range(3))
        draw.line([(0, y), (WIDTH, y)], fill=color)
    return image


def star(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill) -> None:
    """Sekiz köşeli yıldız (iki kare üst üste): uygulamadaki madalyon."""
    for rotation in (0, math.pi / 4):
        points = [
            (
                cx + r * math.cos(rotation + math.pi / 4 + k * math.pi / 2),
                cy + r * math.sin(rotation + math.pi / 4 + k * math.pi / 2),
            )
            for k in range(4)
        ]
        draw.polygon(points, outline=fill, width=3)


def pattern(base: Image.Image) -> Image.Image:
    """Zeminde çok soluk altın yıldız örgüsü."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    step = 220
    for row, y in enumerate(range(-step, HEIGHT + step, step)):
        offset = step // 2 if row % 2 else 0
        for x in range(-step + offset, WIDTH + step, step):
            star(draw, x, y, 46, (*GOLD, 16))
    return Image.alpha_composite(base.convert("RGBA"), layer)


def wrap(text: str, font: ImageFont.FreeTypeFont, width: int) -> list[str]:
    """Satırlara böler; iki satır gerekiyorsa satırları dengeler ki ikinci
    satırda tek bir kelime kalmasın."""
    if font.getlength(text) <= width:
        return [text]
    words = text.split()
    best: list[str] | None = None
    for cut in range(1, len(words)):
        first, second = " ".join(words[:cut]), " ".join(words[cut:])
        if font.getlength(first) > width or font.getlength(second) > width:
            continue
        gap = abs(font.getlength(first) - font.getlength(second))
        if best is None or gap < best[0]:
            best = (gap, [first, second])
    if best is None:
        sys.exit(f"Başlık iki satıra sığmıyor, kısaltın: {text!r}")
    return best[1]


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return mask


def prepare_screen(name: str, path: Path) -> Image.Image:
    screen = Image.open(path).convert("RGB")
    if name == "widget":
        w, h = screen.size
        top = int(h * WIDGET_COVER_FROM)
        wallpaper = screen.getpixel((w // 2, top - 20))
        ImageDraw.Draw(screen).rectangle([0, top, w, h], fill=wallpaper)
    return screen


def widget_card(screen: Image.Image) -> Image.Image:
    """Widget görüntüsünden yalnızca widget'ı ve adını keser.

    Ana ekranın geri kalanı boş duvar kâğıdıdır; telefonun tamamı
    gösterilince widget görselde çok küçük kalıyordu.
    """
    w, h = screen.size
    wallpaper = screen.getpixel((6, h // 2))
    rows = [
        y
        for y in range(int(h * 0.05), int(h * WIDGET_COVER_FROM))
        if any(
            sum(abs(a - b) for a, b in zip(screen.getpixel((x, y)), wallpaper)) > 30
            for x in range(0, w, 6)
        )
    ]
    top, bottom = max(rows[0] - 30, 0), min(rows[-1] + 30, h)
    return screen.crop((0, top, w, bottom))


def compose(language: str, name: str, index: int) -> Path:
    title, subtitle = CAPTIONS[language][name]
    canvas = pattern(gradient())
    draw = ImageDraw.Draw(canvas)

    # Başlık ve açıklama.
    title_font = ImageFont.truetype(str(TITLE_FONT), 112)
    sub_font = body_font(52)
    y = 150
    for line in wrap(title, title_font, 1180):
        width = title_font.getlength(line)
        draw.text(((WIDTH - width) / 2, y), line, font=title_font, fill=GOLD)
        # Amiri'nin satır yüksekliği büyüktür; ayraç harflerin gerçek alt
        # kenarına göre konur, yoksa kuyruklu harflere değer.
        y = draw.textbbox(((WIDTH - width) / 2, y), line, font=title_font)[3] + 18
    # Altın ayraç ve ortasında küçük yıldız.
    y += 18
    draw.line([(WIDTH / 2 - 190, y), (WIDTH / 2 - 34, y)], fill=(*GOLD, 200), width=3)
    draw.line([(WIDTH / 2 + 34, y), (WIDTH / 2 + 190, y)], fill=(*GOLD, 200), width=3)
    star(draw, WIDTH / 2, y, 16, (*GOLD, 255))
    y += 40
    for line in wrap(subtitle, sub_font, 1120):
        width = sub_font.getlength(line)
        draw.text(((WIDTH - width) / 2, y), line, font=sub_font, fill=(*CREAM, 225))
        y += 68

    if name == "widget":
        return save(language, name, index, place_widget(canvas, y))

    # Telefon: ekran görüntüsü, koyu çerçeve ve gölge.
    screen = prepare_screen(name, RAW / language / f"{name}.jpg")
    screen_w = 1000
    screen_h = round(screen.height * screen_w / screen.width)
    screen = screen.resize((screen_w, screen_h), Image.LANCZOS)
    bezel = 26
    radius = 128
    device_w, device_h = screen_w + 2 * bezel, screen_h + 2 * bezel
    device_x = (WIDTH - device_w) // 2
    device_y = max(y + 60, HEIGHT - device_h - 70)

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [device_x + 10, device_y + 40, device_x + device_w - 10, device_y + device_h + 30],
        radius + bezel,
        fill=(0, 0, 0, 150),
    )
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(40)))

    device = Image.new("RGBA", (device_w, device_h), (0, 0, 0, 0))
    device_draw = ImageDraw.Draw(device)
    device_draw.rounded_rectangle(
        [0, 0, device_w - 1, device_h - 1], radius + bezel, fill=(16, 18, 20, 255)
    )
    device_draw.rounded_rectangle(
        [2, 2, device_w - 3, device_h - 3], radius + bezel - 2, outline=(92, 98, 104, 255), width=3
    )
    device.paste(screen, (bezel, bezel), rounded_mask((screen_w, screen_h), radius))
    canvas.alpha_composite(device, (device_x, device_y))

    return save(language, name, index, canvas)


def place_widget(canvas: Image.Image, top: int) -> Image.Image:
    """Widget'ı büyütülmüş olarak, telefon ekranının duvar kâğıdı renginde
    yuvarlak bir panelin üstünde gösterir."""
    raw = Image.open(RAW / "tr" / "widget.jpg").convert("RGB")
    card = widget_card(raw)
    scale = 1180 / card.width
    card = card.resize((1180, round(card.height * scale)), Image.LANCZOS)
    panel_w, panel_h = card.width, card.height + 120
    x = (WIDTH - panel_w) // 2
    y = top + (HEIGHT - top - panel_h) // 2 - 80
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x + 10, y + 40, x + panel_w - 10, y + panel_h + 30], 90, fill=(0, 0, 0, 150)
    )
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(40)))
    panel = Image.new("RGB", (panel_w, panel_h), raw.getpixel((6, raw.height // 2)))
    panel.paste(card, (0, 60))
    canvas.paste(panel, (x, y), rounded_mask((panel_w, panel_h), 90))
    return canvas


def save(language: str, name: str, index: int, canvas: Image.Image) -> Path:
    final = canvas.convert("RGB")
    assert final.size == (WIDTH, HEIGHT)
    target = OUT / language / f"iphone-{index:02d}-{name}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    final.save(target, optimize=True)
    return target


def main() -> None:
    for language, captions in CAPTIONS.items():
        missing = [n for n in ORDER if not (RAW / language / f"{n}.jpg").exists()]
        if missing:
            sys.exit(f"{language}: ekran görüntüsü eksik: {', '.join(missing)}")
        assert set(captions) == set(ORDER), f"{language}: başlık tablosu eksik"
        for index, name in enumerate(ORDER, start=1):
            print(compose(language, name, index).relative_to(ROOT))


if __name__ == "__main__":
    main()
