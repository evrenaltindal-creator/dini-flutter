#!/usr/bin/env python3
"""Ezan kaydını uygulamanın kısa ezan sesine çevirir.

Aynı ses iki yerde çalar: uygulama açılırken ve (seçilirse) vakit
bildiriminde. Kayıt depoya bu betikle girer, elle değil. Betik:

* yalnızca 16 bit PCM WAV okur (standart kitaplık dışında bağımlılık yok);
  MP3/M4A ise önce çevirin:  ffmpeg -i ezan.mp3 -ac 1 -ar 44100 ezan.wav
* kaydın ilk 5 saniyesini alır (`--seconds`); ilk kısmı olduğu gibi,
  normal sesle çalar, son 3 saniyede sesi yavaşça kısılıp sıfıra iner;
* sesi normalleştirir: en yüksek nokta tam ölçeğin %70'i olur, kayıttan
  kayda açılış sesi birden patlamasın ya da duyulmayacak kadar kısık
  kalmasın;
* iOS bildirim sesini en fazla 30 saniye çalar, daha uzununda sessizce
  varsayılan sese döner — `--seconds` 29'dan büyük olamaz;
* çıktıyı iki yere yazar: `assets/audio/ezan.wav` (açılış sesi; iOS'ta
  ayrıca Library/Sounds'a kopyalanır) ve
  `android/app/src/main/res/raw/ezan.wav` (Android bildirim kanalının sesi);
* kaynağı ve lisansı `assets/audio/EZAN_SOURCE.txt` dosyasına yazar.
  **Lisans vermeden çalışmaz:** telifi olan bir kayıt uygulamaya alınmaz.

    python3 tool/prepare_ezan_sound.py kayit.wav \\
        --source "Kaydın nereden geldiği (müezzin, cami, bağlantı)" \\
        --license "Lisansı ya da izin (ör. CC0, kamu malı, yazılı izin)"
"""

import argparse
import array
import os
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET = "assets/audio/ezan.wav"
ANDROID = "android/app/src/main/res/raw/ezan.wav"
SOURCE_NOTE = "assets/audio/EZAN_SOURCE.txt"

DEFAULT_SECONDS = 5.0
# iOS 30 saniyede keser; pay bırakılır.
MAX_SECONDS = 29.0
# Sesin kısıldığı kısım: sonun 3 saniyesi, kısa klipte en çok %60'ı.
FADE_SECONDS = 3.0
PEAK = 0.7


def prepare(path, *, start_seconds=0.0, seconds=DEFAULT_SECONDS, root=ROOT):
    with wave.open(path, "rb") as source:
        if source.getsampwidth() != 2:
            raise SystemExit(
                "yalnızca 16 bit PCM WAV okunuyor; önce çevirin: "
                "ffmpeg -i girdi -ac 1 -ar 44100 -sample_fmt s16 ezan.wav"
            )
        channels = source.getnchannels()
        rate = source.getframerate()
        source.setpos(min(source.getnframes(), int(start_seconds * rate)))
        frames = source.readframes(int(seconds * rate))

    samples = array.array("h")
    samples.frombytes(frames)
    if sys.byteorder == "big":
        samples.byteswap()

    total = len(samples) // channels
    if total == 0:
        raise SystemExit("kayıt boş ya da --start kaydın sonundan sonra")

    loudest = max(abs(value) for value in samples) or 1
    level = PEAK * 32767 / loudest

    fade = min(int(FADE_SECONDS * rate), int(total * 0.6))
    hold = total - fade
    for frame in range(total):
        gain = level
        if frame >= hold:
            # Karesel eğri: kulak sesi logaritmik duyar; doğrusal kısma uzun
            # süre aynı kalıp en sonda birden kesiliyor gibi gelir.
            remaining = (total - 1 - frame) / max(1, fade - 1)
            gain *= remaining * remaining
        for channel in range(channels):
            index = frame * channels + channel
            value = int(round(samples[index] * gain))
            samples[index] = max(-32768, min(32767, value))

    if sys.byteorder == "big":
        samples.byteswap()
    data = samples.tobytes()

    for relative in (ASSET, ANDROID):
        target = os.path.join(root, relative)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with wave.open(target, "wb") as out:
            out.setnchannels(channels)
            out.setsampwidth(2)
            out.setframerate(rate)
            out.writeframes(data)
        print("wrote", relative, f"{total / rate:.1f} s")
    return total / rate


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("wav")
    parser.add_argument("--source", required=True)
    parser.add_argument("--license", required=True)
    parser.add_argument(
        "--start", type=float, default=0.0, help="kaydın kaçıncı saniyesinden"
    )
    parser.add_argument(
        "--seconds",
        type=float,
        default=DEFAULT_SECONDS,
        help=f"klibin uzunluğu (varsayılan {DEFAULT_SECONDS:g}, en çok {MAX_SECONDS:g})",
    )
    parser.add_argument("--root", default=ROOT, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if not args.source.strip():
        raise SystemExit("kaynak boş olamaz; kaydın nereden geldiği yazılmalı")
    if not args.license.strip():
        raise SystemExit("lisans boş olamaz; telifi olan kayıt uygulamaya alınmaz")
    if not 1.0 <= args.seconds <= MAX_SECONDS:
        raise SystemExit(f"--seconds 1 ile {MAX_SECONDS:g} arasında olmalı")

    seconds = prepare(
        args.wav, start_seconds=args.start, seconds=args.seconds, root=args.root
    )
    with open(os.path.join(args.root, SOURCE_NOTE), "w", encoding="utf-8") as note:
        note.write("Ezan sesi (açılış ve bildirim)\n")
        note.write(f"Kaynak: {args.source.strip()}\n")
        note.write(f"Lisans: {args.license.strip()}\n")
        note.write(f"Süre: {seconds:.1f} sn, sonu kısılarak biter\n")
    print("wrote", SOURCE_NOTE)


if __name__ == "__main__":
    main()
