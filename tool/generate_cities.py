#!/usr/bin/env python3
"""Paketlenen şehir listesini üretir.

Uygulama çevrimdışıdır: geocoding servisi çağıramayız (bkz. CLAUDE.md 1. ve
2. kural). Şehir seçici ve koordinattan saat dilimi çözümü bu listeye dayanır.

Liste iki bölümden oluşur:

* Türkiye'nin 81 ili. Hepsi `Europe/Istanbul`; saat dilimi riski yoktur.
* Diaspora ve İslam dünyasının büyük şehirleri.

Koordinatlar il/şehir merkezleridir ve yaklaşık bir dakikalık vakit farkı
yaratacak hassasiyettedir; bir şehrin içindeki mahalle farkı zaten bundan
küçüktür.

    python3 tool/generate_cities.py
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "assets/data/cities.json")

TURKEY = "Europe/Istanbul"

# (ad, enlem, boylam) — hepsi Europe/Istanbul.
TURKISH_PROVINCES = [
    ("Adana", 37.00, 35.32), ("Adıyaman", 37.76, 38.28),
    ("Afyonkarahisar", 38.76, 30.54), ("Ağrı", 39.72, 43.05),
    ("Aksaray", 38.37, 34.03), ("Amasya", 40.65, 35.83),
    ("Ankara", 39.93, 32.86), ("Antalya", 36.90, 30.71),
    ("Ardahan", 41.11, 42.70), ("Artvin", 41.18, 41.82),
    ("Aydın", 37.85, 27.84), ("Balıkesir", 39.65, 27.89),
    ("Bartın", 41.64, 32.34), ("Batman", 37.89, 41.13),
    ("Bayburt", 40.26, 40.23), ("Bilecik", 40.14, 29.98),
    ("Bingöl", 38.88, 40.50), ("Bitlis", 38.40, 42.11),
    ("Bolu", 40.74, 31.61), ("Burdur", 37.72, 30.29),
    ("Bursa", 40.19, 29.06), ("Çanakkale", 40.15, 26.41),
    ("Çankırı", 40.60, 33.62), ("Çorum", 40.55, 34.95),
    ("Denizli", 37.78, 29.09), ("Diyarbakır", 37.91, 40.24),
    ("Düzce", 40.84, 31.16), ("Edirne", 41.68, 26.56),
    ("Elazığ", 38.68, 39.22), ("Erzincan", 39.75, 39.49),
    ("Erzurum", 39.90, 41.27), ("Eskişehir", 39.78, 30.52),
    ("Gaziantep", 37.07, 37.38), ("Giresun", 40.91, 38.39),
    ("Gümüşhane", 40.46, 39.48), ("Hakkâri", 37.57, 43.74),
    ("Hatay", 36.20, 36.16), ("Iğdır", 39.92, 44.04),
    ("Isparta", 37.76, 30.55), ("İstanbul", 41.01, 28.98),
    ("İzmir", 38.42, 27.14), ("Kahramanmaraş", 37.58, 36.93),
    ("Karabük", 41.20, 32.63), ("Karaman", 37.18, 33.22),
    ("Kars", 40.61, 43.10), ("Kastamonu", 41.38, 33.78),
    ("Kayseri", 38.73, 35.49), ("Kilis", 36.72, 37.12),
    ("Kırıkkale", 39.85, 33.52), ("Kırklareli", 41.74, 27.22),
    ("Kırşehir", 39.14, 34.17), ("Kocaeli", 40.77, 29.92),
    ("Konya", 37.87, 32.48), ("Kütahya", 39.42, 29.98),
    ("Malatya", 38.35, 38.31), ("Manisa", 38.62, 27.43),
    ("Mardin", 37.31, 40.74), ("Mersin", 36.80, 34.63),
    ("Muğla", 37.22, 28.36), ("Muş", 38.73, 41.49),
    ("Nevşehir", 38.62, 34.71), ("Niğde", 37.97, 34.68),
    ("Ordu", 40.98, 37.88), ("Osmaniye", 37.07, 36.25),
    ("Rize", 41.02, 40.52), ("Sakarya", 40.76, 30.38),
    ("Samsun", 41.29, 36.33), ("Siirt", 37.93, 41.94),
    ("Sinop", 42.03, 35.15), ("Sivas", 39.75, 37.02),
    ("Şanlıurfa", 37.16, 38.80), ("Şırnak", 37.52, 42.46),
    ("Tekirdağ", 40.98, 27.51), ("Tokat", 40.32, 36.55),
    ("Trabzon", 41.00, 39.72), ("Tunceli", 39.11, 39.55),
    ("Uşak", 38.68, 29.41), ("Van", 38.49, 43.38),
    ("Yalova", 40.66, 29.28), ("Yozgat", 39.82, 34.81),
    ("Zonguldak", 41.46, 31.79),
]

# (ad, ülke kodu, enlem, boylam, IANA saat dilimi)
WORLD = [
    # Avrupa — Türk diasporasının yoğun olduğu şehirler önce.
    ("Berlin", "DE", 52.52, 13.41, "Europe/Berlin"),
    ("Köln", "DE", 50.94, 6.96, "Europe/Berlin"),
    ("Hamburg", "DE", 53.55, 9.99, "Europe/Berlin"),
    ("München", "DE", 48.14, 11.58, "Europe/Berlin"),
    ("Frankfurt", "DE", 50.11, 8.68, "Europe/Berlin"),
    ("Stuttgart", "DE", 48.78, 9.18, "Europe/Berlin"),
    ("Düsseldorf", "DE", 51.23, 6.78, "Europe/Berlin"),
    ("Wien", "AT", 48.21, 16.37, "Europe/Vienna"),
    ("Zürich", "CH", 47.38, 8.54, "Europe/Zurich"),
    ("Amsterdam", "NL", 52.37, 4.90, "Europe/Amsterdam"),
    ("Rotterdam", "NL", 51.92, 4.48, "Europe/Amsterdam"),
    ("Brussel", "BE", 50.85, 4.35, "Europe/Brussels"),
    ("Paris", "FR", 48.86, 2.35, "Europe/Paris"),
    ("London", "GB", 51.51, -0.13, "Europe/London"),
    ("Manchester", "GB", 53.48, -2.24, "Europe/London"),
    ("Birmingham", "GB", 52.49, -1.89, "Europe/London"),
    ("Stockholm", "SE", 59.33, 18.07, "Europe/Stockholm"),
    ("København", "DK", 55.68, 12.57, "Europe/Copenhagen"),
    ("Oslo", "NO", 59.91, 10.75, "Europe/Oslo"),
    ("Moskova", "RU", 55.76, 37.62, "Europe/Moscow"),
    ("Kiev", "UA", 50.45, 30.52, "Europe/Kyiv"),
    ("Sofya", "BG", 42.70, 23.32, "Europe/Sofia"),
    ("Bükreş", "RO", 44.43, 26.10, "Europe/Bucharest"),
    ("Atina", "GR", 37.98, 23.73, "Europe/Athens"),
    ("Roma", "IT", 41.90, 12.50, "Europe/Rome"),
    ("Madrid", "ES", 40.42, -3.70, "Europe/Madrid"),
    ("Lizbon", "PT", 38.72, -9.14, "Europe/Lisbon"),
    ("Saraybosna", "BA", 43.86, 18.41, "Europe/Sarajevo"),
    ("Üsküp", "MK", 41.99, 21.43, "Europe/Skopje"),
    ("Tiran", "AL", 41.33, 19.82, "Europe/Tirane"),
    ("Lefkoşa", "CY", 35.19, 33.38, "Asia/Nicosia"),
    # Kafkasya ve Orta Asya.
    ("Bakü", "AZ", 40.41, 49.87, "Asia/Baku"),
    ("Tiflis", "GE", 41.72, 44.79, "Asia/Tbilisi"),
    ("Taşkent", "UZ", 41.30, 69.24, "Asia/Tashkent"),
    ("Almatı", "KZ", 43.24, 76.89, "Asia/Almaty"),
    ("Bişkek", "KG", 42.87, 74.59, "Asia/Bishkek"),
    ("Duşanbe", "TJ", 38.56, 68.79, "Asia/Dushanbe"),
    ("Aşkabat", "TM", 37.95, 58.38, "Asia/Ashgabat"),
    # Orta Doğu.
    ("Mekke", "SA", 21.42, 39.83, "Asia/Riyadh"),
    ("Medine", "SA", 24.47, 39.61, "Asia/Riyadh"),
    ("Riyad", "SA", 24.71, 46.68, "Asia/Riyadh"),
    ("Cidde", "SA", 21.49, 39.19, "Asia/Riyadh"),
    ("Dubai", "AE", 25.20, 55.27, "Asia/Dubai"),
    ("Doha", "QA", 25.29, 51.53, "Asia/Qatar"),
    ("Kuveyt", "KW", 29.38, 47.99, "Asia/Kuwait"),
    ("Manama", "BH", 26.23, 50.59, "Asia/Bahrain"),
    ("Maskat", "OM", 23.59, 58.41, "Asia/Muscat"),
    ("Bağdat", "IQ", 33.31, 44.37, "Asia/Baghdad"),
    ("Erbil", "IQ", 36.19, 44.01, "Asia/Baghdad"),
    ("Şam", "SY", 33.51, 36.29, "Asia/Damascus"),
    ("Beyrut", "LB", 33.89, 35.50, "Asia/Beirut"),
    ("Amman", "JO", 31.95, 35.93, "Asia/Amman"),
    ("Kudüs", "PS", 31.78, 35.22, "Asia/Hebron"),
    ("Tahran", "IR", 35.69, 51.39, "Asia/Tehran"),
    # Afrika.
    ("Kahire", "EG", 30.04, 31.24, "Africa/Cairo"),
    ("Tunus", "TN", 36.81, 10.18, "Africa/Tunis"),
    ("Cezayir", "DZ", 36.75, 3.06, "Africa/Algiers"),
    ("Kazablanka", "MA", 33.57, -7.59, "Africa/Casablanca"),
    ("Rabat", "MA", 34.02, -6.84, "Africa/Casablanca"),
    ("Trablus", "LY", 32.89, 13.19, "Africa/Tripoli"),
    ("Hartum", "SD", 15.50, 32.56, "Africa/Khartoum"),
    ("Lagos", "NG", 6.52, 3.38, "Africa/Lagos"),
    ("Nairobi", "KE", -1.29, 36.82, "Africa/Nairobi"),
    # Güney ve Güneydoğu Asya.
    ("Kabil", "AF", 34.53, 69.17, "Asia/Kabul"),
    ("İslamabad", "PK", 33.69, 73.06, "Asia/Karachi"),
    ("Karaçi", "PK", 24.86, 67.01, "Asia/Karachi"),
    ("Lahor", "PK", 31.55, 74.34, "Asia/Karachi"),
    ("Delhi", "IN", 28.61, 77.21, "Asia/Kolkata"),
    ("Mumbai", "IN", 19.08, 72.88, "Asia/Kolkata"),
    ("Haydarabad", "IN", 17.39, 78.49, "Asia/Kolkata"),
    ("Dakka", "BD", 23.81, 90.41, "Asia/Dhaka"),
    ("Kuala Lumpur", "MY", 3.14, 101.69, "Asia/Kuala_Lumpur"),
    ("Cakarta", "ID", -6.21, 106.85, "Asia/Jakarta"),
    ("Singapur", "SG", 1.35, 103.82, "Asia/Singapore"),
    # Amerika ve Okyanusya.
    ("New York", "US", 40.71, -74.01, "America/New_York"),
    ("Chicago", "US", 41.88, -87.63, "America/Chicago"),
    ("Houston", "US", 29.76, -95.37, "America/Chicago"),
    ("Detroit", "US", 42.33, -83.05, "America/Detroit"),
    ("Los Angeles", "US", 34.05, -118.24, "America/Los_Angeles"),
    ("Toronto", "CA", 43.65, -79.38, "America/Toronto"),
    ("Montreal", "CA", 45.50, -73.57, "America/Toronto"),
    ("Sydney", "AU", -33.87, 151.21, "Australia/Sydney"),
    ("Melbourne", "AU", -37.81, 144.96, "Australia/Melbourne"),
]


def build():
    cities = [
        {"name": name, "country": "TR", "lat": lat, "lon": lon, "tz": TURKEY}
        for name, lat, lon in TURKISH_PROVINCES
    ]
    cities += [
        {"name": name, "country": country, "lat": lat, "lon": lon, "tz": tz}
        for name, country, lat, lon, tz in WORLD
    ]

    seen = set()
    for city in cities:
        key = (city["name"], city["country"])
        if key in seen:
            raise SystemExit("Aynı şehir iki kez: %s" % (key,))
        seen.add(key)
        if not -90 <= city["lat"] <= 90 or not -180 <= city["lon"] <= 180:
            raise SystemExit("Geçersiz koordinat: %s" % city)

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(cities, handle, ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")
    print("wrote", os.path.relpath(OUTPUT, ROOT), len(cities), "şehir")
    print("Türkiye:", sum(1 for c in cities if c["country"] == "TR"))


if __name__ == "__main__":
    build()
