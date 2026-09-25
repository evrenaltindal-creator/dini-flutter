#!/usr/bin/env python3
"""App Store Connect'te mağaza sayfası dışındaki zorunlu ayarları yapar.

`fastlane deliver` metinleri ve görselleri yükler; incelemeye göndermeden
önce App Store Connect şunları da ister. Hepsi API ile yapılabilir:

- Fiyat: ücretsiz (kullanıcı kararı).
- Satış ülkeleri: hepsi (fiyat yeni bir uygulamada tek başına yetmez).
- Yaş sınırı anketi: uygulamada şiddet, kumar, kullanıcı içeriği,
  reklam vb. yok; her soru "yok".
- İçerik hakları: Kur'an metni ve mealler üçüncü taraf içeriğidir
  (Tanzil, CC BY; Elmalılı 1935 ve Pickthall 1930 kamu malı), kullanım
  hakkı var.
- İnceleme ekibinin iletişim bilgileri ve notu. Telefon numarası depo
  herkese açık olduğu için depoda durmaz: APP_REVIEW_PHONE sırrından
  okunur, yoksa App Store Connect'te elle girilmiş olanı korunur.

Yapılamayan tek şey Uygulama Gizliliği ("Veri toplamıyoruz"): Apple bunu
API'ye açmıyor, sitede bir kez elle işaretlenir.

Ortam: APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_KEY_IDENTIFIER,
APP_STORE_CONNECT_PRIVATE_KEY, DINI_MAIN_BUNDLE_ID, (isteğe bağlı)
APP_REVIEW_PHONE. `pip install pyjwt cryptography requests`.
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import jwt
import requests

API = "https://api.appstoreconnect.apple.com"
METADATA = Path(__file__).resolve().parent.parent / "store" / "metadata"

REVIEW_CONTACT = {
    "contactFirstName": "Evren",
    "contactLastName": "Altındal",
    "contactEmail": "info@ewocom.com",
}
REVIEW_NOTES = (
    "Namaz Yolu (Prayer Path) works fully offline and needs no account or "
    "sign-in. Prayer times and the Qibla are calculated on the device; the "
    "location is never sent anywhere. If location permission is denied, a "
    "city can be chosen under Settings > Location. The app has no in-app "
    "purchases, no ads and collects no data. The Apple Watch app receives "
    "its schedule from the iPhone app over WatchConnectivity; open the "
    "iPhone app once first."
)

# Yaş sınırı anketindeki sıklık soruları ("yok / seyrek / sık").
FREQUENCY_QUESTIONS = {
    "alcoholTobaccoOrDrugUseOrReferences",
    "contests",
    "gamblingSimulated",
    "gunsOrOtherWeapons",
    "horrorOrFearThemes",
    "matureOrSuggestiveThemes",
    "medicalOrTreatmentInformation",
    "profanityOrCrudeHumor",
    "sexualContentGraphicAndNudity",
    "sexualContentOrNudity",
    "violenceCartoonOrFantasy",
    "violenceRealistic",
    "violenceRealisticProlongedGraphicOrSadistic",
}
# Evet/hayır soruları. "Diyanet'e soru sor" sayfayı Safari'de açar;
# uygulamanın içinde kısıtsız web tarayıcı yoktur.
YES_NO_QUESTIONS = {
    "advertising",
    "ageAssurance",
    "gambling",
    "healthOrWellnessTopics",
    "lootBox",
    "messagingAndChat",
    "parentalControls",
    "unrestrictedWebAccess",
    "userGeneratedContent",
}


class Client:
    def __init__(self) -> None:
        self.issuer = os.environ["APP_STORE_CONNECT_ISSUER_ID"]
        self.key_id = os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"]
        self.key = os.environ["APP_STORE_CONNECT_PRIVATE_KEY"]
        self._token = ""
        self._expires = 0.0

    def _auth(self) -> dict[str, str]:
        if time.time() > self._expires - 60:
            now = int(time.time())
            self._token = jwt.encode(
                {"iss": self.issuer, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                self.key,
                algorithm="ES256",
                headers={"kid": self.key_id, "typ": "JWT"},
            )
            self._expires = now + 1100
        return {"Authorization": f"Bearer {self._token}"}

    def request(self, method: str, path: str, **kwargs) -> dict | None:
        url = path if path.startswith("http") else f"{API}{path}"
        response = requests.request(method, url, headers=self._auth(), timeout=60, **kwargs)
        if response.status_code == 404 and method == "GET":
            return None
        if response.status_code >= 400:
            sys.exit(f"{method} {path} -> {response.status_code}\n{response.text}")
        return response.json() if response.content else {}

    def get_all(self, path: str) -> list[dict]:
        items: list[dict] = []
        page = self.request("GET", path)
        while page:
            items.extend(page.get("data", []))
            nxt = page.get("links", {}).get("next")
            page = self.request("GET", nxt) if nxt else None
        return items


def find_app(api: Client, bundle_id: str) -> str:
    apps = api.get_all(f"/v1/apps?filter[bundleId]={bundle_id}")
    if not apps:
        sys.exit(f"App Store Connect'te {bundle_id} uygulaması yok.")
    return apps[0]["id"]


def editable_app_info(api: Client, app: str) -> dict:
    infos = api.get_all(f"/v1/apps/{app}/appInfos")
    editable = [i for i in infos if i["attributes"].get("state") != "READY_FOR_DISTRIBUTION"]
    return (editable or infos)[0]


def ensure_info_localizations(api: Client, app: str) -> None:
    """Mağaza dillerinin uygulama bilgisi (ad) sayfalarını açar.

    Yeni bir dilde sürüm sayfası açılırken Apple o dilin adını uygulamanın
    adından kopyalar; "Namaz Yolu" İngilizce sayfada başka bir uygulamada
    kullanıldığı için deliver en-US'i açamadı. Ad önce burada, dilin
    kendi name.txt'sindeki adla verilir.
    """
    info = editable_app_info(api, app)
    present = {
        loc["attributes"]["locale"]
        for loc in api.get_all(f"/v1/appInfos/{info['id']}/appInfoLocalizations")
    }
    for folder in sorted(METADATA.iterdir()):
        if not folder.is_dir() or folder.name in present:
            continue
        name_file = folder / "name.txt"
        if not name_file.exists():
            sys.exit(f"{folder.name}: yeni mağaza dili için name.txt gerekli.")
        attributes = {"locale": folder.name, "name": name_file.read_text().strip()}
        for key, file in (("subtitle", "subtitle.txt"), ("privacyPolicyUrl", "privacy_url.txt")):
            if (folder / file).exists():
                attributes[key] = (folder / file).read_text().strip()
        api.request(
            "POST",
            "/v1/appInfoLocalizations",
            json={
                "data": {
                    "type": "appInfoLocalizations",
                    "attributes": attributes,
                    "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}},
                }
            },
        )
        print(f"{folder.name}: mağaza adı '{attributes['name']}' ile açıldı.")


def set_content_rights(api: Client, app: str) -> None:
    api.request(
        "PATCH",
        f"/v1/apps/{app}",
        json={
            "data": {
                "type": "apps",
                "id": app,
                "attributes": {"contentRightsDeclaration": "USES_THIRD_PARTY_CONTENT"},
            }
        },
    )
    print("İçerik hakları: üçüncü taraf içerik, kullanım hakkı var.")


def set_free_price(api: Client, app: str) -> None:
    existing = api.request("GET", f"/v1/appPriceSchedules/{app}/manualPrices")
    if existing and existing.get("data"):
        print("Fiyat zaten ayarlı; dokunulmadı.")
        return
    points = api.get_all(f"/v1/apps/{app}/appPricePoints?filter[territory]=USA&limit=200")
    free = next(p for p in points if float(p["attributes"]["customerPrice"]) == 0)
    api.request(
        "POST",
        "/v1/appPriceSchedules",
        json={
            "data": {
                "type": "appPriceSchedules",
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]},
                },
            },
            "included": [
                {
                    "type": "appPrices",
                    "id": "${free}",
                    "attributes": {"startDate": None},
                    "relationships": {
                        "appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}
                    },
                }
            ],
        },
    )
    print("Fiyat: ücretsiz.")


def set_availability(api: Client, app: str) -> None:
    if api.request("GET", f"/v1/apps/{app}/appAvailabilityV2"):
        print("Satış ülkeleri zaten ayarlı; dokunulmadı.")
        return
    territories = api.get_all("/v1/territories?limit=200")
    api.request(
        "POST",
        "/v2/appAvailabilities",
        json={
            "data": {
                "type": "appAvailabilities",
                "attributes": {"availableInNewTerritories": True},
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app}},
                    "territoryAvailabilities": {
                        "data": [
                            {"type": "territoryAvailabilities", "id": f"${{{t['id']}}}"}
                            for t in territories
                        ]
                    },
                },
            },
            "included": [
                {
                    "type": "territoryAvailabilities",
                    "id": f"${{{t['id']}}}",
                    "attributes": {"available": True},
                    "relationships": {"territory": {"data": {"type": "territories", "id": t["id"]}}},
                }
                for t in territories
            ],
        },
    )
    print(f"Satış ülkeleri: {len(territories)} ülkenin hepsi.")


def set_age_rating(api: Client, app: str) -> None:
    info = editable_app_info(api, app)
    declaration = api.request("GET", f"/v1/appInfos/{info['id']}/ageRatingDeclaration")
    if not declaration:
        sys.exit("Yaş sınırı anketi bulunamadı.")
    current = declaration["data"]["attributes"]
    answers: dict[str, object] = {}
    for name in current:
        if name in FREQUENCY_QUESTIONS:
            answers[name] = "NONE"
        elif name in YES_NO_QUESTIONS:
            answers[name] = False
    api.request(
        "PATCH",
        f"/v1/ageRatingDeclarations/{declaration['data']['id']}",
        json={
            "data": {
                "type": "ageRatingDeclarations",
                "id": declaration["data"]["id"],
                "attributes": answers,
            }
        },
    )
    unknown = sorted(set(current) - FREQUENCY_QUESTIONS - YES_NO_QUESTIONS)
    print(f"Yaş sınırı: {len(answers)} soru 'yok'. Dokunulmayan alanlar: {unknown}")


def set_review_details(api: Client, app: str) -> None:
    versions = api.get_all(
        f"/v1/apps/{app}/appStoreVersions?filter[platform]=IOS"
        "&filter[appStoreState]=PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED"
    )
    if not versions:
        sys.exit("Düzenlenebilir App Store sürümü yok (önce deliver çalışmalı).")
    version = versions[0]["id"]
    attributes = dict(REVIEW_CONTACT, notes=REVIEW_NOTES, demoAccountRequired=False)
    phone = os.environ.get("APP_REVIEW_PHONE", "").strip()
    if phone:
        attributes["contactPhone"] = phone
    detail = api.request("GET", f"/v1/appStoreVersions/{version}/appStoreReviewDetail")
    if detail and detail.get("data"):
        api.request(
            "PATCH",
            f"/v1/appStoreReviewDetails/{detail['data']['id']}",
            json={
                "data": {
                    "type": "appStoreReviewDetails",
                    "id": detail["data"]["id"],
                    "attributes": attributes,
                }
            },
        )
        has_phone = bool(phone or detail["data"]["attributes"].get("contactPhone"))
    else:
        api.request(
            "POST",
            "/v1/appStoreReviewDetails",
            json={
                "data": {
                    "type": "appStoreReviewDetails",
                    "attributes": attributes,
                    "relationships": {
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version}}
                    },
                }
            },
        )
        has_phone = bool(phone)
    print("İnceleme iletişim bilgileri ve notu yazıldı." + ("" if has_phone else " TELEFON EKSİK."))


def main() -> None:
    api = Client()
    app = find_app(api, os.environ.get("DINI_MAIN_BUNDLE_ID", "com.dini.diniFlutter"))
    print(f"Uygulama: {app}")
    if sys.argv[1:] == ["languages"]:
        # deliver'dan önce: yeni mağaza dillerinin adı.
        ensure_info_localizations(api, app)
        return
    set_content_rights(api, app)
    set_free_price(api, app)
    set_availability(api, app)
    set_age_rating(api, app)
    set_review_details(api, app)


if __name__ == "__main__":
    main()
