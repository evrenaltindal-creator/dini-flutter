import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_localizations.dart';
import '../domain/content_repository.dart';

class DailyContentCard extends StatefulWidget {
  final String title;
  final DailyContent content;
  final bool initiallyFavorite;
  final bool glass;
  final ValueChanged<bool>? onFavoriteChanged;
  const DailyContentCard({
    required this.title,
    required this.content,
    this.initiallyFavorite = false,
    this.glass = false,
    this.onFavoriteChanged,
    super.key,
  });
  @override
  State<DailyContentCard> createState() => _DailyContentCardState();
}

class _DailyContentCardState extends State<DailyContentCard> {
  late bool favorite;
  bool expanded = false;
  @override
  void initState() {
    super.initState();
    favorite = widget.initiallyFavorite;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.content.shareText;
    final foreground = widget.glass ? Colors.white : null;
    final accent = widget.glass ? const Color(0xFFFFD88A) : null;
    return Card(
      color: widget.glass ? const Color(0xC20A2425) : null,
      elevation: widget.glass ? 0 : null,
      shape: widget.glass
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0x45FFFFFF)),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.text(
                    favorite ? 'content.removeFavorite' : 'content.addFavorite',
                  ),
                  onPressed: () {
                    setState(() => favorite = !favorite);
                    widget.onFavoriteChanged?.call(favorite);
                  },
                  color: foreground,
                  icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
                ),
              ],
            ),
            Text(
              text,
              style: TextStyle(color: foreground, height: 1.45),
              maxLines: expanded ? null : 3,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: accent),
                onPressed: () => setState(() => expanded = !expanded),
                child: Text(
                  context.l10n.text(
                    expanded ? 'content.collapse' : 'content.more',
                  ),
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: context.l10n.text('content.copy'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.text('content.copied')),
                        ),
                      );
                    }
                  },
                  color: foreground,
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: context.l10n.text('content.share'),
                  onPressed: () => Share.share(text, subject: widget.title),
                  color: foreground,
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
