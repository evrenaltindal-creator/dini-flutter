#!/usr/bin/env python3
"""Bildirim tonunu sentezler.

Uygulamaya telifli bir kayıt koyamayız (bkz. CLAUDE.md). Bu betik tonu
sıfırdan üretir: ortada bir kayıt yoktur, yalnızca sinüs toplamları vardır,
dolayısıyla telif sorunu da yoktur.

Ton bir çan modelidir: temel frekansın üstüne uyumsuz (inharmonik) üst
sesler biner ve her biri farklı hızda söner. Arka arkaya iki vuruş vardır.
Ezan DEĞİLDİR ve arayüzde öyle adlandırılmaz.

    python3 tool/generate_notification_tone.py
"""

import math
import os
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

RATE = 22050
DURATION = 2.6

# Çan üst sesleri: (temel frekansa oran, başlangıç genliği, sönüm hızı).
# Uyumsuz oranlar sese metalik, çan benzeri bir karakter verir.
PARTIALS = [
    (1.00, 1.00, 1.6),
    (2.00, 0.50, 2.4),
    (3.01, 0.28, 3.2),
    (4.17, 0.16, 4.4),
    (5.43, 0.09, 5.6),
]

# İki vuruş: (başlangıç saniyesi, temel frekans, genlik). C5 ve onun beşlisi G5.
STRIKES = [(0.00, 523.25, 1.00), (0.42, 783.99, 0.72)]


def _samples():
    total = int(RATE * DURATION)
    data = [0.0] * total
    for start, frequency, level in STRIKES:
        offset = int(start * RATE)
        for index in range(offset, total):
            t = (index - offset) / RATE
            value = 0.0
            for ratio, amplitude, decay in PARTIALS:
                value += amplitude * math.exp(-decay * t) * math.sin(
                    2 * math.pi * frequency * ratio * t
                )
            data[index] += level * value

    peak = max(abs(value) for value in data) or 1.0
    # Tepe değeri 0 dB'in biraz altında tut; bildirim sesleri kırpılmamalı.
    gain = 0.89 / peak

    fade = int(0.12 * RATE)
    result = []
    for index, value in enumerate(data):
        scaled = value * gain
        # Sondaki ani kesilme tık sesi yapar; son 120 ms yumuşatılır.
        remaining = total - index
        if remaining < fade:
            scaled *= remaining / fade
        result.append(max(-1.0, min(1.0, scaled)))
    return result


def _write(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(
            b"".join(struct.pack("<h", int(value * 32767)) for value in samples)
        )
    print("wrote", os.path.relpath(path, ROOT), os.path.getsize(path), "bytes")


def main():
    samples = _samples()
    # Android bildirim kanalı sesi res/raw altından okunur.
    _write(
        os.path.join(ROOT, "android/app/src/main/res/raw/notification_tone.wav"),
        samples,
    )
    # iOS'ta aynı dosya Flutter varlığı olarak taşınır ve ilk açılışta
    # uygulama kabının Library/Sounds klasörüne kopyalanır.
    _write(os.path.join(ROOT, "assets/audio/notification_tone.wav"), samples)


if __name__ == "__main__":
    main()
