import 'package:flutter/material.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/models/analysis_model.dart';
import 'reimagine_screen.dart';

/// Gradient CTA card that opens the Reimagine screen (AI "after" previews).
class _ReimagineCard extends StatelessWidget {
  final AnalysisModel analysis;

  const _ReimagineCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageFile = analysis.imagePath != null
        ? File(analysis.imagePath!)
        : null;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (imageFile != null && imageFile.existsSync())
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReimagineScreen(
                        imageFile: imageFile,
                        roomName: analysis.roomName,
                        analysisId: analysis.id,
                      ),
                    ),
                  );
                }
              : null,
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.all(18.0),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reimagine this room',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          )),
                      SizedBox(height: 4),
                      Text(
                        'See "after" previews — decluttered, brighter, minimal',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResultsScreen extends StatelessWidget {  final AnalysisModel analysis;

  const ResultsScreen({super.key, required this.analysis});

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Needs work';
    return 'Poor';
  }

  void _shareSummary(BuildContext context) {
    final recs = [...analysis.recommendations]
      ..sort((a, b) => b.impact.compareTo(a.impact));
    final topRecs = recs
        .take(3)
        .map((r) => '• ${r.title} (Impact ${r.impact}/100)')
        .join('\n');
    final s = analysis.scores;

    final text = '🏠 ${analysis.roomName} — SpaceSense AI\n\n'
        'Overall score: ${s.overall}/100\n'
        'Clutter ${s.clutter} • Design ${s.design} • Functionality ${s.functionality}\n'
        'Storage ${s.storage} • Lighting ${s.lighting}\n\n'
        'Top improvements:\n$topRecs\n\n'
        'Get room insights with SpaceSense AI!';

    SharePlus.instance.share(
      ShareParams(text: text, title: 'SpaceSense AI — ${analysis.roomName}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                analysis.roomName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
              background: analysis.imagePath != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(analysis.imagePath!),
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: Colors.grey[800]),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: 'Share summary',
                onPressed: () => _shareSummary(context),
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room type badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${analysis.roomType.replaceAll('_', ' ').toUpperCase()} • ${(analysis.roomTypeConfidence * 100).toInt()}% confidence',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reimagine CTA — AI "after" previews of this room
                  _ReimagineCard(analysis: analysis),
                  const SizedBox(height: 24),

                  // Overall score
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getScoreColor(analysis.scores.overall),
                              width: 8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _getScoreColor(analysis.scores.overall)
                                    .withOpacity(0.25),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${analysis.scores.overall}',
                                  style: TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _getScoreColor(analysis.scores.overall),
                                  ),
                                ),
                                Text(
                                  _getScoreLabel(analysis.scores.overall),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        _getScoreColor(analysis.scores.overall),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Overall Score',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[500]),
                        ),

                        // Progress vs the previous scan of this room
                        if (analysis.scoreDelta != null &&
                            analysis.scoreDelta != 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (analysis.scoreDelta! > 0
                                      ? Colors.green
                                      : Colors.red)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (analysis.scoreDelta! > 0
                                        ? Colors.green
                                        : Colors.red)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  analysis.scoreDelta! > 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 16,
                                  color: analysis.scoreDelta! > 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${analysis.scoreDelta! > 0 ? '+' : ''}${analysis.scoreDelta} pts vs last scan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: analysis.scoreDelta! > 0
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Score breakdown
                  Text(
                    'Score Breakdown',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ...analysis.scores.allScores.skip(1).map((score) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                score.key,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${score.value}/100',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _getScoreColor(score.value),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: score.value / 100,
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                            color: _getScoreColor(score.value),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 32),

                  // Detected objects
                  if (analysis.detectedObjects.isNotEmpty) ...[
                    Text(
                      'Detected Objects',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: analysis.detectedObjects.map((object) {
                        return Chip(
                          label: Text(object),
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Suggested products (tap to browse in a webshop)
                  if (analysis.suggestedProducts.isNotEmpty) ...[
                    Text(
                      'Suggested Products',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a card to browse it in a webshop',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ...analysis.suggestedProducts.map((product) {
                      return _ProductCard(product: product);
                    }),
                    const SizedBox(height: 32),
                  ],

                  // Recommendations — interactive action plan with a
                  // projected score gain for completing the checked steps.
                  _RecommendationsPlan(analysis: analysis),
                  const SizedBox(height: 16),

                  // Analysis metadata
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildMetadataRow(
                          context,
                          'AI Model',
                          '${analysis.aiProvider} / ${analysis.aiModel}',
                        ),
                        const SizedBox(height: 8),
                        _buildMetadataRow(
                          context,
                          'Processing Time',
                          '${(analysis.processingTimeMs / 1000).toStringAsFixed(1)}s',
                        ),
                        const SizedBox(height: 8),
                        _buildMetadataRow(
                          context,
                          'Analyzed',
                          _formatDateTime(analysis.analyzedAt),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ProductCard extends StatelessWidget {
  final ProductSuggestionModel product;
  const _ProductCard({required this.product});

  IconData get _categoryIcon {
    switch (product.category) {
      case 'storage':
        return Icons.inventory_2_outlined;
      case 'furniture':
        return Icons.chair_outlined;
      case 'decor':
        return Icons.developer_board;
      case 'lighting':
        return Icons.lightbulb_outline;
      case 'organization':
        return Icons.grid_view_outlined;
      case 'appliance':
        return Icons.kitchen_outlined;
      default:
        return Icons.shopping_bag_outlined;
    }
  }

  /// Live webshop search links built from the AI's generic search terms.
  Uri get _googleShoppingUri => Uri.parse(
      'https://www.google.com/search?tbm=shop&q=${Uri.encodeComponent(product.searchQuery)}');
  Uri get _amazonUri => Uri.parse(
      'https://www.amazon.com/s?k=${Uri.encodeComponent(product.searchQuery)}');

  Future<void> _openStore(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the browser')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the browser')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRemove = product.isRemove;
    final actionColor = isRemove ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openStore(context, _googleShoppingUri),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (isRemove
                              ? const Color(0xFFF59E0B)
                              : theme.colorScheme.primary)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_categoryIcon, color: isRemove
                        ? const Color(0xFFF59E0B)
                        : theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      product.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  // ADD / REPLACE action chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: actionColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRemove ? Icons.swap_horiz : Icons.add,
                          size: 14,
                          color: actionColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isRemove ? 'Replace' : 'Add',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: actionColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                product.reason,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 14, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          product.estimatedPrice,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Store links
                  OutlinedButton.icon(
                    onPressed: () => _openStore(context, _googleShoppingUri),
                    icon: const Icon(Icons.storefront_outlined, size: 16),
                    label: const Text('Google', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openStore(context, _amazonUri),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                    label: const Text('Amazon', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The recommendations section as an interactive action plan. Each step has
/// a checkbox; checked steps roll up into a projected overall-score gain
/// (sum of their AI impact scores). Checked state persists per analysis so
/// returning to a report keeps the plan.
class _RecommendationsPlan extends StatefulWidget {
  final AnalysisModel analysis;

  const _RecommendationsPlan({required this.analysis});

  @override
  State<_RecommendationsPlan> createState() => _RecommendationsPlanState();
}

class _RecommendationsPlanState extends State<_RecommendationsPlan> {
  /// Step indices are stored against the impact-sorted list so ranks stay
  /// stable as the plan is checked off.
  Set<int> _done = {};

  List<RecommendationModel> get _sorted {
    final recs = [...widget.analysis.recommendations];
    recs.sort((a, b) => b.impact.compareTo(a.impact));
    return recs;
  }

  int get _projectedGain {
    final recs = _sorted;
    var sum = 0;
    for (final i in _done) {
      if (i >= 0 && i < recs.length) sum += recs[i].impact;
    }
    return sum;
  }

  String get _prefsKey => 'plan_done_${widget.analysis.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? const <String>[];
    if (mounted) {
      setState(() => _done = saved.map((s) => int.tryParse(s) ?? -1).toSet()..remove(-1));
    }
  }

  Future<void> _toggle(int index) async {
    setState(() {
      if (_done.contains(index)) {
        _done.remove(index);
      } else {
        _done.add(index);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _done.map((i) => '$i').toList());
  }

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  /// Gold / silver / bronze for the top 3, neutral grey after that.
  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFF59E0B); // amber (gold)
      case 2:
        return const Color(0xFF94A3B8); // slate (silver)
      case 3:
        return const Color(0xFFB45309); // bronze
      default:
        return const Color(0xFF64748B); // neutral slate
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'layout':
        return const Color(0xFF6366F1);
      case 'organization':
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  String _budgetIcon(String tier) {
    switch (tier) {
      case 'free':
        return '💡';
      case 'low':
        return '💵';
      case 'medium':
        return '💰';
      case 'premium':
        return '💎';
      default:
        return '💡';
    }
  }

  @override
  Widget build(BuildContext context) {
    final recs = _sorted;
    final theme = Theme.of(context);
    final doneCount = recs.asMap().keys.where(_done.contains).length;
    final allDone = recs.isNotEmpty && doneCount == recs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Action plan',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (recs.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$doneCount/${recs.length} done',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          allDone
              ? 'All steps done — run a rescan to see your real new score! 🎉'
              : 'Tick steps as you complete them — projected gain: '
                  '+$_projectedGain pts',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 16),
        ...recs.asMap().entries.map((entry) {
          final index = entry.key;
          final rec = entry.value;
          final isDone = _done.contains(index);
          final rank = index + 1;
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () => _toggle(index),
              borderRadius: BorderRadius.circular(12),
              child: Opacity(
                opacity: isDone ? 0.65 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: isDone,
                            onChanged: (_) => _toggle(index),
                          ),
                          const SizedBox(width: 4),
                          _buildRankBadge(context, rank),
                          const SizedBox(width: 12),
                          Text(
                            _budgetIcon(rec.budgetTier),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rec.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _categoryColor(rec.category)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              rec.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _categoryColor(rec.category),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(rec.description,
                          style: theme.textTheme.bodyMedium),
                      if (rec.reasoning.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          rec.reasoning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildImpactChip(context, rec.impact),
                          _buildMiniChip(
                            context,
                            icon: Icons.payments_outlined,
                            label: rec.estimatedCost,
                          ),
                          _buildMiniChip(
                            context,
                            icon: Icons.fitness_center_outlined,
                            label: rec.difficulty,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRankBadge(BuildContext context, int rank) {
    final color = _rankColor(rank);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildImpactChip(BuildContext context, int impact) {
    final color = _scoreColor(impact);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'Impact $impact/100',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(BuildContext context,
      {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
