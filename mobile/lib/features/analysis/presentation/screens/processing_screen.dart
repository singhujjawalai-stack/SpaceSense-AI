import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import '../../../../core/ai/ai_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/models/analysis_model.dart';
import '../../../../shared/models/api_key_model.dart';
import '../../../settings/data/api_key_service.dart';
import 'results_screen.dart';

final aiServiceProvider = Provider((ref) => AiService());

class ProcessingScreen extends ConsumerStatefulWidget {
  final File imageFile;
  final String roomName;
  final List<String> goals;

  const ProcessingScreen({
    super.key,
    required this.imageFile,
    required this.roomName,
    required this.goals,
  });

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  bool _isProcessing = true;
  int _stage = 0; // 0 = reading image, 1 = using AI, 2 = saving results
  String? _errorMessage;
  Timer? _timer;
  int _elapsedSeconds = 0;

  static const List<Map<String, dynamic>> _steps = [
    {'icon': Icons.image_outlined, 'label': 'Reading'},
    {'icon': Icons.psychology_outlined, 'label': 'AI Analysis'},
    {'icon': Icons.save_outlined, 'label': 'Saving'},
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
    _processImage();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isProcessing) {
        setState(() => _elapsedSeconds += 1);
      }
    });
  }

  String get _elapsedLabel {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    if (m == 0) return 'Elapsed ${s}s';
    return 'Elapsed ${m}m ${s}s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _processImage() async {
    try {
      setState(() {
        _stage = 0;
      });

      // Convert image to base64
      final bytes = await widget.imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      setState(() => _stage = 1);

      // Get API key
      final apiKeyService = ref.read(apiKeyServiceProvider);
      final apiKey = await apiKeyService.getApiKey();

      if (apiKey == null) {
        throw AiException(
            'No API key configured. Please add your key in Settings.');
      }

      // Call the AI provider directly (no backend needed)
      final aiService = ref.read(aiServiceProvider);
      final analysisData = await aiService.analyzeRoom(
        imageBase64: base64Image,
        roomName: widget.roomName,
        provider: apiKey.provider,
        model: apiKey.model,
        apiKey: apiKey.apiKey,
        goals: widget.goals,
      );

      // If the auto-fallback used a different model than the one saved in
      // Settings, persist the working model so future scans don't re-guess.
      final usedModel = (analysisData['ai_model'] ?? apiKey.model) as String;
      if (usedModel != apiKey.model) {
        await apiKeyService.saveApiKey(
          ApiKeyModel(
            provider: apiKey.provider,
            model: usedModel,
            apiKey: apiKey.apiKey,
          ),
        );
      }

      setState(() => _stage = 2);

      // Parse response
      final analysis = AnalysisModel.fromJson(analysisData);

      // Save original image
      final storageService = StorageService();
      final roomId = analysis.roomId;
      final imagePath = await storageService.saveOriginalImage(
        widget.imageFile,
        roomId,
      );

      // Save analysis JSON.
      // Progress tracking: before this scan is written, compare its overall
      // score against the latest saved analysis of the same room name. That
      // delta (points vs the last visit) displays as a badge in results and
      // history — turning rescans into visible progress.
      int? scoreDelta;
      try {
        final existing = await storageService.getAllAnalyses();
        final sameName = existing
            .where((a) => ((a['room_name'] ?? '') as String).trim() ==
                widget.roomName.trim());
        final previous = sameName.isNotEmpty ? sameName.first : null;
        if (previous != null && previous['scores'] is Map) {
          final prevOverall =
              (((previous['scores'] as Map)['overall'] ?? 0) as num).toInt();
          scoreDelta = analysis.scores.overall - prevOverall;
        }
      } catch (_) {
        // Progress tracking is best-effort; never block the save.
      }

      final updatedAnalysis = analysis.copyWith(
        imagePath: imagePath,
        scoreDelta: scoreDelta,
      );

      // Save analysis JSON
      await storageService.saveAnalysis(
        updatedAnalysis.toJson(),
        analysis.id,
      );

      setState(() => _isProcessing = false);

      // Navigate to results
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultsScreen(analysis: updatedAnalysis),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Analysis Failed'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_isProcessing)
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      strokeWidth: 3,
                    ),
                  )
                else
                  Icon(
                    Icons.error_outline,
                    size: 96,
                    color: theme.colorScheme.error,
                  ),
                const SizedBox(height: 40),

                // Step tracker
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_steps.length, (i) {
                    final step = _steps[i];
                    final done = _isProcessing && i < _stage;
                    final active = _isProcessing && i == _stage;
                    final label = step['label'] as String;
                    final labelColor = done
                        ? Colors.green
                        : active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: done
                                ? const CircleAvatar(
                                    backgroundColor:
                                        Colors.transparent,
                                    child: Icon(Icons.check_circle,
                                        color: Colors.green),
                                  )
                                : active
                                    ? Center(
                                        child: _TypingDots(
                                          color:
                                              theme.colorScheme.primary,
                                        ),
                                      )
                                    : CircleAvatar(
                                        backgroundColor:
                                            Colors.transparent,
                                        child: Icon(
                                          step['icon'] as IconData,
                                          color: theme
                                              .colorScheme.outlineVariant,
                                        ),
                                      ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: labelColor,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                if (_isProcessing)
                  Text(
                    'Analyzing "${widget.roomName}"',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (_isProcessing) ...[
                  const SizedBox(height: 12),
                  Text(
                    _elapsedLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'This usually takes 30–60 seconds',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (!_isProcessing && _errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three staggered jumping dots (WhatsApp "typing" style) for the active
/// step indicator.
class _TypingDots extends StatefulWidget {
  final Color color;

  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot so the three jump in sequence.
            final p = ((_controller.value - i * 0.18) % 1.0 + 1.0) % 1.0;
            final wave = math.sin(p * math.pi); // 0 -> 1 -> 0, smooth
            final dy = -wave * 4.0;
            final scale = 1.0 - wave * 0.3;
            final opacity = 0.35 + wave * 0.65;
            final color = widget.color.withValues(alpha: opacity);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
