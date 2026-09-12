import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/storage/storage_provider.dart';

const _openingTakbirKey = 'dini.openingTakbir.enabled';

final openingTakbirEnabledProvider = FutureProvider<bool>((ref) async {
  return await ref.watch(localStorageProvider).read(_openingTakbirKey) !=
      'false';
});

class OpeningTakbirGate extends ConsumerStatefulWidget {
  final Widget child;

  const OpeningTakbirGate({super.key, required this.child});

  @override
  ConsumerState<OpeningTakbirGate> createState() => _OpeningTakbirGateState();
}

class _OpeningTakbirGateState extends ConsumerState<OpeningTakbirGate> {
  AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  Future<void> _play() async {
    try {
      final enabled = await ref.read(openingTakbirEnabledProvider.future);
      if (!enabled || !mounted) return;
      final player = AudioPlayer();
      _player = player;
      await player.setVolume(.18);
      await player.play(AssetSource('audio/opening_takbir.mp3'));
    } catch (_) {
      // Ses desteği olmayan cihazlarda uygulamanın açılışı etkilenmez.
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class OpeningTakbirSettingTile extends ConsumerWidget {
  const OpeningTakbirSettingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(openingTakbirEnabledProvider);
    return enabled.when(
      data: (value) => SwitchListTile(
        secondary: const Icon(Icons.volume_down_outlined),
        title: Text(context.l10n.text('settings.openingTakbir')),
        subtitle: Text(context.l10n.text('settings.openingTakbirHint')),
        value: value,
        onChanged: (next) async {
          await ref
              .read(localStorageProvider)
              .write(_openingTakbirKey, '$next');
          ref.invalidate(openingTakbirEnabledProvider);
        },
      ),
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
