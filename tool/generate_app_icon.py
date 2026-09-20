#!/usr/bin/env python3
"""Uygulama simgesini üretir.

Simge bir vektör tarifi olarak burada durur; PNG'ler bu betikten üretilir.
Böylece boyut listesi değiştiğinde ya da renkler temaya göre güncellendiğinde
simgeyi elle yeniden çizmek gerekmez.

Çalıştırmak için:

    pip install Pillow
    python3 tool/generate_app_icon.py

Tasarım: koyu yeşil zemin üzerinde altın renkli bir mihrap KAPISI (dolu
kemer değil, hat); boşluğunda hilal durur ve eşikten öne doğru genişleyen bir
yol geçer — uygulamanın adı "Namaz Yolu". Dolu kemer denendi ve bırakıldı:
altındaki yol kaideye dönüşüp simge satranç taşına benziyordu. Renkler `lib/core/theme/app_theme.dart` içindeki tohum renk (#0b3d3a)
ve ikincil renkten (#cda45e) alınmıştır.

Küçük boyut belirleyicidir: simge 40 pikselde de okunmalı. Bu yüzden yol iki
kalın dilime bölünür; ince "kaldırım taşları" o ölçekte çamura dönüşürdü.
"""

import json
import os
import subprocess
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Tema renkleri.
GREEN_DARK = (7, 40, 38)
GREEN_LIGHT = (18, 77, 72)
GOLD_TOP = (232, 200, 140)
GOLD_BOTTOM = (186, 143, 74)

# Kenar yumuşatma: her şey bu katsayıyla büyütülüp sonra küçültülür.
SS = 4


def _lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def _background(size):
    """Merkezi hafifçe açılan dikey degrade."""
    image = Image.new("RGB", (size, size), GREEN_DARK)
    draw = ImageDraw.Draw(image)
    for y in range(size):
        # Üstte açık, altta koyu; tepe noktası 0.35 yükseklikte.
        t = abs(y / size - 0.35) / 0.75
        draw.line([(0, y), (size, y)], fill=_lerp(GREEN_LIGHT, GREEN_DARK, min(t, 1.0)))
    return image


def _arch_mask(size, *, width_ratio, apex_ratio, spring_ratio, bottom_ratio):
    """İki merkezli (sivri) mihrap kemerinin maskesi.

    Kemer, yay merkezleri omuz hizasında olan iki dairenin kesişimidir; omuz
    hizasının altı düz gövdedir. Ölçüler dışarıdan verilir: aynı biçim hem dış
    hat hem iç boşluk için kullanılır, ikisinin farkı kapı halkasını verir.
    """
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)

    cx = size / 2
    width = width_ratio * size
    half = width / 2
    spring = spring_ratio * size  # omuz hizası
    apex = apex_ratio * size  # tepe
    bottom = bottom_ratio * size

    height = spring - apex
    # d: yay merkezinin eksenden kayması. h^2 = W^2/4 + W*d denkleminden.
    offset = (height * height - half * half) / width
    radius = half + offset

    draw.rectangle([cx - half, spring, cx + half, bottom], fill=255)
    # Sağ yayın merkezi solda kalır ve tersi; kesişimleri sivri ucu verir.
    left = Image.new("L", (size, size), 0)
    ImageDraw.Draw(left).ellipse(
        [cx - offset - radius, spring - radius, cx - offset + radius, spring + radius],
        fill=255,
    )
    right = Image.new("L", (size, size), 0)
    ImageDraw.Draw(right).ellipse(
        [cx + offset - radius, spring - radius, cx + offset + radius, spring + radius],
        fill=255,
    )
    lens = Image.new("L", (size, size), 0)
    lens.paste(Image.composite(left, Image.new("L", (size, size), 0), right), (0, 0))
    # Yalnızca omuz hizasının üstündeki kısmı al.
    top = Image.new("L", (size, size), 0)
    ImageDraw.Draw(top).rectangle([0, 0, size, spring], fill=255)
    lens = Image.composite(lens, Image.new("L", (size, size), 0), top)

    mask.paste(255, (0, 0), lens)
    return mask


# Kapının dış hattı ve boşluğu. Dolu bir kemer, altındaki her şeyi kaide gibi
# gösteriyordu; kapı olarak çizilince yol içinden geçip derinlik kazanıyor.
DOOR_OUTER = dict(width_ratio=0.52, apex_ratio=0.12, spring_ratio=0.44, bottom_ratio=0.72)
DOOR_INNER = dict(width_ratio=0.36, apex_ratio=0.21, spring_ratio=0.47, bottom_ratio=0.76)


def _door_mask(size):
    """Kapının altın hattı: dış kemerden iç boşluk çıkarılır."""
    outer = _arch_mask(size, **DOOR_OUTER)
    inner = _arch_mask(size, **DOOR_INNER)
    outer.paste(0, (0, 0), inner)
    return outer


def _crescent_mask(size):
    """Kapı boşluğunda duran hilal."""
    # Hilalin görsel ağırlık merkezi oyuk yüzünden sola kayar; kemerin
    # ortasında dursun diye tamamı hafifçe sağa alınır.
    cx = size / 2 + 0.022 * size
    cy = 0.355 * size
    outer = 0.105 * size
    inner = 0.091 * size
    # İç daireyi sağa ve yukarı kaydırmak sola açılan bir hilal bırakır.
    ix = cx + 0.052 * size
    iy = cy - 0.025 * size

    full = Image.new("L", (size, size), 0)
    ImageDraw.Draw(full).ellipse([cx - outer, cy - outer, cx + outer, cy + outer], fill=255)
    cut = Image.new("L", (size, size), 0)
    ImageDraw.Draw(cut).ellipse([ix - inner, iy - inner, ix + inner, iy + inner], fill=255)
    return Image.composite(Image.new("L", (size, size), 0), full, cut)


def _path_mask(size):
    """Kapıdan geçip öne doğru genişleyen yol.

    Perspektif hissi için alt kenarda geniş, kapının eşiğinde dardır. Tek
    parça çizilir: iki dilime bölmek 48 pikselde üst üste binen bantlara
    dönüşüyordu. Bu haliyle aynı zamanda mihraba uzanan bir seccade okuması
    verir.
    """
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)

    cx = size / 2
    top = 0.56 * size  # eşik: kapının boşluğunun içinde başlar
    bottom = 0.83 * size
    half_top = 0.055 * size
    half_bottom = 0.185 * size

    # Yol, kapının tabanından (0.72) geçerken ayakların arasında kalmalı;
    # taştığında kapı bir kaidenin üstünde duruyormuş gibi görünüyor.

    def half_at(y):
        t = (y - top) / (bottom - top)
        return half_top + (half_bottom - half_top) * t

    draw.polygon(
        [
            (cx - half_at(top), top),
            (cx + half_at(top), top),
            (cx + half_at(bottom), bottom),
            (cx - half_at(bottom), bottom),
        ],
        fill=255,
    )
    return mask


def _gold(size):
    image = Image.new("RGB", (size, size), GOLD_TOP)
    draw = ImageDraw.Draw(image)
    for y in range(size):
        draw.line([(0, y), (size, y)], fill=_lerp(GOLD_TOP, GOLD_BOTTOM, y / size))
    return image


def render(size, *, background=True, scale=1.0):
    """Simgeyi `size` piksellik kare olarak üretir.

    `background` kapalıyken yalnızca kemer döner (Android uyarlanabilir
    simgesinin ön planı için). `scale`, ön planı güvenli alana sığdırmak için
    içeriği küçültür.
    """
    work = size * SS
    layer = Image.new("RGBA", (work, work), (0, 0, 0, 0))

    content = int(work * scale)
    arch = _door_mask(content)
    arch.paste(255, (0, 0), _crescent_mask(content))
    arch.paste(255, (0, 0), _path_mask(content))

    gold = _gold(content).convert("RGBA")
    gold.putalpha(arch)
    inset = (work - content) // 2
    layer.paste(gold, (inset, inset), gold)

    if background:
        base = _background(work).convert("RGBA")
        base.alpha_composite(layer)
        layer = base

    return layer.resize((size, size), Image.LANCZOS)


def _write(image, path, *, opaque):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if opaque:
        flat = Image.new("RGB", image.size, GREEN_DARK)
        flat.paste(image, (0, 0), image)
        image = flat
    image.save(path, "PNG", optimize=True)
    print("wrote", os.path.relpath(path, ROOT), image.size)


def build_ios():
    folder = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    with open(os.path.join(folder, "Contents.json")) as handle:
        contents = json.load(handle)
    wanted = {}
    for entry in contents["images"]:
        side, _, _ = entry["size"].partition("x")
        pixels = round(float(side) * float(entry["scale"].rstrip("x")))
        wanted.setdefault(entry["filename"], pixels)
    for filename, pixels in sorted(wanted.items(), key=lambda item: item[1]):
        # App Store simgesi saydam olamaz; hepsini opak yazıyoruz.
        _write(render(pixels), os.path.join(folder, filename), opaque=True)


ANDROID_LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Uyarlanabilir simgede sistem ön planın dış %25'ini kırpabilir; içerik
# güvenli daireye sığsın diye küçültülür.
ADAPTIVE_SAFE = 0.62


def build_android():
    res = os.path.join(ROOT, "android/app/src/main/res")
    for folder, pixels in ANDROID_LEGACY.items():
        _write(
            render(pixels),
            os.path.join(res, folder, "ic_launcher.png"),
            opaque=True,
        )
        # Uyarlanabilir simge katmanları 108dp'lik tuval ister. Zemin düz
        # renk olduğu için PNG değil, values/colors.xml'deki renk kullanılır.
        adaptive = round(pixels * 108 / 48)
        _write(
            render(adaptive, background=False, scale=ADAPTIVE_SAFE),
            os.path.join(res, folder, "ic_launcher_foreground.png"),
            opaque=False,
        )


def main():
    build_ios()
    build_android()
    preview = os.path.join(ROOT, "build", "icon_preview.png")
    os.makedirs(os.path.dirname(preview), exist_ok=True)
    strip = Image.new("RGB", (1024 + 192 + 96 + 48 + 40, 1024), (245, 245, 245))
    x = 0
    for pixels in (1024, 192, 96, 48):
        strip.paste(render(pixels).convert("RGB"), (x, 0))
        x += pixels + 10
    strip.save(preview)
    print("preview", preview)
    subprocess.run(["git", "status", "--short"], cwd=ROOT, check=False)


if __name__ == "__main__":
    main()
