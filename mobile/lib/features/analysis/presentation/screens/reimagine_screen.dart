import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../../../../core/utils/storage_service.dart';
import '../controllers/reimagine_controller.dart';

/// Lets the user transform the analyzed room photo with AI for a set of
/// selected parameters. Generation runs in [ReimagineController] (background,
/// survives navigation) and results persist as children of the original photo.
class ReimagineScreen extends ConsumerStatefulWidget {
  final File imageFile;
  final String roomName;
  final String analysisId;

  const ReimagineScreen({
    super.key,
    required this.imageFile,
    required this.roomName,
    required this.analysisId,
  });

  @override
  ConsumerState<ReimagineScreen> createState() => _ReimagineScreenState();
}

class _ReimagineScreenState extends ConsumerState<ReimagineScreen> {
  static const int maxSelection = 3;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    // Restore any previously persisted images for this analysis on open.
    () async {
      final disk =
          await StorageService().getReimaginedImages(widget.analysisId);
      if (mounted) {
        ref.read(reimagineProvider.notifier).ensureSession(
              widget.analysisId,
              diskImages: disk,
            );
      }
    }();
    ref.read(reimagineProvider.notifier).ensureSession(widget.analysisId);
  }

  ReimagineSession? _session(ReimagineGlobalState st) =>
      st.sessions[widget.analysisId];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reimagineProvider);
    final session = _session(state);
    final running = session?.running ?? false;
    final theme = Theme.of(context);

    final doneCount =
        session?.items.values.where((i) => i.status == ReimagineStatus.done).length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Reimagine "${widget.roomName}"',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              widget.imageFile,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),
          Text('How would you like to see this room?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            running
                ? 'Generating in the background — you can leave and come back.'
                : 'Pick up to $maxSelection styles. Each gets a realistic "after" version of your room.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final style in reimagineStyles)
                FilterChip(
                  label: Text(style.label),
                  selected:
                      _selected.contains(style.id) || _isDone(session, style.id),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      if (_selected.length >= maxSelection) return;
                      _selected.add(style.id);
                    } else {
                      _selected.remove(style.id);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed:
                (_selected.isEmpty || running) ? null : () => _run(session),
            child: Text(running
                ? 'Generating… (${_elapsedLabel(session)})'
                : 'Generate ${_selected.length} image${_selected.length == 1 ? '' : 's'}'),
          ),
          if (running) ...[
            const SizedBox(height: 8),
            Text(
              _elapsedLabel(session),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'One at a time, ~30–60s per style. Results stay saved for this room.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
          const SizedBox(height: 20),
          if (doneCount > 0 && !running)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Your saved "after" images',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          for (final style in reimagineStyles)
            if (session?.items[style.id]?.status == ReimagineStatus.done ||
                session?.items[style.id]?.status == ReimagineStatus.generating ||
                session?.items[style.id]?.status == ReimagineStatus.error)
              _buildCard(context, theme, session!, style),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  bool _isDone(ReimagineSession? session, String styleId) =>
      session?.items[styleId]?.status == ReimagineStatus.done;

  String _elapsedLabel(ReimagineSession? session) {
    final total = session?.elapsedSeconds ?? 0;
    final m = total ~/ 60;
    final s = total % 60;
    return m == 0 ? 'Elapsed ${s}s' : 'Elapsed ${m}m ${s}s';
  }

  void _run(ReimagineSession? session) {
    final styles =
        reimagineStyles.where((s) => _selected.contains(s.id)).toList();
    ref.read(reimagineProvider.notifier).generate(
          analysisId: widget.analysisId,
          imageFile: widget.imageFile,
          roomName: widget.roomName,
          styles: styles,
        );
  }

  void _regenerateOne(ReimagineStyle style) {
    ref.read(reimagineProvider.notifier).generate(
          analysisId: widget.analysisId,
          imageFile: widget.imageFile,
          roomName: widget.roomName,
          styles: [style],
        );
  }

  Future<void> _shareImage(String path) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        title: 'SpaceSense AI — Reimagined room',
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    ThemeData theme,
    ReimagineSession session,
    ReimagineStyle style,
  ) {
    final item = session.items[style.id]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: item.status == ReimagineStatus.done &&
                      item.imagePath != null
                  ? Image.file(
                      File(item.imagePath!),
                      fit: BoxFit.cover,
                    )
                  : item.status == ReimagineStatus.generating
                      ? Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              Text('Generating "${style.label}"…',
                                  style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        )
                      : Container(
                          color: Colors.black12,
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          child: Text(
                            item.error ?? 'Not generated yet',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.error),
                          ),
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(style.label,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (item.status == ReimagineStatus.done &&
                    item.imagePath != null)
                  IconButton(
                    tooltip: 'Share',
                    onPressed: () => _shareImage(item.imagePath!),
                    icon: const Icon(Icons.ios_share),
                  ),
                if (item.status != ReimagineStatus.generating &&
                    (!_busy(session)))
                  IconButton(
                    tooltip: 'Regenerate',
                    onPressed: () => _regenerateOne(style),
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _busy(ReimagineSession session) => session.running;
}

