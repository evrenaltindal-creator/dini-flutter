#!/usr/bin/env python3
"""Elmalılı Hamdi Yazır mealinin 1935 aslını Tanzil biçimine çevirir.

Tanzil'in `tr.yazir` dosyası mealin sonradan SADELEŞTİRİLMİŞ bir baskısıdır
(qurandatabase.org aynı metni "Elmalılı Sadeleştirilmiş" diye verir) ve
sadeleştirmenin telifi ayrıdır. Aslı ise kamu malıdır: Elmalılı 1942'de
vefat etti, koruma süresi 2013'te doldu.

Aslının âyet âyet dijital metni namazzamani.net'te "Elmalılı Hamdi Yazır
(Orijinal)" başlığıyla yayımlanıyor. Bu betik o sayfaların kaydedilmiş
kopyalarını okur (indirme ayrı yapılır, betik ağa çıkmaz):

* her sûre sayfasındaki `<li>` satırlarından âyet numarasını ve metni alır;
  metin HTML kaçışlarından arındırılır, boşluklar teke indirilir, başka hiçbir
  harfe dokunulmaz (sitenin ´ kesme işareti olduğu gibi kalır);
* sûreyi sayfa adresindeki addan (`surah_names.dart`'taki Türkçe adlarla)
  bulur ve âyet sayısını Tanzil üst verisiyle ayrıca denetler; ad ya da
  sayı tutmazsa hata verir;
* sonucu Tanzil meal dosyası biçiminde yazar (`sûre|âyet|metin` ve künye
  başlığı); ardından `tool/import_quran.py --translation` ile denetlenip
  pakete girer.

    python3 tool/convert_elmalili_orijinal.py sayfalar/ quran-data.xml \\
        tr.elmalili.txt
"""

import argparse
import gzip
import html
import os
import re
import sys
import unicodedata

ITEM = re.compile(
    r'<li>\s*<b><a href="([a-z-]+)-(\d+)\.ayet\.htm">[^<]*?(\d+):</b>(.*?)</a>\s*</li>',
    re.S,
)
NAMES = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "lib/features/quran/data/surah_names.dart",
)
SURA = re.compile(r'<sura index="(\d+)" ayas="(\d+)"[^>]*tname="([^"]*)"')

# Sitenin adresindeki sûre adı ile bizim Türkçe adımızın yazımı farklı olanlar.
SLUG_ALIASES = {
    "hacc": 22,
    "saff": 61,
    "kiyame": 75,
    "kadir": 97,
}

HEADER = """# --------------------------------------------------------------------
#
#  Quran Translation
#  Name: Elmalılı Hamdi Yazır (1935 aslı, sadeleştirilmemiş)
#  Translator: Elmalılı Muhammed Hamdi Yazır (1878-1942)
#  Language: Turkish
#  ID: tr.elmalili
#  Source: namazzamani.net, "Elmalılı Hamdi Yazır (Orijinal)"
#  License: Kamu malı (yazar 1942'de vefat etti)
#
# --------------------------------------------------------------------
"""


def fold(text):
    """Harf karşılaştırması için: küçük harf, işaretsiz, yalnızca a-z."""
    text = unicodedata.normalize("NFKD", text.lower().replace("ı", "i"))
    return re.sub(r"[^a-z]", "", text)


def parse_page(raw):
    """Sayfadaki (adres adı, âyet no, metin) satırları."""
    rows = []
    for slug, link_number, number, body in ITEM.findall(raw):
        if link_number != number:
            raise SystemExit(f"{slug}: bağlantı {link_number}, etiket {number}")
        text = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", body)))
        rows.append((slug, int(number), text.strip()))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("pages", help="kaydedilmiş sûre sayfalarının klasörü")
    parser.add_argument("meta", help="Tanzil quran-data.xml (ya da .gz)")
    parser.add_argument("out", help="yazılacak Tanzil biçimli meal dosyası")
    args = parser.parse_args()

    opener = gzip.open if args.meta.endswith(".gz") else open
    with opener(args.meta, "rt", encoding="utf-8") as meta:
        suras = [(int(i), int(n), fold(t)) for i, n, t in SURA.findall(meta.read())]
    if len(suras) != 114:
        raise SystemExit("üst veride 114 sûre yok")

    with open(NAMES, encoding="utf-8") as source:
        code = "\n".join(
            line for line in source if not line.lstrip().startswith("//")
        )
    listed = re.findall(r"'((?:[^'\\]|\\.)+)'", code)
    if len(listed) != 114:
        raise SystemExit(f"{NAMES}: {len(listed)} ad var")
    names = {fold(n.replace("\\'", "")): i for i, n in enumerate(listed, start=1)}

    by_number = {}
    for name in sorted(os.listdir(args.pages)):
        with open(os.path.join(args.pages, name), encoding="utf-8") as page:
            rows = parse_page(page.read())
        if not rows:
            raise SystemExit(f"{name}: âyet bulunamadı")
        slug = rows[0][0].replace("-suresi", "")
        numbers = [n for _, n, _ in rows]
        if numbers != list(range(1, len(numbers) + 1)):
            raise SystemExit(f"{name}: âyetler sırayla değil")

        # Sûre, sayfa adresindeki adla (Türkçe adlarımıza göre) bulunur ve
        # âyet sayısı Tanzil üst verisiyle ayrıca denetlenir: iki bağımsız
        # denetim, yanlış sûreye yazılmayı önler.
        number = SLUG_ALIASES.get(slug) or names.get(fold(slug))
        if number is None:
            raise SystemExit(f"{name}: '{slug}' hiçbir sûre adına uymuyor")
        if suras[number - 1][1] != len(rows):
            raise SystemExit(
                f"{name}: {number}. sûre {len(rows)} âyet, üst veride "
                f"{suras[number - 1][1]}"
            )
        if number in by_number:
            raise SystemExit(f"{name}: {number}. sûre iki kez geldi")
        by_number[number] = [text for _, _, text in rows]

    missing = sorted(set(range(1, 115)) - set(by_number))
    if missing:
        raise SystemExit(f"eksik sûreler: {missing}")
    empty = [
        f"{s}:{a}"
        for s, texts in by_number.items()
        for a, text in enumerate(texts, start=1)
        if not text
    ]
    if empty:
        raise SystemExit(f"boş âyetler: {empty[:10]}")

    with open(args.out, "w", encoding="utf-8") as out:
        for surah in range(1, 115):
            for ayah, text in enumerate(by_number[surah], start=1):
                out.write(f"{surah}|{ayah}|{text}\n")
        out.write("\n" + HEADER)
    total = sum(len(t) for t in by_number.values())
    print(f"{args.out}: 114 sûre, {total} âyet")
    return 0


if __name__ == "__main__":
    sys.exit(main())
