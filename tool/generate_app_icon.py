#!/usr/bin/env python3
"""Uygulama simgesini üretir.

Kaynak, `assets/branding/app_icon_source.png` dosyasındaki 1024x1024
tasarımdır: degrade zemin üzerinde altın hatlı cami, pusula, halkalar ve
vakit adları.

Kaynak tasarımda iki yazı bloğu vardır ("Huzur Rehberi" ve "Namazlar");
uygulamanın adı yalnızca **Namaz Yolu** olduğu için ikisi de burada silinir.
Silme el ile yapılmaz: yazının altın pikselleri bağlı bileşen olarak bulunur,
kenarına taşan yumuşamayla birlikte maskelenir ve yerine satır satır
enterpolasyonla zeminin degradesi yazılır. Böylece kaynak dosya olduğu gibi
kalır, çıktı temizlenir.

Kaynak **tam kenar** olmalıdır: kare, saydamlıksız, köşeleri yuvarlatılmamış
ve etrafında "saydamlık" damalı deseni çizilmemiş. iOS ve Android simgeye
kendi maskesini uygular; hazır yuvarlatılmış ya da damalı bir kaynak köşede
beyaz kırıntı veya dama tahtası olarak görünür. `_source` bunları kontrol
eder ve sessizce kabul etmez.

Uyarlanabilir (Android) simgede sistem ön planın dışını kırpar; güvenli daire
tuvalin %30,5'idir. Tasarımın altın içeriği tuval yarı-genişliğinin %88'ine
kadar uzandığı için ön plan küçültülür — ölçüldü, tahmin edilmedi. Zemin
degrade olduğu için uyarlanabilir simgenin zemini de düz renk değil, üretilen
bir PNG katmanıdır.

Çalıştırmak için:

    pip install Pillow
    python3 tool/generate_app_icon.py
"""

import json
import os
import subprocess
from collections import deque
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SOURCE = os.path.join(ROOT, "assets/branding/app_icon_source.png")

# Kaynak tasarım yalnızca bu betik tarafından, derleme öncesinde okunur.
# `pubspec.yaml` içindeki `assets:` listesine EKLENMEZ: uygulama onu çalışma
# anında yüklemiyor, eklemek pakete boşuna yer bindirirdi.

# Altın içeriğin merkeze uzaklığı / tuval yarı-genişliği. Ölçülerek bulundu;
# tasarım değişirse yeniden ölçülmelidir.
CONTENT_EXTENT = 0.88

# Uyarlanabilir simgenin güvenli dairesi: tuvalin %30,5'i.
SAFE_RADIUS = 0.305

# Ön planın küçültme oranı; içerik güvenli daireye bu oranla sığar.
ADAPTIVE_SAFE = SAFE_RADIUS / (CONTENT_EXTENT / 2)

_cache = {}

# Silinecek yazı blokları (sol, üst, sağ, alt). Kaynak 1024x1024 olduğu için
# piksel cinsindendir ve tasarımdan ÖLÇÜLDÜ: üstteki kuşak madalyonun içinde,
# kubbe ile iç halka arasındaki düz zemine oturur; alttaki, halkanın tamamen
# dışındadır. Kutular yalnızca düz zemin içerir; içlerinde kalan çizgiler
# (minare, kubbe külahı, halka) kutunun kenarına DEĞDİĞİ için korunur.
TEXT_BANDS = ((330, 270, 700, 375), (330, 860, 700, 985))


def _source():
    """Kaynak tasarım; tam kenar olduğu doğrulanır.

    Sessizce düzeltmeye çalışmak yerine hata verir: damalı ya da yuvarlatılmış
    bir kaynak fark edilmeden mağazaya gidebilir.
    """
    if "source" in _cache:
        return _cache["source"]
    if not os.path.exists(SOURCE):
        raise SystemExit(f"kaynak tasarım yok: {SOURCE}")

    image = Image.open(SOURCE)
    if image.mode in ("RGBA", "LA") and image.getchannel("A").getextrema()[0] < 250:
        raise SystemExit("kaynakta saydamlık var; simge tam kenar olmalı")
    image = image.convert("RGB")
    if image.size[0] != image.size[1]:
        raise SystemExit(f"kaynak kare değil: {image.size}")

    width, height = image.size
    for x, y in ((2, 2), (width - 3, 2), (2, height - 3), (width - 3, height - 3)):
        red, green, blue = image.getpixel((x, y))
        if abs(red - green) < 12 and abs(green - blue) < 12 and red > 180:
            raise SystemExit(
                "kaynağın köşesi açık gri: tasarım ya yuvarlatılmış ya da "
                "etrafına saydamlık damaları çizilmiş; tuvali dolduran bir "
                "sürüm gerekir"
            )
    for band in TEXT_BANDS:
        _erase(image, band)
    _cache["source"] = image
    return image


def _text_mask(image, box):
    """Kutudaki yazının maskesi.

    Yazı, zeminden altın rengiyle ayrılır; ama kutuda yazı dışında da altın
    vardır (minare, külah, halka). Ayrım şöyle yapılır: kutunun kenarına
    değen her bağlı bileşen tasarımın bir parçasıdır ve KORUNUR. Yazı
    kutunun ortasında yüzer, kenara değmez.
    """
    left, top, right, bottom = box
    width, height = right - left, bottom - top
    pixels = image.load()
    gold = [
        [
            (lambda rgb: rgb[0] - rgb[2] > 6 and (rgb[0] + rgb[1]) / 2 > 60)(
                pixels[left + x, top + y]
            )
            for x in range(width)
        ]
        for y in range(height)
    ]

    mask = Image.new("L", (width, height), 0)
    painter = mask.load()
    seen = [[False] * width for _ in range(height)]
    for start_y in range(height):
        for start_x in range(width):
            if not gold[start_y][start_x] or seen[start_y][start_x]:
                continue
            component, touches_edge = [], False
            queue = deque([(start_x, start_y)])
            seen[start_y][start_x] = True
            while queue:
                x, y = queue.popleft()
                component.append((x, y))
                if x in (0, width - 1) or y in (0, height - 1):
                    touches_edge = True
                for step_x in (-1, 0, 1):
                    for step_y in (-1, 0, 1):
                        next_x, next_y = x + step_x, y + step_y
                        if not (0 <= next_x < width and 0 <= next_y < height):
                            continue
                        if gold[next_y][next_x] and not seen[next_y][next_x]:
                            seen[next_y][next_x] = True
                            queue.append((next_x, next_y))
            # Tek tük piksel gürültüsü zaten zeminle aynı; harf gövdesi büyüktür.
            if not touches_edge and len(component) > 20:
                for x, y in component:
                    painter[x, y] = 255
    return mask


def _erase(image, box):
    """Kutudaki yazıyı siler, yerine zeminin degradesini koyar."""
    mask = _text_mask(image, box)
    if mask.getextrema()[1] == 0:
        return
    # Harfin çevresindeki yumuşama eşiğin altında kalır; maske büyütülmezse
    # silinen yazının soluk bir hayaleti durur.
    mask = mask.filter(ImageFilter.MaxFilter(9))
    marked = mask.load()

    patch = image.crop(box)
    canvas = patch.load()
    width, height = patch.size
    for y in range(height):
        for x in range(width):
            if not marked[x, y]:
                continue
            before = next((i for i in range(x - 1, -1, -1) if not marked[i, y]), None)
            after = next((i for i in range(x + 1, width) if not marked[i, y]), None)
            if before is None and after is None:
                continue
            if before is None:
                canvas[x, y] = canvas[after, y]
            elif after is None:
                canvas[x, y] = canvas[before, y]
            else:
                ratio = (x - before) / (after - before)
                start, end = canvas[before, y], canvas[after, y]
                canvas[x, y] = tuple(
                    int(round(start[i] + (end[i] - start[i]) * ratio))
                    for i in range(3)
                )
    # Satır satır enterpolasyon dikey yönde ince şeritler bırakır; dolgu
    # bölgesi yumuşatılınca degradeden ayırt edilemez hâle gelir.
    patch = Image.composite(
        patch.filter(ImageFilter.GaussianBlur(4)),
        patch,
        mask.filter(ImageFilter.GaussianBlur(3)),
    )
    image.paste(patch, box)


def _artwork():
    """Altın hatlar; zemin saydam.

    Uyarlanabilir simgenin ön planı zemini TAŞIMAMALI: ön plan küçültüldüğü
    için kendi degrade parçası arka katmanın degradesiyle uyuşmuyor ve
    madalyonun çevresinde daire şeklinde bir dikiş görünüyordu. Zemin koyu,
    hatlar altın olduğu için ayrım parlaklıkla yapılır; yumuşak geçiş
    korunsun diye alfa kademelidir.
    """
    if "artwork" in _cache:
        return _cache["artwork"]
    source = _source()
    width, height = source.size
    result = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    src_pixels = source.load()
    out_pixels = result.load()
    for y in range(height):
        for x in range(width):
            red, green, blue = src_pixels[x, y]
            # Altın: parlak ve sıcak. Koyu yeşil/lacivert zeminden bu ikisiyle
            # ayrılır.
            warmth = red - blue
            level = (red + green) / 2
            alpha = 0.0
            if warmth > 10 and level > 70:
                alpha = min(1.0, (level - 70) / 90) * min(1.0, (warmth - 10) / 40)
            if alpha > 0:
                out_pixels[x, y] = (red, green, blue, int(round(alpha * 255)))
    _cache["artwork"] = result
    return result


def render(size, *, background=True, scale=1.0):
    """Simgeyi `size` piksellik kare olarak üretir.

    `background` açıkken tasarım tuvali doldurur (iOS ve Android eski simge).
    Kapalıyken yalnızca madalyon döner ve `scale` ile güvenli alana sığdırılır
    (Android uyarlanabilir simgenin ön planı).
    """
    if background:
        return _source().resize((size, size), Image.LANCZOS).convert("RGBA")

    content = max(1, int(size * scale))
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    artwork = _artwork().resize((content, content), Image.LANCZOS)
    inset = (size - content) // 2
    layer.paste(artwork, (inset, inset), artwork)
    return layer


def render_background(size):
    """Uyarlanabilir simgenin zemin katmanı.

    Tasarımın zemini degradedir; düz renk bir katman ön planın kenarında renk
    farkı bırakırdı. Madalyonun olmadığı köşe bölgesi büyütülerek tuvali
    dolduran bir degrade elde edilir.
    """
    corner = _source()
    edge = corner.size[0]
    corner = corner.crop((0, 0, int(edge * 0.22), int(edge * 0.22)))
    return corner.resize((size, size), Image.LANCZOS).convert("RGBA")


def _write(image, path, *, opaque):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if opaque:
        flat = Image.new("RGB", image.size, (20, 62, 70))
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

def build_android():
    res = os.path.join(ROOT, "android/app/src/main/res")
    for folder, pixels in ANDROID_LEGACY.items():
        _write(
            render(pixels),
            os.path.join(res, folder, "ic_launcher.png"),
            opaque=True,
        )
        # Uyarlanabilir simge katmanları 108dp'lik tuval ister. Zemin DEGRADE
        # olduğu için düz renk değil, ayrı bir PNG katmanı üretilir; düz renk
        # kullanıldığında ön planın kenarında renk farkı görünüyordu.
        adaptive = round(pixels * 108 / 48)
        _write(
            render(adaptive, background=False, scale=ADAPTIVE_SAFE),
            os.path.join(res, folder, "ic_launcher_foreground.png"),
            opaque=False,
        )
        _write(
            render_background(adaptive),
            os.path.join(res, folder, "ic_launcher_background.png"),
            opaque=True,
        )


WATCH_ICONS = os.path.join(ROOT, "ios/DiniWatch/Assets.xcassets")


def build_watch():
    """Apple Watch uygulamasının simgesi.

    watchOS tek bir 1024x1024 simge ister; sistem onu daireye kırpar.
    Simgesi olmayan saat uygulaması App Store yüklemesinde reddedilir.
    iOS simgesi gibi opaktır: saydamlık da reddedilir.
    """
    os.makedirs(WATCH_ICONS, exist_ok=True)
    with open(os.path.join(WATCH_ICONS, "Contents.json"), "w") as handle:
        json.dump({"info": {"author": "xcode", "version": 1}}, handle, indent=2)
        handle.write("\n")
    folder = os.path.join(WATCH_ICONS, "AppIcon.appiconset")
    os.makedirs(folder, exist_ok=True)
    filename = "AppIcon-1024.png"
    with open(os.path.join(folder, "Contents.json"), "w") as handle:
        json.dump(
            {
                "images": [
                    {
                        "filename": filename,
                        "idiom": "universal",
                        "platform": "watchos",
                        "size": "1024x1024",
                    }
                ],
                "info": {"author": "xcode", "version": 1},
            },
            handle,
            indent=2,
        )
        handle.write("\n")
    _write(render(1024), os.path.join(folder, filename), opaque=True)


def main():
    build_ios()
    build_android()
    build_watch()
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
