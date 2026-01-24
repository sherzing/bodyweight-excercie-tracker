import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushup_counter/models/invalid_rep_reason.dart';
import 'package:pushup_counter/widgets/invalid_rep_feedback.dart';

void main() {
  group('InvalidRepFeedback', () {
    testWidgets('initially shows nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InvalidRepFeedback(),
          ),
        ),
      );

      // Should not find any text from the reasons
      expect(find.text('Keep body straight'), findsNothing);
      expect(find.text('Go lower'), findsNothing);
      expect(find.text('Extend arms fully'), findsNothing);
      expect(find.text('Slow down'), findsNothing);
    });

    testWidgets('shows poorForm message when triggered', (tester) async {
      final key = GlobalKey<InvalidRepFeedbackState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvalidRepFeedback(key: key),
          ),
        ),
      );

      // Trigger the feedback
      key.currentState!.show(InvalidRepReason.poorForm);
      await tester.pump();

      expect(find.text('Keep body straight'), findsOneWidget);
    });

    testWidgets('shows partialRangeDown message when triggered', (tester) async {
      final key = GlobalKey<InvalidRepFeedbackState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvalidRepFeedback(key: key),
          ),
        ),
      );

      key.currentState!.show(InvalidRepReason.partialRangeDown);
      await tester.pump();

      expect(find.text('Go lower'), findsOneWidget);
    });

    testWidgets('shows partialRangeUp message when triggered', (tester) async {
      final key = GlobalKey<InvalidRepFeedbackState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvalidRepFeedback(key: key),
          ),
        ),
      );

      key.currentState!.show(InvalidRepReason.partialRangeUp);
      await tester.pump();

      expect(find.text('Extend arms fully'), findsOneWidget);
    });

    testWidgets('shows tooFast message when triggered', (tester) async {
      final key = GlobalKey<InvalidRepFeedbackState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvalidRepFeedback(key: key),
          ),
        ),
      );

      key.currentState!.show(InvalidRepReason.tooFast);
      await tester.pump();

      expect(find.text('Slow down'), findsOneWidget);
    });

    testWidgets('shows poseLost message when triggered', (tester) async {
      final key = GlobalKey<InvalidRepFeedbackState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvalidRepFeedback(key: key),
          ),
        ),
      );

      key.currentState!.show(InvalidRepReason.poseLost);
      await tester.pump();

      expect(find.text('Stay in frame'), findsOneWidget);
    });

    testWidgets('showFromInfo works with InvalidRepInfo', (tester) async {
      final key = GlobalKey<InvalidRepFeedbackState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvalidRepFeedback(key: key),
          ),
        ),
      );

      final info = InvalidRepInfo(
        reason: InvalidRepReason.poorForm,
        timestamp: DateTime.now(),
        repIndex: 0,
      );

      key.currentState!.showFromInfo(info);
      await tester.pump();

      expect(find.text('Keep body straight'), findsOneWidget);
    });

    testWidgets('message disappears after animation completes', (tester) async {
      final key = GlobalKey<InvalidRepFeedbackState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvalidRepFeedback(key: key),
          ),
        ),
      );

      key.currentState!.show(InvalidRepReason.poorForm);
      await tester.pump();

      expect(find.text('Keep body straight'), findsOneWidget);

      // Wait for animation to complete (1500ms + buffer)
      await tester.pumpAndSettle(const Duration(milliseconds: 2000));

      expect(find.text('Keep body straight'), findsNothing);
    });

    testWidgets('new message replaces previous message', (tester) async {
      final key = GlobalKey<InvalidRepFeedbackState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvalidRepFeedback(key: key),
          ),
        ),
      );

      key.currentState!.show(InvalidRepReason.poorForm);
      await tester.pump();
      expect(find.text('Keep body straight'), findsOneWidget);

      // Show new message
      key.currentState!.show(InvalidRepReason.partialRangeDown);
      await tester.pump();

      expect(find.text('Go lower'), findsOneWidget);
      expect(find.text('Keep body straight'), findsNothing);
    });
  });
}
