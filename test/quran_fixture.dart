import 'dart:io';

import 'package:dini_flutter/features/quran/data/quran_book.dart';

/// Uygulamanın paketindeki Kuran dosyaları, doğrudan diskten.
///
/// Uygulamada kitap arka planda (ayrı bir isolate'te) açılır; testin sahte
/// saati onu hiç bitirmez. Testler kitabı bununla bir kez yükleyip
/// `quranBookProvider`'ı onunla değiştirir.
Future<QuranBook> loadQuranBookFromDisk() =>
    QuranBook.load((asset) async => File(asset).readAsBytesSync());
