import 'dart:io';

import 'package:expense_splitter_app/app.dart';
import 'package:expense_splitter_app/data/hive/hive_boxes.dart';
import 'package:expense_splitter_app/models/group.dart';
import 'package:expense_splitter_app/models/participant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

// Note: real Hive disk writes triggered *inside* a testWidgets body (e.g. by
// tapping a button whose handler awaits a box.put()) never resolve under
// Flutter's AutomatedTestWidgetsFlutterBinding — a known zone/timer
// interaction, confirmed by isolating it down to a plain `dart:io` write
// hanging the same way. Writes made in setUp()/tearDown() are unaffected,
// so tests here seed data in setUp and only read inside the test body. The
// full create/edit/delete-through-the-UI flow is verified live via
// `flutter run` instead.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('expense_splitter_widget_test');
    await HiveBoxes.initForTest(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('shows the empty state with no groups', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ExpenseSplitterApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expense Splitter'), findsOneWidget);
    expect(find.text('No groups yet'), findsOneWidget);
  });

  testWidgets('renders a seeded group and navigates to its dashboard', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 1, 1);
    await HiveBoxes.groupsBox.put(
      'g1',
      Group(id: 'g1', name: 'Weekend Trip', createdAt: now, updatedAt: now),
    );
    await HiveBoxes.participantsBox.put(
      'p1',
      const Participant(id: 'p1', groupId: 'g1', name: 'KTA'),
    );

    await tester.pumpWidget(
      const ProviderScope(child: ExpenseSplitterApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekend Trip'), findsOneWidget);
    expect(find.text('1 participant · 0 expenses'), findsOneWidget);

    await tester.tap(find.text('Weekend Trip'));
    await tester.pumpAndSettle();

    // Dashboard app bar title and the seeded participant's balance tile.
    expect(find.text('Weekend Trip'), findsOneWidget);
    expect(find.text('KTA'), findsOneWidget);
    expect(find.text('Settled'), findsOneWidget);
  });
}
