#!/usr/bin/env python3
"""Ezan kaydını bildirim sesine çevirir.

Kayıt depoya bu betikle girer, elle değil. Betik:

* yalnızca 16 bit PCM WAV okur (standart kitaplık dışında bağımlılık yok);
  MP3/M4A ise önce çevirin:  ffmpeg -i ezan.mp3 -ac 1 -ar 44100 ezan.wav
* iOS bildirim sesini en fazla 30 saniye çalar, daha uzununda sessizce
  varsayılan sese döner — kayıt 29 saniyeye kırpılır ve son 1,5 saniyesi
  kısılarak biter (kesik bitmesin);
* çıktıyı iki yere yazar: `assets/audio/ezan.wav` (iOS, açılışta
  Library/Sounds'a kopyalanır) ve `android/app/src/main/res/raw/ezan.wav`
  (Android bildirim kanalının sesi);
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
ASSET = os.path.join(ROOT, "assets/audio/ezan.wav")
ANDROID = os.path.join(ROOT, "android/app/src/main/res/raw/ezan.wav")
SOURCE_NOTE = os.path.join(ROOT, "assets/audio/EZAN_SOURCE.txt")

# iOS 30 saniyede keser; pay bırakılır.
MAX_SECONDS = 29.0
FADE_SECONDS = 1.5


def prepare(path, *, start_seconds=0.0):
    with wave.open(path, "rb") as source:
        if source.getsampwidth() != 2:
            raise SystemExit(
                "yalnızca 16 bit PCM WAV okunuyor; önce çevirin: "
                "ffmpeg -i girdi -ac 1 -ar 44100 -sample_fmt s16 ezan.wav"
            )
        channels = source.getnchannels()
        rate = source.getframerate()
        source.setpos(min(source.getnframes(), int(start_seconds * rate)))
        frames = source.readframes(int(MAX_SECONDS * rate))

    samples = array.array("h")
    samples.frombytes(frames)
    if sys.byteorder == "big":
        samples.byteswap()

    total = len(samples) // channels
    fade = min(total, int(FADE_SECONDS * rate))
    for frame in range(total - fade, total):
        # Doğrusal kısma: son kare sıfıra iner.
        gain = (total - frame) / fade if fade else 1.0
        for channel in range(channels):
            index = frame * channels + channel
            samples[index] = int(samples[index] * gain)

    if sys.byteorder == "big":
        samples.byteswap()
    data = samples.tobytes()

    for target in (ASSET, ANDROID):
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with wave.open(target, "wb") as out:
            out.setnchannels(channels)
            out.setsampwidth(2)
            out.setframerate(rate)
            out.writeframes(data)
        print("wrote", os.path.relpath(target, ROOT), f"{total / rate:.1f} s")
    return total / rate


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("wav")
    parser.add_argument("--source", required=True)
    parser.add_argument("--license", required=True)
    parser.add_argument(
        "--start", type=float, default=0.0, help="kaydın kaçıncı saniyesinden"
    )
    args = parser.parse_args()
    if not args.license.strip():
        raise SystemExit("lisans boş olamaz; telifi olan kayıt uygulamaya alınmaz")

    seconds = prepare(args.wav, start_seconds=args.start)
    with open(SOURCE_NOTE, "w", encoding="utf-8") as note:
        note.write("Ezan bildirim sesi\n")
        note.write(f"Kaynak: {args.source.strip()}\n")
        note.write(f"Lisans: {args.license.strip()}\n")
        note.write(f"Süre: {seconds:.1f} sn (iOS sınırı 30 sn)\n")
    print("wrote", os.path.relpath(SOURCE_NOTE, ROOT))


if __name__ == "__main__":
    main()
