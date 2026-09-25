#!/usr/bin/env python3
"""Tanzil Kuran metnini, üst verisini ve meallerini uygulamaya alır.

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
* üst veriyi (`quran-data.xml`: sûre adları, cüzler, hizb çeyrekleri ve
  Medine Mushaf'ının 604 sayfası) denetler — sûre uzunlukları metinle
  tutmalı, sayfalar ve cüzler sırayla ilerlemeli — ve aynı şekilde olduğu
  gibi sıkıştırır;
* her meal için (`--translation`) 6236 âyetin sırayla geldiğini ve künye
  başlığının (ID, Name, Source) yerinde olduğunu denetler; dosya kimliğiyle
  (`en.pickthall.txt.gz`) yazar. Meal eklemeden önce çevirinin telifine
  bakın: telifli bir meal uygulamaya alınmaz;
* kaynağı, sürümü ve her dosyanın SHA-256 özetini `assets/quran/SOURCE.txt`
  dosyasına yazar. Test, uygulamadaki dosyaların bu özetlerle birebir aynı
  olduğunu denetler.

    python3 tool/import_quran.py quran-uthmani.txt quran-data.xml \\
        --translation en.pickthall.txt
"""

import argparse
import gzip
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEXT_ASSET = "assets/quran/quran-uthmani.txt.gz"
META_ASSET = "assets/quran/quran-data.xml.gz"
SOURCE_NOTE = "assets/quran/SOURCE.txt"
PAGE_COUNT = 604
JUZ_COUNT = 30
QUARTER_COUNT = 240

SURAH_COUNT = 114
AYAH_COUNT = 6236
HEADER = re.compile(r"#\s+Tanzil Quran Text \((Uthmani), (Version [\d.]+)\)")
LINE = re.compile(r"^(\d+)\|(\d+)\|(.+)$")
TRANSLATION_ID = re.compile(r"#\s+ID: ([a-z]{2}\.[a-z]+)\s*$", re.MULTILINE)
TRANSLATION_NAME = re.compile(r"#\s+Name: (.+?)\s*$", re.MULTILINE)
TRANSLATION_SOURCE = re.compile(r"#\s+Source: (.+?)\s*$", re.MULTILINE)
ATTRIBUTES = re.compile(r'(\w+)="([^"]*)"')


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
    return header.group(1), header.group(2), check_lines(raw)


def check_lines(raw):
    """'sûre|âyet|metin' satırlarını denetler; sûre uzunluklarını döndürür."""
    lengths = []
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
        if ayah == 1:
            lengths.append(0)
        lengths[-1] += 1
        previous = (surah, ayah)
        count += 1

    if previous[0] != SURAH_COUNT:
        raise SystemExit(f"{previous[0]} sûre var, {SURAH_COUNT} olmalı")
    if count != AYAH_COUNT:
        raise SystemExit(f"{count} âyet var, {AYAH_COUNT} olmalı")
    return lengths


def _elements(raw, tag):
    return [
        dict(ATTRIBUTES.findall(match))
        for match in re.findall(rf"<{tag}\s([^>]*)/>", raw)
    ]


def check_meta(raw, lengths):
    """Tanzil üst verisini metne göre denetler. Hata varsa çıkar."""
    if 'type="metadata"' not in raw or "Tanzil" not in raw:
        raise SystemExit("Tanzil üst verisi (quran-data.xml) değil")

    suras = _elements(raw, "sura")
    if len(suras) != SURAH_COUNT:
        raise SystemExit(f"üst veride {len(suras)} sûre var")
    start = 0
    for number, sura in enumerate(suras, start=1):
        if int(sura["index"]) != number or int(sura["start"]) != start:
            raise SystemExit(f"{number}. sûrenin sırası ya da başlangıcı bozuk")
        if int(sura["ayas"]) != lengths[number - 1]:
            raise SystemExit(
                f"{number}. sûre üst veride {sura['ayas']}, metinde "
                f"{lengths[number - 1]} âyet"
            )
        if not sura.get("name") or not sura.get("tname"):
            raise SystemExit(f"{number}. sûrenin adı yok")
        start += int(sura["ayas"])

    def check_marks(tag, expected):
        marks = _elements(raw, tag)
        if len(marks) != expected:
            raise SystemExit(f"{len(marks)} {tag} var, {expected} olmalı")
        previous = -1
        for number, mark in enumerate(marks, start=1):
            surah, ayah = int(mark["sura"]), int(mark["aya"])
            if int(mark["index"]) != number or not (
                1 <= surah <= SURAH_COUNT and 1 <= ayah <= lengths[surah - 1]
            ):
                raise SystemExit(f"{number}. {tag} geçersiz")
            position = sum(lengths[: surah - 1]) + ayah - 1
            if position <= previous:
                raise SystemExit(f"{number}. {tag} sırayla ilerlemiyor")
            previous = position
        if (int(marks[0]["sura"]), int(marks[0]["aya"])) != (1, 1):
            raise SystemExit(f"ilk {tag} Fâtiha'nın başında değil")

    check_marks("page", PAGE_COUNT)
    check_marks("juz", JUZ_COUNT)
    check_marks("quarter", QUARTER_COUNT)


def check_translation(raw):
    """Meali denetler; (kimlik, ad, kaynak) döndürür. Hata varsa çıkar.

    Künye başlığında kimlik, ad ve kaynak bulunmalı: kaynağı yazılmayan
    meal uygulamaya alınmaz.
    """
    identifier = TRANSLATION_ID.search(raw)
    name = TRANSLATION_NAME.search(raw)
    source = TRANSLATION_SOURCE.search(raw)
    if not identifier or not name or not source:
        raise SystemExit("meal künyesi (ID, Name, Source) bulunamadı")
    check_lines(raw)
    return identifier.group(1), name.group(1), source.group(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("text", help="Tanzil'den indirilen quran-uthmani.txt")
    parser.add_argument("meta", help="Tanzil'den indirilen quran-data.xml")
    parser.add_argument(
        "--translation",
        action="append",
        default=[],
        help="Tanzil'den indirilen meal (ör. en.pickthall.txt); tekrarlanabilir",
    )
    parser.add_argument("--root", default=ROOT, help=argparse.SUPPRESS)
    args = parser.parse_args()

    def read(path):
        with open(path, "rb") as source:
            return source.read()

    # Önce hepsi denetlenir; biri bozuksa hiçbir şey yazılmaz.
    text = read(args.text)
    kind, version, lengths = check_text(text.decode("utf-8"))
    meta = read(args.meta)
    check_meta(meta.decode("utf-8"), lengths)
    translations = []
    for path in args.translation:
        data = read(path)
        identifier, name, source = check_translation(data.decode("utf-8"))
        translations.append((identifier, name, source, data))

    def write(asset, data):
        target = os.path.join(args.root, asset)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as out:
            out.write(gzip.compress(data, compresslevel=9, mtime=0))
        print(f"{asset}: {os.path.getsize(target)} bayt")
        return hashlib.sha256(data).hexdigest()

    lines = [
        "Kuran metni",
        "Kaynak: Tanzil Projesi — https://tanzil.net",
        f"Metin: Tanzil Quran Text ({kind}, {version})",
        "Lisans: Creative Commons Atıf 3.0 (CC BY 3.0)",
        "Şartlar: metin değiştirilmeden kullanılır, kaynak açıkça",
        "yazılır ve tanzil.net'e bağlantı verilir (Hakkında sayfası:",
        "about.quran). Telif bloğu sıkıştırılmış dosyanın içindedir.",
        f"Dosya: {TEXT_ASSET} (gzip, içerik değiştirilmedi)",
        f"SHA-256 (sıkıştırılmamış): {write(TEXT_ASSET, text)}",
        "",
        "Üst veri (sûre adları, cüzler, hizbler, Medine Mushaf'ı sayfaları)",
        "Kaynak: Tanzil Projesi — quran-data.xml, CC BY",
        f"Dosya: {META_ASSET} (gzip, içerik değiştirilmedi)",
        f"SHA-256 (sıkıştırılmamış): {write(META_ASSET, meta)}",
    ]
    for identifier, name, source, data in translations:
        asset = f"assets/quran/{identifier}.txt.gz"
        lines += [
            "",
            f"Meal: {name} ({identifier})",
            f"Kaynak: {source}",
            f"Dosya: {asset} (gzip, içerik değiştirilmedi)",
            f"SHA-256 (sıkıştırılmamış): {write(asset, data)}",
        ]
    with open(os.path.join(args.root, SOURCE_NOTE), "w", encoding="utf-8") as note:
        note.write("\n".join(lines) + "\n")
    print(f"{AYAH_COUNT} âyet, {SURAH_COUNT} sûre — {kind} {version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
