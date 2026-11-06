import '../../shared/models/analysis_model.dart';

/// A bundled, hand-crafted analysis used for the "See a sample report"
/// entry point. Lets a brand-new user explore the full results experience
/// — scores, recommendations and product suggestions — before setting up
/// an API key or taking any photo. Never persisted, never charged.
class SampleAnalysis {
  static AnalysisModel build() => AnalysisModel.fromJson(const {
        'id': 'sample_living_room',
        'room_id': 'sample_living_room',
        'room_name': 'Living Room (Sample)',
        'room_type': 'living_room',
        'room_type_confidence': 1.0,
        'analyzed_at': '2025-01-01T12:00:00.000Z',
        'scores': {
          'overall': 48,
          'clutter': 35,
          'design': 62,
          'functionality': 48,
          'storage': 30,
          'lighting': 64,
        },
        'detected_objects': [
          'sofa',
          'coffee table',
          'TV unit',
          'floor cushions',
          'stacked boxes',
          'floor lamp',
          'empty wall',
        ],
        'recommendations': [
          {
            'category': 'storage',
            'title': 'Mount a floating shelf above the TV unit',
            'description':
                'The wall above your TV unit is completely empty while loose '
                'items pile up around it. A single floating shelf absorbs '
                'books, plants and media accessories without touching the '
                'floor.',
            'budget_tier': 'free',
            'reasoning':
                'Uses zero floor space, and leads the storage fixes for '
                'impact relative to effort in this layout.',
            'difficulty': 'easy',
            'estimated_cost': '\$0-\$10',
            'impact': 14,
            'priority': 1,
          },
          {
            'category': 'clutter',
            'title': 'Clear the floor-cushion and box pile-up',
            'description':
                'Two stacks of boxes and misused floor cushions break the '
                'walkway between the sofa and coffee table. Moving them into '
                'the shelf or another room restores circulation.',
            'budget_tier': 'free',
            'reasoning':
                'Pure removal — no purchases needed, and clutter is this '
                "room's weakest dimension (35/100).",
            'difficulty': 'easy',
            'estimated_cost': '\$0',
            'impact': 12,
            'priority': 2,
          },
          {
            'category': 'lighting',
            'title': 'Add a warm accent light on the empty-wall side',
            'description':
                'One ceiling light is flattening the room. A warm floor or '
                'wall lamp on the far side adds depth for evening use.',
            'budget_tier': 'low',
            'reasoning':
                'Lighting is easy to improve and lifts both evenings and '
                'photos of the room.',
            'difficulty': 'easy',
            'estimated_cost': '\$15-\$25',
            'impact': 9,
            'priority': 3,
          },
          {
            'category': 'functionality',
            'title': 'Give the coffee table breathing room (keep 45 cm)',
            'description':
                'The table sits closer than ~45 cm to the sofa, which makes '
                'sitting and passing uncomfortable. Pulling it out is free '
                'and instantly better.',
            'budget_tier': 'free',
            'reasoning':
                'Zero-cost spacing fix with immediate comfort payoff.',
            'difficulty': 'easy',
            'estimated_cost': '\$0',
            'impact': 7,
            'priority': 4,
          },
          {
            'category': 'design',
            'title': 'Anchor the seating with a flat-weave rug',
            'description':
                'The sofa floats in the middle of bare flooring. A '
                'flat-weave rug sized to the seating area visually anchors '
                'the setup and hides floor wear.',
            'budget_tier': 'medium',
            'reasoning':
                'Highest single design boost, reserved for after the free '
                'fixes are done.',
            'difficulty': 'medium',
            'estimated_cost': '\$35-\$60',
            'impact': 10,
            'priority': 5,
          },
        ],
        'suggested_products': [
          {
            'name': 'floating wall shelf',
            'search_query': 'floating wall shelf 90cm wood',
            'action': 'add',
            'reason':
                'Fills the empty TV wall and swallows the items currently '
                'stacked on the floor.',
            'estimated_price': '\$8-\$20',
            'category': 'storage',
            'budget_tier': 'free',
          },
          {
            'name': 'storage bench with lift-top',
            'search_query': 'storage bench cushioned 100cm',
            'action': 'add',
            'reason':
                'Doubles as seating and hides the box pile-up permanently.',
            'estimated_price': '\$30-\$55',
            'category': 'storage',
            'budget_tier': 'medium',
          },
          {
            'name': 'warm dimmable floor lamp',
            'search_query': 'warm dimmable LED floor lamp minimal',
            'action': 'add',
            'reason': 'Brings layered evening light to the flat-lit far side.',
            'estimated_price': '\$15-\$25',
            'category': 'lighting',
            'budget_tier': 'low',
          },
          {
            'name': 'flat-weave area rug',
            'search_query': 'flat weave area rug 160x230 beige',
            'action': 'add',
            'reason': 'Anchors the seating zone on bare flooring.',
            'estimated_price': '\$35-\$60',
            'category': 'decor',
            'budget_tier': 'medium',
          },
          {
            'name': 'unused floor cushions',
            'search_query': 'cushion storage backrest',
            'action': 'remove',
            'reason':
                'Cluttering the walkway — relocate to a backrest or storage.',
            'estimated_price': '\$0',
            'category': 'clutter',
            'budget_tier': 'free',
          },
        ],
        'processing_time_ms': 0,
        'ai_provider': 'SpaceSense',
        'ai_model': 'Sample report',
      });
}
