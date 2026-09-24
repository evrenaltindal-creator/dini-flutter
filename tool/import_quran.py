#!/usr/bin/env python3
"""Tanzil Kuran metnini uygulamaya alır.

Metin depoya bu betikle girer, elle değil. Tanzil'in kullanım şartı
metnin TEK HARFİNİN bile değiştirilmemesidir; betik bu yüzden dosyaya
dokunmaz, yalnızca denetler ve sıkıştırır:

* tanzil.net/download'dan "Osmani (Uthmani)" ve "Metin (aya
  numaralarıyla birlikte)" seçilerek indirilen dosyayı okur;
* Tanzil telif bloğunun yerinde olduğunu, 114 sûre ve 6236 âyetin
  eksiksiz ve sırasıyla geldiğini denetler — biri tutmazsa hata verir,
  sessizce kabul etmez;
* dosyayı OLDUĞU GİBİ (telif bloğu dahil) gzip ile sıkıştırıp
  `assets/quran/quran-uthmani.txt.gz` dosyasına yazar. Sıkıştırma
  zaman damgasız yapılır: aynı girdi her seferinde aynı çıktıyı verir;
* kaynağı, sürümü ve SHA-256 özetini `assets/quran/SOURCE.txt`
  dosyasına yazar. Test, uygulamadaki metnin bu özetle birebir aynı
  olduğunu denetler.

    python3 tool/import_quran.py quran-uthmani.txt
"""

import argparse
import gzip
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEXT_ASSET = "assets/quran/quran-uthmani.txt.gz"
SOURCE_NOTE = "assets/quran/SOURCE.txt"

SURAH_COUNT = 114
AYAH_COUNT = 6236
HEADER = re.compile(r"#\s+Tanzil Quran Text \((Uthmani), (Version [\d.]+)\)")
LINE = re.compile(r"^(\d+)\|(\d+)\|(.+)$")


def check_text(raw):
    """Metni denetler; (tür, sürüm) döndürür. Hata varsa çıkar."""
    header = HEADER.search(raw)
    if not header:
        raise SystemExit(
            "Tanzil telif bloğu bulunamadı ya da metin Uthmani değil: "
            "tanzil.net/download'dan Osmani (Uthmani) metni indirin"
        )
    if "CHANGING IT IS NOT ALLOWED" not in raw:
        raise SystemExit("Tanzil kullanım şartları metinde yok")

    previous = (0, 0)
    count = 0
    for number, line in enumerate(raw.split("\n"), start=1):
        if not line or line.startswith("#"):
            continue
        match = LINE.match(line)
        if not match:
            raise SystemExit(f"{number}. satır 'sûre|âyet|metin' değil")
        surah, ayah = int(match.group(1)), int(match.group(2))
        following = (previous[0], previous[1] + 1)
        next_surah = (previous[0] + 1, 1)
        if (surah, ayah) not in (following, next_surah):
            raise SystemExit(
                f"{number}. satırda sıra bozuk: {previous[0]}:{previous[1]} "
                f"ardından {surah}:{ayah}"
            )
        previous = (surah, ayah)
        count += 1

    if previous[0] != SURAH_COUNT:
        raise SystemExit(f"{previous[0]} sûre var, {SURAH_COUNT} olmalı")
    if count != AYAH_COUNT:
        raise SystemExit(f"{count} âyet var, {AYAH_COUNT} olmalı")
    return header.group(1), header.group(2)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("text", help="Tanzil'den indirilen quran-uthmani.txt")
    parser.add_argument("--root", default=ROOT, help=argparse.SUPPRESS)
    args = parser.parse_args()

    with open(args.text, "rb") as source:
        data = source.read()
    kind, version = check_text(data.decode("utf-8"))

    target = os.path.join(args.root, TEXT_ASSET)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "wb") as out:
        out.write(gzip.compress(data, compresslevel=9, mtime=0))

    digest = hashlib.sha256(data).hexdigest()
    with open(os.path.join(args.root, SOURCE_NOTE), "w", encoding="utf-8") as note:
        note.write(
            "Kuran metni\n"
            f"Kaynak: Tanzil Projesi — https://tanzil.net\n"
            f"Metin: Tanzil Quran Text ({kind}, {version})\n"
            "Lisans: Creative Commons Atıf 3.0 (CC BY 3.0)\n"
            "Şartlar: metin değiştirilmeden kullanılır, kaynak açıkça\n"
            "yazılır ve tanzil.net'e bağlantı verilir (Hakkında sayfası:\n"
            "about.quran). Telif bloğu sıkıştırılmış dosyanın içindedir.\n"
            f"Dosya: {TEXT_ASSET} (gzip, içerik değiştirilmedi)\n"
            f"SHA-256 (sıkıştırılmamış): {digest}\n"
        )
    print(f"{AYAH_COUNT} âyet, {SURAH_COUNT} sûre — {kind} {version}")
    print(f"{TEXT_ASSET}: {os.path.getsize(target)} bayt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
