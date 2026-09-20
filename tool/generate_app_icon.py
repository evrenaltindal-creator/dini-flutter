#!/usr/bin/env python3
"""Uygulama simgesini üretir.

Kaynak, `assets/branding/app_icon_source.png` dosyasındaki 1024x1024
tasarımdır (altın hatlı cami, pusula ve halkalar; düz yeşil zemin). PNG'ler
bu betikten türetilir: boyut listesi değiştiğinde ya da kaynak tasarım
yenilendiğinde simgeleri elle kesmek gerekmez.

Çalıştırmak için:

    pip install Pillow
    python3 tool/generate_app_icon.py

İki ayrı çıktı üretilir:

* **iOS ve Android eski simge** — tasarım olduğu gibi, tuvali doldurarak.
  Köşeleri sistem yuvarlatır; kaynak kare ve saydamlıksız olmalıdır.
* **Android uyarlanabilir simge ön planı** — sistem ön planın dışını kırpar
  ve güvenli alan ortadaki dairedir. Tasarımın dış halkası tuvalin %77'sine
  kadar uzandığı için ön plan küçültülür; aksi halde halka kırpılırdı.
  Zemin düz renk olduğu için ön planda zemin şeffaflaştırılır ve renk
  `values/colors.xml` üzerinden verilir.
"""

import json
import os
import subprocess
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Kaynak tasarımın düz zemin rengi. Uyarlanabilir simgede zemin ayrı katman
# olduğu için bu renk `values/colors.xml` ile birebir aynı olmalıdır; aksi
# halde ön planın kenarında ince bir renk halkası görünür.
BACKGROUND = (28, 97, 83)

# Kaynak tasarım yalnızca bu betik tarafından, derleme öncesinde okunur.
# `pubspec.yaml` içindeki `assets:` listesine EKLENMEZ: uygulama onu çalışma
# anında yüklemiyor, eklemek pakete boşuna ~400 KB bindirirdi.
SOURCE = os.path.join(ROOT, "assets/branding/app_icon_source.png")

# Uyarlanabilir simgede sistem ön planın dışını kırpar; güvenli daire tuvalin
# ortadaki %61'idir. Tasarımın en dış halkası merkeze 425/1024 piksel
# uzaklıkta bittiği için içerik bu oranla küçültülür (ölçüldü, tahmin değil).
ADAPTIVE_SAFE = 0.74


def _source():
    """Kaynak tasarım. Bulunamazsa sessizce varsayılana düşmez: simgeyi
    yanlışlıkla eski haliyle üretmek, değişikliğin kaybolduğunu fark
    ettirmez."""
    if not os.path.exists(SOURCE):
        raise SystemExit(f"kaynak tasarım yok: {SOURCE}")
    return Image.open(SOURCE).convert("RGB")


def _keyed(image, tolerance=26):
    """Düz zemini saydamlaştırır; uyarlanabilir simgenin ön planı için."""
    result = image.convert("RGBA")
    pixels = result.load()
    width, height = result.size
    for y in range(height):
        for x in range(width):
            r, g, b, _ = pixels[x, y]
            if all(abs(c - t) <= tolerance for c, t in zip((r, g, b), BACKGROUND)):
                pixels[x, y] = (r, g, b, 0)
    return result


# Küçük boyutlarda tasarım kalabalık kalıyor: ince altın halkalar 40 pikselde
# birbirine giriyor. Bu ölçülerde kenardan biraz kırpılır, böylece cami ve
# pusula büyür. Apple her boyut için ayrı dosya beklediği ve bu dosyalar
# ayrı ayrı üretildiği için bu serbesttir. Kırpma oranı denenerek seçildi:
# %22'de dış halka kesiliyordu.
SMALL_SIZE_LIMIT = 76
SMALL_CROP = 0.14


def render(size, *, background=True, scale=1.0):
    """Simgeyi `size` piksellik kare olarak üretir.

    `background` kapalıyken zemin saydamlaşır (Android uyarlanabilir simgenin
    ön planı). `scale`, içeriği güvenli alana sığdırmak için küçültür.
    """
    source = _source()
    if background:
        if size <= SMALL_SIZE_LIMIT:
            edge = source.size[0]
            inset = round(edge * SMALL_CROP / 2)
            source = source.crop((inset, inset, edge - inset, edge - inset))
        return source.resize((size, size), Image.LANCZOS).convert("RGBA")

    content = max(1, int(size * scale))
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    keyed = _keyed(source).resize((content, content), Image.LANCZOS)
    inset = (size - content) // 2
    layer.paste(keyed, (inset, inset), keyed)
    return layer


def _write(image, path, *, opaque):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if opaque:
        flat = Image.new("RGB", image.size, BACKGROUND)
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
