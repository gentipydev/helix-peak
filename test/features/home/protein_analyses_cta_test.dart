import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/config/env.dart';
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

  testWidgets('a long label wraps at a large text size, and never overflows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ProteinAnalysesCta(
                  label: 'Peptide Language Model',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Peptide Language Model'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  group('home', () {
    tearDown(() => dotenv.clean());

    testWidgets(
      'with no .env flag, home offers the walk, then the peptide language '
      'model, and nothing else',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pump();
        expect(find.byType(ProteinAnalysesCta), findsNWidgets(2));
        expect(find.text('DNA Replication'), findsNothing);
        expect(
          tester.getCenter(find.text('Protein Analyses')).dy,
          lessThan(tester.getCenter(find.text('Peptide Language Model')).dy),
        );
        expect(find.text('Lab'), findsNothing);
      },
    );

    for (final String value in <String>['false', '', 'yes', '1']) {
      testWidgets('SHOW_DNA_REPLICATION=$value keeps replication off home', (
        WidgetTester tester,
      ) async {
        dotenv.loadFromString(envString: 'SHOW_DNA_REPLICATION=$value');
        expect(Env.showDnaReplication, isFalse);
        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pump();
        expect(find.text('DNA Replication'), findsNothing);
      });
    }

    testWidgets(
      'SHOW_DNA_REPLICATION=true offers the walk, then replication, then the '
      'peptide language model',
      (WidgetTester tester) async {
        dotenv.loadFromString(envString: 'SHOW_DNA_REPLICATION=true');
        expect(Env.showDnaReplication, isTrue);
        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pump();
        expect(find.byType(ProteinAnalysesCta), findsNWidgets(3));
        expect(
          tester.getCenter(find.text('Protein Analyses')).dy,
          lessThan(tester.getCenter(find.text('DNA Replication')).dy),
        );
        expect(
          tester.getCenter(find.text('DNA Replication')).dy,
          lessThan(tester.getCenter(find.text('Peptide Language Model')).dy),
        );
      },
    );
  });
}
