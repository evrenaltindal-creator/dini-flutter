import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/content_repository.dart';

class DailyContentCard extends StatefulWidget {
  final String title;
  final DailyContent content;
  final bool initiallyFavorite;
  final ValueChanged<bool>? onFavoriteChanged;
  const DailyContentCard({
    required this.title,
    required this.content,
    this.initiallyFavorite = false,
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
    return Card(
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: favorite ? 'Favoriden çıkar' : 'Favoriye ekle',
                  onPressed: () {
                    setState(() => favorite = !favorite);
                    widget.onFavoriteChanged?.call(favorite);
                  },
                  icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
                ),
              ],
            ),
            Text(
              text,
              maxLines: expanded ? null : 3,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => expanded = !expanded),
                child: Text(expanded ? 'Daralt' : 'Devamını gör'),
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Metni kopyala',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Metin kopyalandı')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: 'Paylaş',
                  onPressed: () => Share.share(text, subject: widget.title),
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
