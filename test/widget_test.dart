import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pushup_counter/providers/workout_manager.dart';
import 'package:pushup_counter/screens/selection_screen.dart';

void main() {
  group('SelectionScreen', () {
    testWidgets('displays workout setup title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => WorkoutManager(),
          child: const MaterialApp(
            home: SelectionScreen(),
          ),
        ),
      );

      expect(find.text('Workout Setup'), findsOneWidget);
    });

    testWidgets('displays exercise selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => WorkoutManager(),
          child: const MaterialApp(
            home: SelectionScreen(),
          ),
        ),
      );

      expect(find.text('Exercise'), findsOneWidget);
      expect(find.text('Pushups'), findsOneWidget);
      expect(find.text('Burpees'), findsOneWidget);
    });

    testWidgets('displays mode selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => WorkoutManager(),
          child: const MaterialApp(
            home: SelectionScreen(),
          ),
        ),
      );

      expect(find.text('Mode'), findsOneWidget);
      expect(find.text('Timer'), findsOneWidget);
      expect(find.text('Rep Goal'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
    });

    testWidgets('displays start button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => WorkoutManager(),
          child: const MaterialApp(
            home: SelectionScreen(),
          ),
        ),
      );

      expect(find.text('Start Workout'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows target value selector when timer mode selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => WorkoutManager(),
          child: const MaterialApp(
            home: SelectionScreen(),
          ),
        ),
      );

      // Select Timer mode
      await tester.tap(find.text('Timer'));
      await tester.pumpAndSettle();

      // Should show duration selector
      expect(find.text('Duration (seconds)'), findsOneWidget);
    });

    testWidgets('shows target value selector when rep goal mode selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => WorkoutManager(),
          child: const MaterialApp(
            home: SelectionScreen(),
          ),
        ),
      );

      // Select Rep Goal mode
      await tester.tap(find.text('Rep Goal'));
      await tester.pumpAndSettle();

      // Should show reps selector
      expect(find.text('Target Reps'), findsOneWidget);
    });

    testWidgets('hides target value selector in free mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => WorkoutManager(),
          child: const MaterialApp(
            home: SelectionScreen(),
          ),
        ),
      );

      // Free mode is default, should not show target selectors
      expect(find.text('Duration (seconds)'), findsNothing);
      expect(find.text('Target Reps'), findsNothing);
    });
  });
}
