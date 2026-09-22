import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/storage_provider.dart';
import '../../../shared/models/domain.dart';
import '../../home/presentation/mosque_backdrop.dart';
import '../data/prayer_voice.dart';
import '../domain/guided_prayer.dart';
import '../domain/worship_guide.dart';
import 'prayer_figure.dart';

/// Ekranın kararmasını açıp kapatır; testte ve desteklemeyen cihazda sessiz.
final screenAwakeProvider = Provider<Future<void> Function(bool)>(
  (ref) => (awake) async {
    try {
      await WakelockPlus.toggle(enable: awake);
    } catch (_) {}
  },
);

const _speedKey = 'dini.hoca.speed';
const _voiceKey = 'dini.hoca.voice';

/// Seçilebilen hızlar.
const guidedSpeeds = [.5, .75, 1.0, 1.25, 1.5, 2.0];

/// Namaz hocası: namazı bir hoca gibi adım adım kıldırır.
///
/// Ortada figür o anki hareketi gösterir, altta o adımda okunacak dualar
/// Arapça, okunuşu ve (istenirse) anlamıyla yazar. "Başlat"a basınca adımlar
/// okunacak metnin uzunluğuna göre kendiliğinden ilerler; hız 0,5× ile 2×
/// arasında ayarlanır. Sesli okuma açıksa adım, okuma bitince geçer.
class GuidedPrayerPage extends ConsumerStatefulWidget {
  final DailyPrayerGuide guide;

  /// Yalnızca bu bölüm kılınır; null ise bütün bölümler sırayla.
  final int? partIndex;

  const GuidedPrayerPage({super.key, required this.guide, this.partIndex});

  static String routeFor(Prayer prayer, {int? part}) =>
      '/guide/prayer/${prayer.name}/hoca${part == null ? '' : '?part=$part'}';

  static const figureKey = ValueKey('guided-prayer-figure');
  static const playKey = ValueKey('guided-prayer-play');

  @override
  ConsumerState<GuidedPrayerPage> createState() => _GuidedPrayerPageState();
}

class _GuidedPrayerPageState extends ConsumerState<GuidedPrayerPage>
    with SingleTickerProviderStateMixin {
  late final List<GuidedStep> steps = guidedPrayerSteps(
    widget.guide,
    partIndex: widget.partIndex,
  );
  late final AnimationController stepProgress = AnimationController(
    vsync: this,
  );

  int index = 0;
  bool playing = false;
  bool finished = false;
  bool showMeaning = false;
  double speed = 1;
  bool voiceOn = false;

  /// Telefonda Arapça ses var mı? Sesli okuma ilk açıldığında öğrenilir.
  bool? voiceAvailable;

  /// Sesli okunan metnin adımdaki sırası; vurgulanır.
  int? speaking;

  Timer? timer;

  /// Her yeniden planlamada artar; eski bir okuma bittiğinde yanlış adımı
  /// ilerletmesin diye.
  int run = 0;

  GuidedStep get step => steps[index];

  // dispose() içinde ref kullanılamaz; ikisi açılışta alınır.
  late final PrayerVoice voice;
  late final Future<void> Function(bool) keepAwake;

  @override
  void initState() {
    super.initState();
    voice = ref.read(prayerVoiceProvider);
    keepAwake = ref.read(screenAwakeProvider);
    keepAwake(true);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final storage = ref.read(localStorageProvider);
    final savedSpeed = double.tryParse(await storage.read(_speedKey) ?? '');
    final savedVoice = await storage.read(_voiceKey) == 'true';
    if (!mounted) return;
    setState(() {
      if (savedSpeed != null && guidedSpeeds.contains(savedSpeed)) {
        speed = savedSpeed;
      }
      voiceOn = savedVoice;
    });
    if (savedVoice) await _prepareVoice();
  }

  Future<void> _prepareVoice() async {
    final available = await voice.prepare();
    if (!mounted) return;
    setState(() => voiceAvailable = available);
  }

  @override
  void dispose() {
    timer?.cancel();
    run++;
    voice.stop();
    keepAwake(false);
    stepProgress.dispose();
    super.dispose();
  }

  bool get _speaks =>
      voiceOn && voiceAvailable == true && step.recitations.isNotEmpty;

  /// O anki adımı baştan planlar: süre dolunca ya da okuma bitince geçer.
  void _schedule() {
    timer?.cancel();
    final token = ++run;
    voice.stop();
    speaking = null;
    stepProgress
      ..stop()
      ..value = 0;
    if (!playing || finished) return;
    if (_speaks) {
      _speakStep(token);
    } else {
      final duration = guidedStepDuration(step, speed: speed);
      stepProgress
        ..duration = duration
        ..forward(from: 0);
      timer = Timer(duration, _advance);
    }
  }

  Future<void> _speakStep(int token) async {
    for (final (position, item) in step.recitations.indexed) {
      for (var time = 0; time < item.repeat; time++) {
        if (token != run || !mounted) return;
        setState(() => speaking = position);
        await voice.speak(item.recitation.arabic, speed: speed);
      }
    }
    if (token != run || !mounted) return;
    setState(() => speaking = null);
    // Hareket için kısa bir soluk.
    timer = Timer(Duration(milliseconds: (1500 / speed).round()), _advance);
  }

  void _advance() {
    if (!mounted) return;
    setState(() {
      if (index < steps.length - 1) {
        index++;
      } else {
        finished = true;
        playing = false;
      }
    });
    _schedule();
  }

  void _goTo(int target) {
    setState(() {
      index = target.clamp(0, steps.length - 1);
      finished = false;
    });
    _schedule();
  }

  void _togglePlay() {
    setState(() {
      if (finished) {
        finished = false;
        index = 0;
      }
      playing = !playing;
    });
    _schedule();
  }

  void _restart() {
    setState(() {
      finished = false;
      index = 0;
      playing = true;
    });
    _schedule();
  }

  Future<void> _setSpeed(double value) async {
    setState(() => speed = value);
    _schedule();
    await ref.read(localStorageProvider).write(_speedKey, '$value');
  }

  Future<void> _toggleVoice() async {
    final next = !voiceOn;
    setState(() => voiceOn = next);
    await ref.read(localStorageProvider).write(_voiceKey, '$next');
    if (next && voiceAvailable == null) await _prepareVoice();
    if (mounted) _schedule();
  }

  String _partLabel(AppLocalizations l10n, PrayerPartKind kind) =>
      switch (kind) {
        PrayerPartKind.firstSunnah => l10n.text('guide.firstSunnah'),
        PrayerPartKind.fard => l10n.text('guide.fard'),
        PrayerPartKind.finalSunnah => l10n.text('guide.finalSunnah'),
        PrayerPartKind.witr => l10n.text('guide.witr'),
      };

  String _speedLabel(BuildContext context, double value) {
    var text = value % 1 == 0 ? value.toInt().toString() : value.toString();
    if (Localizations.localeOf(context).languageCode != 'en') {
      text = text.replaceAll('.', ',');
    }
    return context.l10n.text('hoca.speedValue', {'value': text});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final posture = finished ? PrayerPosture.sitting : step.posture;
    final speedIndex = guidedSpeeds.indexOf(speed);

    return BackdropScaffold(
      title: l10n.text('hoca.title'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nerede olduğumuz: vakit, bölüm, rekât, adım.
              Card(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${l10n.prayer(widget.guide.prayer.name)} · '
                              '${_partLabel(l10n, step.part.kind)} · '
                              '${l10n.text('guide.rakatLabel', {'index': step.rakat})}',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            l10n.text('hoca.stepOf', {
                              'current': index + 1,
                              'total': steps.length,
                            }),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: finished ? 1 : (index + 1) / steps.length,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),
              // Hareket: figür ve ne yapılacağı yan yana (Arapçada yer
              // değiştirir).
              Card(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 10, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 130,
                            child: PrayerFigure(
                              key: GuidedPrayerPage.figureKey,
                              posture: posture,
                              semanticLabel: l10n.text(
                                'hoca.posture.${posture.name}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.text('hoca.posture.${posture.name}'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  finished
                                      ? l10n.text('hoca.finished')
                                      : l10n.text(step.instructionKey),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AnimatedBuilder(
                        animation: stepProgress,
                        builder: (context, _) => LinearProgressIndicator(
                          value: stepProgress.value,
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Okunacaklar.
              Expanded(
                child: Card(
                  child: finished
                      ? _Finished(onRestart: _restart)
                      : _RecitationPanel(
                          guide: widget.guide,
                          step: step,
                          showMeaning: showMeaning,
                          speaking: speaking,
                          onToggleMeaning: () =>
                              setState(() => showMeaning = !showMeaning),
                        ),
                ),
              ),
              // Denetimler.
              Card(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: l10n.text('hoca.previous'),
                            onPressed: index == 0 && !finished
                                ? null
                                : () => _goTo(finished ? index : index - 1),
                            icon: const Icon(Icons.skip_previous_rounded),
                          ),
                          Expanded(
                            child: FilledButton.icon(
                              key: GuidedPrayerPage.playKey,
                              onPressed: _togglePlay,
                              icon: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              label: Text(
                                l10n.text(playing ? 'hoca.pause' : 'hoca.play'),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.text('hoca.next'),
                            onPressed: finished ? null : _advance,
                            icon: const Icon(Icons.skip_next_rounded),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            l10n.text('hoca.speed'),
                            style: theme.textTheme.bodyMedium,
                          ),
                          IconButton(
                            tooltip: l10n.text('hoca.slower'),
                            onPressed: speedIndex <= 0
                                ? null
                                : () => _setSpeed(guidedSpeeds[speedIndex - 1]),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            _speedLabel(context, speed),
                            style: theme.textTheme.titleSmall,
                          ),
                          IconButton(
                            tooltip: l10n.text('hoca.faster'),
                            onPressed: speedIndex >= guidedSpeeds.length - 1
                                ? null
                                : () => _setSpeed(guidedSpeeds[speedIndex + 1]),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          const Spacer(),
                          IconButton.filledTonal(
                            tooltip: l10n.text(
                              voiceOn ? 'hoca.voiceOff' : 'hoca.voice',
                            ),
                            isSelected: voiceOn,
                            onPressed: _toggleVoice,
                            icon: const Icon(Icons.volume_off_outlined),
                            selectedIcon: const Icon(Icons.volume_up_rounded),
                          ),
                        ],
                      ),
                      if (voiceOn)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            8,
                            0,
                            8,
                            4,
                          ),
                          child: Text(
                            l10n.text(
                              voiceAvailable == false
                                  ? 'hoca.voiceMissing'
                                  : 'hoca.voiceNotice',
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecitationPanel extends StatelessWidget {
  final DailyPrayerGuide guide;
  final GuidedStep step;
  final bool showMeaning;
  final int? speaking;
  final VoidCallback onToggleMeaning;

  const _RecitationPanel({
    required this.guide,
    required this.step,
    required this.showMeaning,
    required this.speaking,
    required this.onToggleMeaning,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (step.recitations.isEmpty) {
      // Niyet: kalpten edilir; cümlesi yol göstersin diye yazılır.
      return ListView(
        padding: const EdgeInsetsDirectional.all(18),
        children: [
          Text(
            l10n.text('hoca.intentLabel'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.text(intentKeyFor(guide, step.part), {
              'prayer': l10n.text(intentPrayerKey(guide.prayer)),
            }),
            style: theme.textTheme.titleMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          Text(l10n.text('hoca.learnNotice'), style: theme.textTheme.bodySmall),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
      children: [
        AlignmentDirectionalButton(
          label: l10n.text(
            showMeaning ? 'hoca.hideMeaning' : 'hoca.showMeaning',
          ),
          onPressed: onToggleMeaning,
        ),
        for (final (position, item) in step.recitations.indexed)
          _RecitationBlock(
            item: item,
            showMeaning: showMeaning,
            highlighted: speaking == position,
          ),
      ],
    );
  }
}

/// Satırın sonuna (yöne göre) yaslanmış küçük metin düğmesi.
class AlignmentDirectionalButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const AlignmentDirectionalButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: TextButton(onPressed: onPressed, child: Text(label)),
  );
}

class _RecitationBlock extends StatelessWidget {
  final GuidedRecitation item;
  final bool showMeaning;
  final bool highlighted;

  const _RecitationBlock({
    required this.item,
    required this.showMeaning,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recitation = item.recitation;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.text(recitation.nameKey),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (item.repeat > 1)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(l10n.text('hoca.repeat', {'count': item.repeat})),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Arapça metin her dilde sağdan sola yazılır.
          Text(
            recitation.arabic,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, height: 1.9),
          ),
          const SizedBox(height: 6),
          Text(
            recitation.transliteration,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
          if (showMeaning) ...[
            const SizedBox(height: 8),
            Text(
              l10n.text(recitation.meaningKey),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.text(recitation.sourceKey),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  final VoidCallback onRestart;

  const _Finished({required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.text('hoca.finished'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.replay_rounded),
              label: Text(l10n.text('hoca.again')),
            ),
          ],
        ),
      ),
    );
  }
}
