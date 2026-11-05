import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:spacesense/main.dart';

// Supabase must be initialized before SpaceSenseApp builds, same as main().
Future<void> _initSupabase() async {
  await Supabase.initialize(
    url: 'https://test.supabase.co',
    anonKey: 'test-anon-key',
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Supabase internally reads persisted settings via shared_preferences,
    // which has no plugin implementation in the test environment.
    SharedPreferences.setMockInitialValues({});
    await _initSupabase();
  });

  testWidgets('App boots and renders a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpaceSenseApp()));
    await tester.pump(); // let the auth stream emit once

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
