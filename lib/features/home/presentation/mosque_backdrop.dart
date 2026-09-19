import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/domain/ramadan_status.dart';
import '../../ramadan/domain/mahya.dart';
import '../../ramadan/presentation/mahya_view.dart';
import '../../prayer_times/domain/timezone_service.dart';
import '../../prayer_times/presentation/providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/mosque_scene_state.dart';
import 'mosque_scene.dart';

/// Perdenin koyuluğu. İçerik yoğunlaştıkça artar.
enum BackdropScrim {
  /// Ana ekran: fotoğraf ana öğedir, metin azdır.
  light,

  /// Liste ve tablo ekranları: metin fotoğrafın üzerinde okunabilmeli.
  heavy,
}

/// Uygulamanın her ekranının arkasında duran cami sahnesi.
///
/// Sahne kabuğun içinde **bir kez** çizilir. Her sayfa kendi kopyasını
/// çizseydi sekme değiştirirken görsel yeniden yüklenir, giriş animasyonu
/// baştan oynar ve fotoğraf bir an kaybolurdu.
///
/// Fotoğraf koyudur; üzerindeki metnin okunabilmesi için her zaman bir perde
/// vardır. Yoğun ekranlarda perde koyulaşır — tabloyu fotoğrafın üzerine
/// perdesiz koymak okunmaz bir ekran demektir.
class MosqueBackdrop extends ConsumerWidget {
  final Widget child;
  final BackdropScrim scrim;

  const MosqueBackdrop({
    required this.child,
    this.scrim = BackdropScrim.heavy,
    super.key,
  });

  /// Okunabilirlik perdesinin anahtarı.
  static const scrimKey = ValueKey('mosque-backdrop-scrim');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ağaçta zaten bir sahne varsa ikincisini çizme. İç içe gelen sayfalar
    // (kabuğun içindeki Ayarlar gibi) aksi halde fotoğrafı iki kez çizer:
    // giriş animasyonu iki kez oynar ve perde üst üste binerek ekranı
    // olduğundan koyu gösterir.
    if (_BackdropMarker.of(context)) return child;

    final times = ref.watch(prayerTimesProvider);
    final settings = ref.watch(effectivePrayerSettingsProvider);
    final now = TimezoneService.inLocation(
      times.timezoneId ?? 'Europe/Istanbul',
      ref.watch(clockProvider)(),
    );
    final state = const MosqueSceneStateResolver().resolve(
      now,
      times,
      friday: now.weekday == DateTime.friday,
      ramadan: ramadanStatus(now, calendar: settings.calendar).isFasting,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Fotoğraf koyu olduğu için durum çubuğu simgeleri açık renk olmalı.
      value: SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: MosqueScene(
              state: state,
              height: MediaQuery.sizeOf(context).height,
              borderRadius: BorderRadius.zero,
              showShadow: false,
            ),
          ),
          // Anahtar testler için: sahnenin kendi içinde de degrade var,
          // perdeyi ondan ayırt etmek gerekiyor.
          DecoratedBox(
            key: scrimKey,
            decoration: BoxDecoration(gradient: _gradient),
          ),
          // Mahya perdenin ÜSTÜNDE çizilir; altında kalsaydı koyu perdeli
          // ekranlarda tamamen kaybolurdu. Parlaklığı perdeye göre düşer:
          // içeriğin okunabilirliği mahyadan önce gelir.
          if (mahyaIsLit(state.period))
            Positioned.fill(child: _Mahya(scrim: scrim)),
          _BackdropMarker(child: child),
        ],
      ),
    );
  }

  LinearGradient get _gradient => switch (scrim) {
    BackdropScrim.light => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x16000000), Colors.transparent, Color(0x42020B0D)],
      stops: [0, .55, 1],
    ),
    // Liste ekranlarında fotoğraf bir doku olarak kalır, metin öne çıkar.
    BackdropScrim.heavy => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xE60A1F1E), Color(0xF2071A19), Color(0xF5040F0F)],
      stops: [0, .5, 1],
    ),
  };
}

/// Ramazan gecelerinde minareler arasına asılan ışıklı yazı.
///
/// Hangi yazının yanacağı hicri geceye bağlıdır; kullanıcının tarih
/// düzeltmesi burada da geçerlidir, yoksa mahya bildirimlerin planlandığı
/// günden başka bir gece için yanar.
class _Mahya extends ConsumerWidget {
  final BackdropScrim scrim;

  const _Mahya({required this.scrim});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final times = ref.watch(prayerTimesProvider);
    final settings = ref.watch(effectivePrayerSettingsProvider);
    final now = TimezoneService.inLocation(
      times.timezoneId ?? 'Europe/Istanbul',
      ref.watch(clockProvider)(),
    );
    final state = const MosqueSceneStateResolver().resolve(
      now,
      times,
      ramadan: ramadanStatus(now, calendar: settings.calendar).isFasting,
    );
    final mahya = mahyaFor(
      now,
      afterMaghrib: mahyaAfterMaghrib(state.period),
      calendar: settings.calendar,
    );
    if (mahya == null) return const SizedBox.shrink();

    final text = context.l10n.text(mahya.textKey);
    return MahyaView(
      text: text,
      semanticsLabel: context.l10n.text('mahya.semantics', {'text': text}),
      imageSize: mosqueSceneImageSize,
      glow: scrim == BackdropScrim.light ? MahyaGlow.full : MahyaGlow.dim,
    );
  }
}

/// Ağaçta bir [MosqueBackdrop] bulunduğunu bildirir.
class _BackdropMarker extends InheritedWidget {
  const _BackdropMarker({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BackdropMarker>() != null;

  @override
  bool updateShouldNotify(_BackdropMarker oldWidget) => false;
}

/// Arka planın üzerinde duran ekranlar için saydam iskelet.
///
/// `Scaffold` varsayılan olarak opak bir zemin çizer ve arkadaki sahneyi
/// tamamen örter; bu sarmalayıcı onu saydam yapar ve üst çubuğu sahneye
/// uydurur.
class BackdropScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget> actions;
  final BackdropScrim scrim;

  const BackdropScaffold({
    required this.body,
    this.title,
    this.actions = const [],
    this.scrim = BackdropScrim.heavy,
    super.key,
  });

  @override
  Widget build(BuildContext context) => MosqueBackdrop(
    scrim: scrim,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              actions: actions,
            ),
      body: body,
    ),
  );
}
