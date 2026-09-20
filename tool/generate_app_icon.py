#!/usr/bin/env python3
"""Uygulama simgesini üretir.

Kaynak, `assets/branding/app_icon_source.png` dosyasındaki 1024x1024
tasarımdır: degrade zemin üzerinde altın hatlı cami, pusula, halkalar ve
vakit adları.

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
from PIL import Image, ImageDraw

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
    _cache["source"] = image
    return image


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
