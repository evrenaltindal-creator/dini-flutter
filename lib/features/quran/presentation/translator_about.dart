import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import 'quran_style.dart';

/// Hakkında yazısı olan mealler (kimlik → anahtar öneki
/// `quran.translatorAbout.<kimlik>.title/body/sources`).
///
/// Yazılar kaynağa dayanır; kaynağı gösterilemeyen bilgi yazılmaz. Örneğin
/// "Atatürk meali kendi cebinden ödedi" yaygın ama yanlıştır: ödenek
/// TBMM'nin 21 Şubat 1925'te Diyanet bütçesine koyduğu paradır.
const translatorsWithAbout = {'tr.elmalili'};

/// Meal sayfasının başındaki satır: "Meal: Elmalılı Muhammed Hamdi Yazır".
///
/// Mealin kimin olduğu her sûrenin başında yazar; hakkında yazısı olan
/// mütercimin adına dokununca yazı açılır.
class TranslatorLine extends StatelessWidget {
  final String id;

  const TranslatorLine({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final name = Text(
      context.l10n.text('quran.translator.$id'),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: QuranPalette.green,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
    if (!translatorsWithAbout.contains(id)) {
      return Padding(padding: const EdgeInsets.only(bottom: 6), child: name);
    }
    return Center(
      child: TextButton.icon(
        onPressed: () => showTranslatorAbout(context, id),
        icon: const Icon(
          Icons.info_outline,
          size: 18,
          color: QuranPalette.green,
        ),
        label: name,
      ),
    );
  }
}

/// Mütercim hakkında yazı: kâğıt renkli bir alt sayfa.
Future<void> showTranslatorAbout(BuildContext context, String id) =>
    showModalBottomSheet<void>(
      context: context,
      // Kök gezgin: sekme çubuğunun altında kalmasın, son satırlar
      // (kaynaklar) çubuğun arkasına düşmesin.
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: QuranPalette.paper,
      builder: (context) => TranslatorAboutSheet(id: id),
    );

class TranslatorAboutSheet extends StatelessWidget {
  final String id;

  const TranslatorAboutSheet({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final key = 'quran.translatorAbout.$id';
    // Kâğıt krem, uygulama koyu temada: yazı renkleri açıkça verilir.
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .82,
      maxChildSize: .95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
        children: [
          Text(
            l10n.text('$key.title'),
            style: const TextStyle(
              color: QuranPalette.green,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          for (final paragraph in l10n.text('$key.body').split('\n\n')) ...[
            Text(
              paragraph,
              style: const TextStyle(
                color: QuranPalette.ink,
                fontSize: 16,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Divider(color: QuranPalette.goldLight),
          const SizedBox(height: 6),
          Text(
            l10n.text('$key.sources'),
            style: const TextStyle(
              color: QuranPalette.mutedInk,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
