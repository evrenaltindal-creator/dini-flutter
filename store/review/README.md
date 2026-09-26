# App Review yazışması

- `notes.txt`: App Store Connect → App Review Information → Notes. App
  Review 2.1 "Information Needed" (26.9.2026) amaç, kullanım, dış
  servisler, bölgeler ve üçüncü taraf içeriği sordu ve cevabın bu alana da
  yazılmasını istedi. `tool/app_store_connect_setup.py` buradan okur.
- `reply.txt`: aynı soruya App Review mesajına verilen cevap. Apple'ın
  API'si mesaja cevap yazmaya izin vermez; bilgi notta ve ekte durur.
- `screen-recording.mp4`: App Review'un istediği gerçek iPhone ekran
  kaydı; betik bunu inceleme bilgisine ek olarak yükler. Yüklendikten
  sonra depodan silinir (depo herkese açık).
