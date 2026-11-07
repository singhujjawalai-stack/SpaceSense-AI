import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/ai_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/usage_tracker.dart';
import '../../../settings/data/api_key_service.dart';

/// The available reimagine styles (shared by the controller and the screen).
class ReimagineStyle {
  final String id;
  final String label;
  final String transformation;
  const ReimagineStyle(this.id, this.label, this.transformation);
}

const List<ReimagineStyle> reimagineStyles = [
  ReimagineStyle(
      'decluttered',
      'Decluttered',
      'Remove all visible clutter, organize items neatly, tidy every surface '
          'so the space looks clean and organized.'),
  ReimagineStyle(
      'brighter',
      'Brighter',
      'Make the room significantly brighter with realistic natural and layered '
          'lighting, brightening every corner.'),
  ReimagineStyle(
      'minimalist',
      'Minimalist',
      'Apply a clean minimalist redesign with empty open space, simple neutral '
          'palette and clean surfaces.'),
  ReimagineStyle(
      'more_storage',
      'More storage',
      'Add subtle, functional storage in the same room, e.g. elegant shelves, '
          'baskets, organizers.'),
  ReimagineStyle(
      'modern',
      'Modern refresh',
      'Give the room a modern, refreshed style with tasteful contemporary '
          'furniture and colors.'),
];

enum ReimagineStatus { pending, generating, done, error }

class ReimagineItem {
  final String styleId;
  final ReimagineStatus status;
  /// Path of the saved image on disk (child of the analysis' original photo).
  final String? imagePath;
  final String? error;

  const ReimagineItem({
    required this.styleId,
    this.status = ReimagineStatus.pending,
    this.imagePath,
    this.error,
  });

  ReimagineItem copyWith({
    ReimagineStatus? status,
    String? imagePath,
    String? error,
  }) =>
      ReimagineItem(
        styleId: styleId,
        status: status ?? this.status,
        imagePath: imagePath ?? this.imagePath,
        error: error,
      );
}

class ReimagineSession {
  final String analysisId;
  final bool running;
  final int elapsedSeconds;
  final Map<String, ReimagineItem> items;

  const ReimagineSession({
    required this.analysisId,
    required this.running,
    required this.elapsedSeconds,
    required this.items,
  });
}

class ReimagineGlobalState {
  final Map<String, ReimagineSession> sessions;
  const ReimagineGlobalState({this.sessions = const {}});
}

/// Runs reimagine generations OUTSIDE the widget tree so navigation away
/// never cancels work, and results persist as children of the original photo.
class ReimagineController extends StateNotifier<ReimagineGlobalState> {
  final Ref _ref;
  final Map<String, Timer?> _timers = {};
  final Map<String, bool> _busy = {};

  ReimagineController(this._ref) : super(const ReimagineGlobalState());

  /// Creates (or restores) the session for an analysis. [diskImages] maps
  /// persisted style indices to file paths; index == position in
  /// [reimagineStyles].
  void ensureSession(
    String analysisId, {
    Map<int, String> diskImages = const {},
  }) {
    if (state.sessions.containsKey(analysisId)) {
      // Merge any newly persisted disk images into the session view.
      if (diskImages.isNotEmpty &&
          !(state.sessions[analysisId]?.running ?? false)) {
        final existing = state.sessions[analysisId]!;
        final items = {...existing.items};
        diskImages.forEach((index, path) {
          final style = reimagineStyles[index];
          items[style.id] = ReimagineItem(
            styleId: style.id,
            status: ReimagineStatus.done,
            imagePath: path,
          );
        });
        state = _withSession(
          analysisId,
          ReimagineSession(
            analysisId: analysisId,
            running: false,
            elapsedSeconds: 0,
            items: items,
          ),
        );
      }
      return;
    }
    state = _withSession(
      analysisId,
      ReimagineSession(
        analysisId: analysisId,
        running: false,
        elapsedSeconds: 0,
        items: {
          for (final s in reimagineStyles)
            s.id: ReimagineItem(styleId: s.id),
        },
      ),
    );
    // Overlay persisted images on a fresh session.
    if (diskImages.isNotEmpty) {
      final existing = state.sessions[analysisId]!;
      final items = {...existing.items};
      diskImages.forEach((index, path) {
        final style = reimagineStyles[index];
        items[style.id] = ReimagineItem(
          styleId: style.id,
          status: ReimagineStatus.done,
          imagePath: path,
        );
      });
      state = _withSession(
        analysisId,
        ReimagineSession(
          analysisId: analysisId,
          running: false,
          elapsedSeconds: 0,
          items: items,
        ),
      );
    }
  }

  /// Entry point from the screen — the whole pipeline runs in the background.
  Future<void> generate({
    required String analysisId,
    required File imageFile,
    required String roomName,
    required List<ReimagineStyle> styles,
  }) async {
    if (styles.isEmpty) return;
    if (_busy[analysisId] == true) return;
    _busy[analysisId] = true;

    // Reset selected items to generating.
    final base = state.sessions[analysisId] ??
        const ReimagineSession(
          analysisId: '',
          running: false,
          elapsedSeconds: 0,
          items: {},
        );
    final items = {...base.items};
    for (final s in styles) {
      items[s.id] = ReimagineItem(styleId: s.id, status: ReimagineStatus.generating);
    }
    state = _withSession(
      analysisId,
      ReimagineSession(
        analysisId: analysisId,
        running: true,
        elapsedSeconds: 0,
        items: items,
      ),
    );

    _startTimer(analysisId);

    try {
      final apiKeyService = _ref.read(apiKeyServiceProvider);
      final apiKey = await apiKeyService.getApiKey();
      if (apiKey == null) {
        _failStyles(
            analysisId, styles, 'No API key configured. Please add your key '
                'in Settings.');
        return;
      }
      final aiService = _ref.read(aiServiceProviderSimple);
      final openRouterKey = await apiKeyService.getOpenRouterKey();
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final storage = StorageService();
      for (final style in styles) {
        try {
          final b64 = await aiService.reimagineRoom(
            imageBase64: base64Image,
            roomName: roomName,
            parameter: style.transformation,
            provider: apiKey.provider,
            apiKey: apiKey.apiKey,
            openRouterKey: openRouterKey,
          );
          // Persist immediately — child of the analysis' original photo.
          String path;
          try {
            path = await storage.saveReimaginedImage(
              base64.decode(b64),
              analysisId,
              reimagineStyles.indexWhere((s) => s.id == style.id),
            );
          } catch (_) {
            path = '';
          }
          _updateItem(
            analysisId,
            style.id,
            ReimagineItem(
              styleId: style.id,
              status: ReimagineStatus.done,
              imagePath: path.isNotEmpty ? path : null,
            ),
          );
          // Meter today's usage for the Settings gauge (only on success).
          await _ref.read(usageTrackerProvider).recordImage();
          _ref.invalidate(usageProvider);
        } on AiException catch (e) {
          _updateItem(
            analysisId,
            style.id,
            ReimagineItem(
              styleId: style.id,
              status: ReimagineStatus.error,
              error: e.message,
            ),
          );
        } catch (e) {
          _updateItem(
            analysisId,
            style.id,
            ReimagineItem(
              styleId: style.id,
              status: ReimagineStatus.error,
              error: e.toString(),
            ),
          );
        }
      }
    } catch (e) {
      _failStyles(analysisId, styles, e.toString());
    } finally {
      _busy[analysisId] = false;
      _stopTimer(analysisId);
    }
  }

  void _failStyles(
      String analysisId, List<ReimagineStyle> styles, String message) {
    for (final s in styles) {
      _updateItem(
        analysisId,
        s.id,
        ReimagineItem(styleId: s.id, status: ReimagineStatus.error, error: message),
      );
    }
  }

  void _updateItem(
      String analysisId, String styleId, ReimagineItem item) {
    final session = state.sessions[analysisId];
    if (session == null) return;
    final items = {...session.items};
    items[styleId] = item;
    state = _withSession(
      analysisId,
      ReimagineSession(
        analysisId: analysisId,
        running: session.running,
        elapsedSeconds: session.elapsedSeconds,
        items: items,
      ),
    );
  }

  void _startTimer(String analysisId) {
    _stopTimer(analysisId);
    _timers[analysisId] = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = state.sessions[analysisId];
      if (session == null || !session.running) return;
      state = _withSession(
        analysisId,
        ReimagineSession(
          analysisId: analysisId,
          running: session.running,
          elapsedSeconds: session.elapsedSeconds + 1,
          items: session.items,
        ),
      );
    });
  }

  void _stopTimer(String analysisId) {
    _timers[analysisId]?.cancel();
    _timers[analysisId] = null;
    final session = state.sessions[analysisId];
    if (session != null && session.running) {
      state = _withSession(
        analysisId,
        ReimagineSession(
          analysisId: analysisId,
          running: false,
          elapsedSeconds: session.elapsedSeconds,
          items: session.items,
        ),
      );
    }
  }

  ReimagineGlobalState _withSession(
      String analysisId, ReimagineSession session) {
    final sessions = {...state.sessions};
    sessions[analysisId] = session;
    return ReimagineGlobalState(sessions: sessions);
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t?.cancel();
    }
    super.dispose();
  }
}

/// Root (non-autoDispose) provider — the generation lives here regardless of
/// which screens are on the navigation stack.
final reimagineProvider =
    StateNotifierProvider<ReimagineController, ReimagineGlobalState>(
        (ref) => ReimagineController(ref));
