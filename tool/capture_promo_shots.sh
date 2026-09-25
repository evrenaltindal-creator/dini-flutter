#!/usr/bin/env bash
# Web sitesi için gerçek uygulama ekran görüntülerini üretir.
#
# Görüntüler test/promo_shots_test.dart içinde çizilir ve
# build/promo_shots/ altına yazılır. Sonra tool/generate_web_assets.py
# bunları çerçeveleyip docs/promo/ altına koyar.
#
# Neden her ekran ayrı koşucuda: görüntü diske yazıldıktan sonra koşucu
# kapanmıyor (ekranlar pusula ve ses akışlarını açık bırakıyor), tek bir
# `flutter test` çağrısı ilk ekrandan sonra asılıyor. Burada dosya
# düşer düşmez koşucu kesiliyor.
set -u
cd "$(dirname "$0")/.."

screens=(home qibla imsakiye tracker worship calendar tasbih leaf)
for name in "${screens[@]}"; do
  rm -f "build/promo_shots/$name.png"
  # --run-skipped: dart_test.yaml bu etiketi CI'da atlıyor.
  timeout 180 flutter test --run-skipped test/promo_shots_test.dart \
    --plain-name "$name" >/dev/null 2>&1 &
  runner=$!
  for _ in $(seq 1 90); do
    [ -s "build/promo_shots/$name.png" ] && sleep 2 && break
    sleep 2
  done
  kill $runner 2>/dev/null
  pkill -f flutter_tester 2>/dev/null
  if [ -s "build/promo_shots/$name.png" ]; then echo "OK   $name"; else echo "YOK  $name"; fi
done
