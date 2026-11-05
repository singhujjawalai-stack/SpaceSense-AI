import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
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

  static const List<Map<String, dynamic>> _steps = [
    {'icon': Icons.image_outlined, 'label': 'Reading'},
    {'icon': Icons.psychology_outlined, 'label': 'AI Analysis'},
    {'icon': Icons.save_outlined, 'label': 'Saving'},
  ];

  @override
  void initState() {
    super.initState();
    _processImage();
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

      // Update analysis with image path
      final updatedAnalysis = analysis.copyWith(imagePath: imagePath);

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
                    final color = done
                        ? Colors.green
                        : active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          Icon(step['icon'] as IconData, color: color),
                          const SizedBox(height: 6),
                          Text(
                            step['label'] as String,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: color,
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
                    'This usually takes 15–30 seconds',
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
