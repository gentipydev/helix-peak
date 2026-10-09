import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/home/presentation/screens/home_screen.dart';
import 'package:helixpeek/features/home/presentation/widgets/protein_analyses_cta.dart';

void main() {
  testWidgets('with no label, the row says what the walk’s entry always said', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProteinAnalysesCta(onPressed: () {})),
      ),
    );
    expect(ProteinAnalysesCta.defaultLabel, 'Protein Analyses');
    expect(find.text('Protein Analyses'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('a label replaces the words and nothing else', (
    WidgetTester tester,
  ) async {
    int pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProteinAnalysesCta(
            label: 'DNA Replication',
            onPressed: () => pressed++,
          ),
        ),
      ),
    );
    expect(find.text('DNA Replication'), findsOneWidget);
    expect(find.text('Protein Analyses'), findsNothing);
    await tester.tap(find.text('DNA Replication'));
    expect(pressed, 1);
  });

  testWidgets('home offers the walk, then replication, and nothing else', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    expect(find.byType(ProteinAnalysesCta), findsNWidgets(2));
    expect(
      tester.getCenter(find.text('Protein Analyses')).dy,
      lessThan(tester.getCenter(find.text('DNA Replication')).dy),
    );
    expect(find.text('Lab'), findsNothing);
  });
}
