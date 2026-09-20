import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../notifications/presentation/notification_settings_page.dart';
import '../../tracker/presentation/prayer_tracker_page.dart';
import 'prayer_guide_view.dart';
import 'wudu_guide_view.dart';

class WorshipHubPage extends StatelessWidget {
  final int initialIndex;

  const WorshipHubPage({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 4,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: Navigator.of(context).canPop(),
          title: Text(l10n.text('worship.title')),
          actions: [
            IconButton(
              tooltip: l10n.text('home.tasbih'),
              onPressed: () => context.push('/tasbih'),
              icon: const Icon(Icons.touch_app_outlined),
            ),
          ],
          // Dört sekme her genişlikte görünür kalmalı: kaydırmalı bir sekme
          // çubuğunda son sekme ekran dışında kalıyor ve kullanıcı onu
          // bulamıyordu. Uzun açıklamalar sayfa içi başlık olarak duruyor.
          bottom: TabBar(
            // Sekme çubuğu cami perdesinin üstünde duruyor; temanın
            // varsayılan renkleri aydınlık kipte seçili olmayan sekmeleri
            // okunmaz hâle getiriyordu.
            labelColor: BackdropPalette.text,
            unselectedLabelColor: BackdropPalette.mutedText,
            indicatorColor: BackdropPalette.text,
            tabs: [
              Tab(
                icon: const Icon(Icons.check_circle_outline),
                text: l10n.text('worship.tracker'),
              ),
              Tab(
                icon: const Icon(Icons.menu_book_outlined),
                text: l10n.text('worship.tabPrayer'),
              ),
              Tab(
                icon: const Icon(Icons.water_drop_outlined),
                text: l10n.text('worship.tabWudu'),
              ),
              Tab(
                icon: const Icon(Icons.alarm_outlined),
                text: l10n.text('worship.alarms'),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PrayerTrackerView(),
            PrayerGuideView(),
            WuduGuideView(),
            NotificationSettingsView(),
          ],
        ),
      ),
    );
  }
}
