# STEP 5 — Release Readiness

## Free/Premium boundary

Free remains: prayer times, Qibla, essential local notifications, Hijri calendar, religious events, daily verse/hadith/dua, basic tracker, basic tasbih, basic widget and default dynamic mosque theme. Premium is limited to personalization, additional scene/widget appearance variants and factual local history/statistics. No core worship accuracy or access is gated.

## Store architecture

`in_app_purchase` is the maintained Flutter bridge for StoreKit and Google Play Billing. `PurchaseService` is store-independent at the UI/domain boundary. The product IDs are centralized dev placeholders (`com.dini.dini_flutter.premium.monthly.dev`, `.yearly.dev`, `.lifetime.dev`) and must be replaced with registered IDs before release. Store product title, description and localized price are queried at runtime; unavailable metadata produces no price.

Monthly and yearly are subscription products. Lifetime is modeled separately as a non-consumable purchase. The local entitlement cache is UX continuity only and is reconciled from store purchase updates/restore. Without a custom backend, this is not server-grade receipt verification and a future verifier can be introduced behind `PurchaseService` without changing UI/domain contracts.

## Privacy inventory

| Category | Storage | Purpose | Transmitted | Recipient | Deletion |
|---|---|---|---|---|---|
| Location | Local settings | Prayer/Qibla calculation | No | None | Delete All removes it |
| Prayer settings | Local storage | Calculation and scheduling | No | None | Delete All resets defaults |
| Prayer tracker | Local storage by effective date | User tracking | No | None | Delete All removes history |
| Tasbih | Local storage | Counter/session/history | No | None | Delete All removes state/history |
| Favorites | Local storage | Saved content | No | None | Delete All removes favorites |
| Widget snapshot | OS shared widget storage | Basic next-prayer widget | OS extension only | WidgetKit/AppWidget | Clear snapshot/delete flow |
| Notification settings | Local storage and OS scheduler | Local reminders | No remote push | Local OS scheduler | Cancelled and deleted |
| Purchase state/cache | Store infrastructure plus local cache | Purchase UX/entitlement | Apple/Google receive transaction data | App Store/Google Play | Local cache only; ownership is not cancelled |

## Metadata and release checklist

Before release, replace or confirm: final app name, iOS bundle identifier, Android applicationId, semantic version/build number, privacy policy URL, support URL, App Store and Play descriptions, screenshots, category and age/content declarations. Legal/company values are intentionally not invented. Version increments use `major.minor.patch+build`; build numbers increase monotonically for each store upload.

Android release requires a private keystore stored outside the repository, secret signing values supplied only through CI/environment configuration, `flutter build appbundle --release`, Play Console internal testing, license testers and product/restore/pending/offline validation. iOS release requires signing and provisioning, App Group capability, widget extension signing, StoreKit products/configuration, TestFlight and App Store Connect validation. None can be fully validated on Linux.

## Device acceptance plan

Validate on physical Android and iOS devices: automatic/manual location, timezone/DST and midnight rollover; Qibla sensor calibration and lifecycle; notification permission/schedule/reminder/reboot/timezone change; iOS small/medium and Android compact/medium widgets, privacy toggle and prayer transition; tracker date persistence; tasbih haptics/persistence; monthly/yearly/lifetime purchases, restore, cancel, pending and offline; large text, VoiceOver/TalkBack and reduced motion.

## Security and dependency audit

No custom backend, Firebase, Supabase, analytics, ads, remote push or tracking SDK is added. No credentials, signing material, receipt tokens or release bypass are stored in source. Store billing and external URL launcher are the only new network-capable integrations; product and Diyanet external communication is user initiated. Diyanet’s configured URL is not considered current/officially verified until release-time web verification.
