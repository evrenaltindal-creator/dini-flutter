#!/usr/bin/env python3
"""Web sitesi için tanıtım paketi üretir.

Çıktılar `docs/promo/` altına yazılır:

* `icons/` — favicon (16/32/48 + .ico), apple-touch-icon, PWA simgeleri ve
  Android'in kırptığı maskelenebilir sürüm.
* `banner-og.png` — bağlantı paylaşımında görünen 1200x630 kart.
* `hero.png` — site başlığı için geniş görsel.
* `ekranlar.png` — üç ekran görüntüsü yan yana.
* `ekranlar/*.png` — tek tek çerçevelenmiş ekran görüntüleri.

Ekran görüntüleri gerçek uygulamadan alınır; bu betik onları üretmez, yalnızca
`build/promo_shots/` altında bulduklarını çerçeveler. Klasör boşsa ekranlı
çıktılar atlanır ve betik bunu söyler.

Simge, uygulamanın kendi simgesiyle aynı kaynaktan gelir:
`tool/generate_app_icon.py` içindeki `render()`. Böylece sitedeki simge ile
telefondaki simge ayrışamaz.

    pip install Pillow
    python3 tool/generate_web_assets.py
"""

import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import generate_app_icon as icon

ROOT = icon.ROOT
OUT = os.path.join(ROOT, "docs/promo")
SHOTS = os.path.join(ROOT, "build/promo_shots")

# Tasarımın renkleri; degradenin iki ucundan okundu.
INK = (14, 40, 66)
DEEP = (12, 52, 60)
GOLD = (214, 178, 106)
CREAM = (243, 236, 222)

FONT_DIR = "/usr/share/fonts/truetype/dejavu"


def _font(size, *, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    path = os.path.join(FONT_DIR, name)
    if not os.path.exists(path):
        raise SystemExit(
            f"yazı tipi yok: {path}. Banner metinleri bu yazı tipiyle çizilir."
        )
    return ImageFont.truetype(path, size)


def _wrap(text, font, width):
    """Metni ölçerek satırlara böler.

    Satır sonlarını elle koymak tuzak: yazı tipi değişince ya da dil
    değişince satır tuvalden taşıyordu. Burada her kelime ölçülüyor.
    """
    lines, line = [], ""
    for word in text.split():
        candidate = f"{line} {word}".strip()
        if font.getlength(candidate) <= width or not line:
            line = candidate
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return "\n".join(lines)


def _save(image, *relative):
    path = os.path.join(OUT, *relative)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, "PNG", optimize=True)
    print("wrote", os.path.relpath(path, ROOT), image.size)
    return path


def build_icons():
    """Sitenin ve PWA'nın istediği boyutlar."""
    for size in (16, 32, 48, 64, 180, 192, 256, 512, 1024):
        _save(icon.render(size).convert("RGB"), "icons", f"icon-{size}.png")

    # favicon.ico tek dosyada birkaç boyut taşır; tarayıcı uygunu seçer.
    path = os.path.join(OUT, "icons", "favicon.ico")
    icon.render(256).convert("RGB").save(
        path, sizes=[(16, 16), (32, 32), (48, 48), (64, 64)]
    )
    print("wrote", os.path.relpath(path, ROOT))

    # Maskelenebilir simge: Android simgeyi daireye kırpar, bu yüzden tasarım
    # güvenli daireye sığacak kadar küçültülür ve etrafı zeminle doldurulur.
    size = 512
    canvas = icon.render_background(size).convert("RGB")
    content = round(size * icon.ADAPTIVE_SAFE)
    art = icon.render(content).convert("RGBA")
    inset = (size - content) // 2
    canvas.paste(art, (inset, inset), _round_mask(art.size, radius=content // 2))
    _save(canvas, "icons", "icon-maskable-512.png")


def _round_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def _backdrop(size):
    """Degrade zemin; simgenin renklerinden köşegen geçiş."""
    width, height = size
    base = Image.new("RGB", (2, 2))
    base.putpixel((0, 0), INK)
    base.putpixel((1, 0), DEEP)
    base.putpixel((0, 1), (INK[0] - 4, INK[1] - 10, INK[2] - 12))
    base.putpixel((1, 1), (DEEP[0], DEEP[1] - 8, DEEP[2] - 10))
    canvas = base.resize((width, height), Image.BICUBIC)

    # Sağ üstte yumuşak bir altın parıltı; kart düz durmasın.
    glow = Image.new("L", (width, height), 0)
    ImageDraw.Draw(glow).ellipse(
        (width * 0.55, -height * 0.5, width * 1.35, height * 0.75), fill=40
    )
    glow = glow.filter(ImageFilter.GaussianBlur(width // 12))
    return Image.composite(Image.new("RGB", (width, height), GOLD), canvas, glow)


def _frame(shot, *, width, radius=42, border=3):
    """Ekran görüntüsünü yuvarlatılmış bir telefon çerçevesine oturtur."""
    ratio = shot.size[1] / shot.size[0]
    height = round(width * ratio)
    shot = shot.convert("RGB").resize((width, height), Image.LANCZOS)

    card = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    card.paste(shot, (0, 0), _round_mask((width, height), radius))
    edge = ImageDraw.Draw(card)
    edge.rounded_rectangle(
        (0, 0, width - 1, height - 1),
        radius,
        outline=GOLD + (170,),
        width=border,
    )
    return card


def _shadowed(card, blur=26, offset=(0, 14), spread=40):
    """Karta yumuşak gölge; zeminden ayrılsın."""
    width = card.size[0] + spread * 2
    height = card.size[1] + spread * 2
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    shadow.paste(
        Image.new("RGBA", card.size, (0, 0, 0, 150)),
        (spread + offset[0], spread + offset[1]),
        card,
    )
    layer = Image.alpha_composite(layer, shadow.filter(ImageFilter.GaussianBlur(blur)))
    layer.paste(card, (spread, spread), card)
    return layer


def _shots(*names):
    found = []
    for name in names:
        path = os.path.join(SHOTS, f"{name}.png")
        if os.path.exists(path):
            found.append(Image.open(path))
    return found


def build_banner():
    """Bağlantı kartı (Open Graph / Twitter): 1200x630."""
    width, height = 1200, 630
    canvas = _backdrop((width, height)).convert("RGBA")

    medallion = icon.render(360, background=False, scale=1.0)
    canvas.paste(medallion, (78, (height - 360) // 2), medallion)

    draw = ImageDraw.Draw(canvas)
    left = 500
    draw.text((left, 214), "Namaz Yolu", font=_font(84, bold=True), fill=CREAM)
    draw.text(
        (left, 322),
        "Namaz vakitleri, kıble ve ibadet takibi",
        font=_font(32),
        fill=GOLD,
    )
    body = _font(28)
    draw.text(
        (left, 376),
        _wrap(
            "Her şey cihazında hesaplanır. Hesap yok, reklam yok, izleme yok.",
            body,
            width - left - 72,
        ),
        font=body,
        fill=(210, 220, 224),
        spacing=12,
    )
    draw.line((left, 196, left + 96, 196), fill=GOLD, width=4)
    return _save(canvas.convert("RGB"), "banner-og.png")


def build_hero():
    """Site başlığı görseli: 1600x900, sağda telefonlar."""
    width, height = 1600, 900
    canvas = _backdrop((width, height)).convert("RGBA")

    draw = ImageDraw.Draw(canvas)
    draw.line((96, 250, 192, 250), fill=GOLD, width=5)
    draw.text((96, 276), "Namaz Yolu", font=_font(92, bold=True), fill=CREAM)
    lede = _font(40)
    draw.text(
        (96, 400),
        _wrap("Vakitler, kıble ve hicri takvim cihazının içinde hesaplanır.", lede, 640),
        font=lede,
        fill=GOLD,
        spacing=14,
    )
    note = _font(26)
    draw.text(
        (96, 548),
        "Üç dil · Çevrimdışı · Hesap gerekmez\nReklam yok · İzleme yok · Konum cihazdan çıkmaz",
        font=note,
        fill=(205, 216, 222),
        spacing=14,
    )

    shots = _shots("home", "qibla", "tracker")
    if not shots:
        print("ekran görüntüsü yok, hero düz kalıyor")
        return _save(canvas.convert("RGB"), "hero.png")

    # Öndeki telefon büyük, arkadakiler yana kaçık; sıradan bir vitrin
    # düzeni. Konumlar kartın SOL ÜST köşesini gösterir; gölge payı
    # (`_shadowed` çerçeveyi büyütür) çıkarılır, yoksa sağdaki telefon
    # tuvalden taşıyordu.
    spread = 40
    layout = [(shots[0], 420, (1000, 130))]
    if len(shots) > 1:
        layout.insert(0, (shots[1], 300, (1258, 300)))
    if len(shots) > 2:
        layout.insert(0, (shots[2], 300, (836, 330)))
    for shot, shot_width, position in layout:
        card = _shadowed(_frame(shot, width=shot_width))
        canvas.alpha_composite(
            card, (position[0] - spread, position[1] - spread)
        )
    return _save(canvas.convert("RGB"), "hero.png")


def build_screens():
    shots = _shots("home", "qibla", "imsakiye", "tracker", "worship", "calendar", "tasbih")
    if not shots:
        print("build/promo_shots boş: ekran görselleri atlandı")
        return
    for name in ("home", "qibla", "imsakiye", "tracker", "worship", "calendar", "tasbih"):
        path = os.path.join(SHOTS, f"{name}.png")
        if not os.path.exists(path):
            continue
        card = _shadowed(_frame(Image.open(path), width=520))
        plate = _backdrop(card.size).convert("RGBA")
        plate.alpha_composite(card)
        _save(plate.convert("RGB"), "ekranlar", f"{name}.png")

    trio = shots[:3]
    gap, shot_width = 48, 460
    cards = [_shadowed(_frame(shot, width=shot_width)) for shot in trio]
    width = sum(card.size[0] for card in cards) + gap * (len(cards) - 1) + 80
    height = max(card.size[1] for card in cards) + 80
    canvas = _backdrop((width, height)).convert("RGBA")
    x = 40
    for card in cards:
        canvas.alpha_composite(card, (x, (height - card.size[1]) // 2))
        x += card.size[0] + gap
    _save(canvas.convert("RGB"), "ekranlar.png")


def main():
    build_icons()
    build_banner()
    build_hero()
    build_screens()


if __name__ == "__main__":
    main()
