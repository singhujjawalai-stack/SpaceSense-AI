import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/auth_service.dart';
import '../../../camera/presentation/screens/camera_screen.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/data/api_key_service.dart';
import '../../../../shared/models/analysis_model.dart';
import '../../../../shared/models/api_key_model.dart';
import '../../../analysis/presentation/screens/results_screen.dart';
import '../../../../core/utils/sample_analysis.dart';

/// Which bottom-nav tab is active. Exposed as a provider so screens like the
/// Home tab can programmatically jump to another tab (e.g. Settings).
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final index = ref.watch(homeTabIndexProvider);

    return PopScope(
      // Only allow the system back button to exit the app when the user is
      // already on the Home tab. From History/Settings it goes Home instead.
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) {
          ref.read(homeTabIndexProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        body: _screens[index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) =>
              ref.read(homeTabIndexProvider.notifier).state = i,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  static const List<Widget> _screens = [
    HomeTab(),
    HistoryScreen(),
    SettingsScreen(),
  ];
}

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final initial = (user?.email ?? 'S').isNotEmpty
        ? user!.email![0].toUpperCase()
        : 'S';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpaceSense AI'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
              child: Text(
                initial,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back!',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),

              // API key setup banner (only when no key is configured)
              if (ref.watch(apiKeyProvider).value == null) ...[
                _buildApiKeyBanner(context, ref),
                const SizedBox(height: 20),
              ],

              // Quick stats
              const _QuickStats(),
              const SizedBox(height: 24),

              // Primary action — full-width gradient card, centered content
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CameraScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 32, horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Analyze New Room',
                            style:
                                theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Take a photo to get AI-powered insights',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.85),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sample report — lets new users see the full experience
              // before committing to an API key or any photo.
              _buildSampleReportCard(context),
              const SizedBox(height: 36),

              Text(
                'How it works',
                style:
                    theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildStep(
                  context, '1', 'Take a Photo', 'Capture or upload a room image'),
              _buildStep(
                  context, '2', 'AI Analysis', 'Get 6-dimensional scoring and insights'),
              _buildStep(
                  context,
                  '3',
                  'Recommendations',
                  'Receive personalized improvement tips'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyBanner(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showKeyOnboardingSheet(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.vpn_key_outlined, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set up your AI key to start analyzing rooms',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ) ??
                        const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Free tier available — guided setup takes ~2 min',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF6366F1)),
          ],
        ),
      ),
    );
  }

  /// Guided first-run flow: pick a provider, tap through to its key page,
  /// paste the key, done. Replaces the "go find it in Settings" detour.
  void _showKeyOnboardingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _KeyOnboardingSheet(),
    );
  }

  Widget _buildSampleReportCard(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ResultsScreen(analysis: SampleAnalysis.build()),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome_outlined,
                    size: 22, color: theme.colorScheme.secondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'See a sample report',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explore a full analysis — no key or photo needed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
      BuildContext context, String number, String title, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// First-run guided key setup, opened from the home banner. Sequences the
/// exact three taps a new user needs: pick a provider → tap to its key page
/// → paste. Saves via the same ApiKeyService as Settings.
class _KeyOnboardingSheet extends ConsumerStatefulWidget {
  const _KeyOnboardingSheet();

  @override
  ConsumerState<_KeyOnboardingSheet> createState() =>
      _KeyOnboardingSheetState();
}

class _KeyOnboardingSheetState extends ConsumerState<_KeyOnboardingSheet> {
  late String _provider;
  late String _model;
  final _keyController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _provider = SupportedProvider.google;
    _model = SupportedProvider.models[_provider]!.first;
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  /// Same cleanup paste-trimming as Settings (quotes, "key=", whitespace).
  String _sanitizeKey(String raw) {
    var key = raw.trim();
    if (key.length >= 2 &&
        ((key.startsWith('"') && key.endsWith('"')) ||
            (key.startsWith("'") && key.endsWith("'")))) {
      key = key.substring(1, key.length - 1).trim();
    }
    final prefixes = ['key=', 'apiKey=', 'apikey=', 'API_KEY=', 'Bearer '];
    for (final p in prefixes) {
      if (key.toLowerCase().startsWith(p.toLowerCase())) {
        key = key.substring(p.length).trim();
        break;
      }
    }
    return key.replaceAll(RegExp(r'\s+'), '');
  }

  static String _providerTitle(String provider) {
    switch (provider) {
      case SupportedProvider.google:
        return 'Google AI Studio';
      case SupportedProvider.openrouter:
        return 'OpenRouter';
      case SupportedProvider.openai:
        return 'OpenAI';
      case SupportedProvider.anthropic:
        return 'Anthropic';
      default:
        return provider;
    }
  }

  Future<void> _save() async {
    final key = _sanitizeKey(_keyController.text);
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste your API key first')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiKeyServiceProvider).saveApiKey(ApiKeyModel(
            provider: _provider,
            model: _model,
            apiKey: key,
          ));
      // Refresh the cached provider so Home/camera flows see the new key.
      ref.invalidate(apiKeyProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Key saved — you\'re ready to analyze your first room!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save key: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Set up your free AI key',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Three quick steps — no card, no charges.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),

              // Step 1 — provider picker
              Text('1. Choose a provider',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...SupportedProvider.all.map(_buildProviderCard),
              const SizedBox(height: 16),

              // Step 2 — console link
              Text('2. Create your key',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(SupportedProvider.consoleUrl(_provider)!),
                  mode: LaunchMode.externalApplication,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Open ${_providerTitle(_provider)} — create a key '
                          '(free tier)',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Step 3 — paste + save
              Text('3. Paste your key',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _keyController,
                autofocus: true,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'API key',
                  prefixIcon: const Icon(Icons.vpn_key),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_circle),
                    tooltip: 'Save key',
                    onPressed: _saving ? null : _save,
                  ),
                ),
                onSubmitted: (_) => _saving ? null : _save(),
              ),
              const SizedBox(height: 4),
              // Keyed by provider so switching providers recreates the field
              // with that provider's first model as the fresh initial value.
              DropdownButtonFormField<String>(
                key: ValueKey(_provider),
                initialValue: SupportedProvider.models[_provider]!.first,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  prefixIcon: Icon(Icons.psychology),
                ),
                items: SupportedProvider.models[_provider]!
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _model = v);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Saving…' : 'Save & start analyzing'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(homeTabIndexProvider.notifier).state = 2;
                  },
                  child: const Text('Advanced options in Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard(String provider) {
    final theme = Theme.of(context);
    final selected = provider == _provider;
    final freeTier = provider == SupportedProvider.google ||
        provider == SupportedProvider.openrouter;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() {
          _provider = provider;
          _model = SupportedProvider.models[provider]!.first;
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color:
                    selected ? theme.colorScheme.primary : theme.hintColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _providerTitle(provider),
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (freeTier) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'FREE TIER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      SupportedProvider.hint(provider) ?? '',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick stats strip: total scans, average score, best room.
/// Loads directly from local storage so it refreshes whenever the tab reopens.
class _QuickStats extends ConsumerStatefulWidget {
  const _QuickStats();

  @override
  ConsumerState<_QuickStats> createState() => _QuickStatsState();
}

class _QuickStatsState extends ConsumerState<_QuickStats> {
  List<AnalysisModel>? _analyses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = ref.read(storageServiceProvider);
    final jsons = await storage.getAllAnalyses();
    if (!mounted) return;
    setState(() {
      _analyses = jsons.map((j) => AnalysisModel.fromJson(j)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_analyses == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_analyses!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.insights_outlined,
                color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No scans yet — your stats will appear here',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          ],
        ),
      );
    }

    final count = _analyses!.length;
    final avg = _analyses!
            .map((a) => a.scores.overall)
            .reduce((a, b) => a + b) /
        count;
    final best = _analyses!.reduce(
        (a, b) => a.scores.overall >= b.scores.overall ? a : b);

    return Row(
      children: [
        Expanded(
            child: _statCard(theme, Icons.photo_camera_outlined,
                count.toString(), 'Scans', null)),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard(theme, Icons.grade_outlined, avg.round().toString(),
                'Avg score', _scoreColor(avg.round()))),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard(theme, Icons.emoji_events_outlined,
                best.scores.overall.toString(), best.roomName, _scoreColor(best.scores.overall))),
      ],
    );
  }

  Widget _statCard(
      ThemeData theme, IconData icon, String value, String label, Color? color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: color ?? theme.colorScheme.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}
