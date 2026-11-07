import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/data/auth_service.dart';
import '../../../settings/data/api_key_service.dart';
import '../../../../core/ai/ai_service.dart';
import '../../../../core/utils/usage_tracker.dart';
import '../../../../shared/models/api_key_model.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _selectedProvider;
  String? _selectedModel;
  final _apiKeyController = TextEditingController();
  final _openRouterController = TextEditingController();
  bool _isLoading = false;
  bool _isTesting = false;

  /// Cleans a pasted key: surrounding whitespace/quotes, copy artifacts
  /// ("key=...", "apiKey=...", "Bearer ...", "API_KEY=") and internal
  /// line breaks. Real API keys never contain spaces, so these are safe.
  static String _sanitizeKey(String raw) {
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


  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _openRouterController.dispose();
    super.dispose();
  }

    String _selectedProviderDisplay(String provider) {
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

  Future<void> _loadApiKey() async {
    final apiKeyService = ref.read(apiKeyServiceProvider);
    final apiKey = await apiKeyService.getApiKey();
    final openRouter = await apiKeyService.getOpenRouterKey();
    if (mounted) {
      setState(() {
        if (apiKey != null) {
          _selectedProvider = apiKey.provider;
          // A previously saved model may have been retired by the provider
          // (e.g. gemini-1.5). Force re-selection instead of a guaranteed 404.
          final models = SupportedProvider.models[apiKey.provider] ?? const [];
          _selectedModel = models.contains(apiKey.model) ? apiKey.model : null;
          _apiKeyController.text = apiKey.apiKey;
        }
        if (openRouter != null) _openRouterController.text = openRouter;
      });
    }
  }

  Future<void> _saveApiKey() async {
    final sanitized = _sanitizeKey(_apiKeyController.text);
    if (_selectedProvider == null || _selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select provider and model')),
      );
      return;
    }

    if (sanitized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your API key')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiKey = ApiKeyModel(
        provider: _selectedProvider!,
        model: _selectedModel!,
        apiKey: sanitized,
      );

      final apiKeyService = ref.read(apiKeyServiceProvider);
      await apiKeyService.saveApiKey(apiKey);

      // Refresh the cached apiKeyProvider so other screens see the new key
      ref.invalidate(apiKeyProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving API key: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Validates the entered key against the AI provider directly.
  Future<void> _testApiKey() async {
    final sanitized = _sanitizeKey(_apiKeyController.text);
    if (_selectedProvider == null || _selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select provider and model')),
      );
      return;
    }
    if (sanitized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your API key')),
      );
      return;
    }

    setState(() => _isTesting = true);
    try {
      final aiService = ref.read(aiServiceProviderSimple);
      final ok = await aiService.validateKey(
        provider: _selectedProvider!,
        model: _selectedModel!,
        apiKey: sanitized,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Connected successfully to ${_selectedProvider!}!'
                : 'Connection failed — check your API key'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _deleteApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete API Key'),
        content: const Text('Are you sure you want to delete your API key?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final apiKeyService = ref.read(apiKeyServiceProvider);
      await apiKeyService.deleteApiKey();
      // Refresh the cached provider so the Home banner reappears.
      ref.invalidate(apiKeyProvider);
      setState(() {
        _selectedProvider = null;
        _selectedModel = null;
        _apiKeyController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key deleted')),
        );
      }
    }
  }

  /// Saves (or disables when empty) the optional OpenRouter image fallback.
  Future<void> _saveOpenRouter() async {
    final text = _sanitizeKey(_openRouterController.text);
    final apiKeyService = ref.read(apiKeyServiceProvider);
    if (text.isEmpty) {
      await apiKeyService.deleteOpenRouterKey();
    } else {
      await apiKeyService.saveOpenRouterKey(text);
    }
    if (!mounted) return;
    setState(() {}); // refresh the Clear button visibility
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            text.isEmpty ? 'OpenRouter fallback disabled' : 'OpenRouter fallback enabled'),
      ),
    );
  }

  Future<void> _clearOpenRouter() async {
    await ref.read(apiKeyServiceProvider).deleteOpenRouterKey();
    if (!mounted) return;
    setState(() => _openRouterController.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fallback disabled')),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Account section
            Text(
              'Account',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(user?.email ?? 'Not logged in'),
              ),
            ),
            const SizedBox(height: 32),

            // Usage gauge — today's counts with a midnight-Pacific reset
            _UsageCard(),
            const SizedBox(height: 32),

            // API Configuration section
            Text(
              'API Configuration',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedProvider,
                      decoration: const InputDecoration(
                        labelText: 'AI Provider',
                        prefixIcon: Icon(Icons.business),
                      ),
                      items: SupportedProvider.all.map((provider) {
                        return DropdownMenuItem(
                          value: provider,
                          child: Text(provider.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProvider = value;
                          _selectedModel = null;
                        });
                      },
                    ),
                    if (_selectedProvider != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Row(
                          children: [
                            Icon(
                              _selectedProvider == SupportedProvider.google
                                  ? Icons.savings_outlined
                                  : Icons.payments_outlined,
                              size: 14,
                              color: _selectedProvider == SupportedProvider.google
                                  ? Colors.green
                                  : Colors.grey[500],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                SupportedProvider.hint(_selectedProvider!)!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _selectedProvider == SupportedProvider.google
                                      ? Colors.green[700]
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_selectedProvider != null)
                      DropdownButtonFormField<String>(
                        value: _selectedModel,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          prefixIcon: Icon(Icons.psychology),
                        ),
                        items: SupportedProvider.models[_selectedProvider]!
                            .map((model) {
                          return DropdownMenuItem(
                            value: model,
                            child: Text(model),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedModel = value);
                        },
                      ),
                    const SizedBox(height: 14),
                    if (_selectedProvider != null &&
                        SupportedProvider.consoleUrl(_selectedProvider!) !=
                            null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => launchUrl(
                            Uri.parse(
                                SupportedProvider.consoleUrl(_selectedProvider!)!),
                            mode: LaunchMode.externalApplication,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.open_in_new,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Create an API key on '
                                  '${_selectedProviderDisplay(_selectedProvider!)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        hintText: 'Enter your API key',
                        prefixIcon: Icon(Icons.vpn_key),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isTesting ? null : _testApiKey,
                            icon: _isTesting
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.wifi_tethering),
                            label: const Text('Test Connection'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveApiKey,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_apiKeyController.text.isNotEmpty)
                          OutlinedButton(
                            onPressed: _deleteApiKey,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Optional OpenRouter image fallback
            Text(
              'Image Fallback (optional)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'When Gemini\'s free image quota runs out, Reimagine can use a '
              'free OpenRouter account instead. Create a free key at '
              'openrouter.ai (no card needed) and paste it here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _openRouterController,
                      decoration: const InputDecoration(
                        labelText: 'OpenRouter API key (optional)',
                        hintText: 'sk-or-...',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveOpenRouter,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save Fallback Key'),
                          ),
                        ),
                        if (_openRouterController.text.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _clearOpenRouter,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Clear'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // App info
            Text(
              'About',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Version'),
                    subtitle: const Text('1.1.0'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // TODO: Open privacy policy
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Sign out button
            OutlinedButton(
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's usage gauge: the honest version of a quota indicator. Providers
/// don't expose remaining quota, so this counts today's paid attention:
/// how many room analyses and images the user has spent, with the reset
/// time called out. Zero network calls — a passive local counter.
class _UsageCard extends ConsumerWidget {
  const _UsageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final usageAsync = ref.watch(usageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Usage",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: usageAsync.maybeWhen(
              data: (usage) => Row(
                children: [
                  Expanded(
                    child: _usageCell(
                      theme,
                      Icons.psychology,
                      '${usage.analyses}',
                      'Room analyses',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: theme.dividerColor,
                  ),
                  Expanded(
                    child: _usageCell(
                      theme,
                      Icons.auto_awesome,
                      '${usage.images}',
                      'Images generated',
                    ),
                  ),
                ],
              ),
              orElse: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Free quotas reset daily, around 1:30 PM IST (midnight Pacific).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _usageCell(
      ThemeData theme, IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
