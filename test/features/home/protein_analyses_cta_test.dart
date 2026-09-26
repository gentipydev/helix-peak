import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/home/presentation/screens/home_screen.dart';
import 'package:helixpeek/features/home/presentation/widgets/protein_analyses_cta.dart';

void main() {
  tearDown(dotenv.clean);

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
          body: ProteinAnalysesCta(label: 'Lab', onPressed: () => pressed++),
        ),
      ),
    );
    expect(find.text('Lab'), findsOneWidget);
    expect(find.text('Protein Analyses'), findsNothing);
    await tester.tap(find.text('Lab'));
    expect(pressed, 1);
  });

  testWidgets('home offers one entry in a build without the lab', (
    WidgetTester tester,
  ) async {
    dotenv.clean();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    expect(find.byType(ProteinAnalysesCta), findsOneWidget);
    expect(find.text('Protein Analyses'), findsOneWidget);
    expect(find.text('Lab'), findsNothing);
  });

  testWidgets('home offers the lab beside it in a build that carries it', (
    WidgetTester tester,
  ) async {
    dotenv.loadFromString(envString: 'LAB_ENABLED=true');
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    expect(find.byType(ProteinAnalysesCta), findsNWidgets(2));
    expect(find.text('Protein Analyses'), findsOneWidget);
    expect(find.text('Lab'), findsOneWidget);
  });
}
