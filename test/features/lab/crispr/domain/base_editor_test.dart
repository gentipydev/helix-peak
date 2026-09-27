import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/lab/crispr/domain/base_editor.dart';
import 'package:helixpeek/features/lab/crispr/domain/guide_finder.dart';

void main() {
  group('the three editors', () {
    test('each writes one base for another', () {
      expect(BaseEditor.all, hasLength(3));
      expect(
        <String>[
          for (final BaseEditor editor in BaseEditor.all)
            '${editor.abbreviation} ${editor.from}>${editor.to}',
        ],
        <String>['ABE A>G', 'CBE C>T', 'CGBE C>G'],
      );
      expect(const AdenineBaseEditor().name, 'adenine base editor');
    });

    test('an editor is a type, and the set of them is closed', () {
      // The compiler is the guard: BaseEditor is sealed, each editor is its
      // own final type, and `from` and `to` are that type's own. There is no
      // constructor to hand two bases to, so there is no fourth editor to
      // write and nothing here has to refuse one. This holds the set to what
      // the three types say.
      for (final BaseEditor editor in BaseEditor.all) {
        expect(editor.from, isIn(<String>['A', 'C']));
        expect(
          '${editor.from}>${editor.to}',
          isIn(<String>['A>G', 'C>T', 'C>G']),
        );
      }
    });

    test('the window is the same for all of them', () {
      expect((BaseEditor.windowFrom, BaseEditor.windowTo), (4, 8));
    });
  });

  group('what an editor writes on the page’s own letters', () {
    test('a sense guide writes the editor’s own bases', () {
      expect(const AdenineBaseEditor().rewrites('A', GuideStrand.sense), 'G');
      expect(const CytosineBaseEditor().rewrites('C', GuideStrand.sense), 'T');
      expect(
        const CytosineToGuanineBaseEditor().rewrites('C', GuideStrand.sense),
        'G',
      );
      expect(
        const AdenineBaseEditor().rewrites('T', GuideStrand.sense),
        isNull,
      );
    });

    test('an antisense guide writes them complemented', () {
      // The editor still deaminates an A. On the strand the page draws, the
      // base that pairs with it is a T, and what the page then reads is a C.
      expect(
        const AdenineBaseEditor().rewrites('T', GuideStrand.antisense),
        'C',
      );
      expect(
        const CytosineBaseEditor().rewrites('G', GuideStrand.antisense),
        'A',
      );
      expect(
        const CytosineToGuanineBaseEditor().rewrites(
          'G',
          GuideStrand.antisense,
        ),
        'C',
      );
      expect(
        const AdenineBaseEditor().rewrites('A', GuideStrand.antisense),
        isNull,
      );
    });

    test('six of the twelve changes, and which six', () {
      final List<String> written = <String>[
        for (final ({String from, String to}) change in BaseEditor.changes)
          '${change.from}>${change.to}',
      ];
      expect(written, hasLength(6));
      expect(written.toSet(), <String>{
        'A>G',
        'T>C',
        'C>T',
        'G>A',
        'C>G',
        'G>C',
      });
    });

    test('A to T is not one of them, on either strand', () {
      // The sickle change, and the change that would put it back.
      expect(BaseEditor.forChange(from: 'A', to: 'T'), isNull);
      expect(BaseEditor.forChange(from: 'T', to: 'A'), isNull);
      // Nor the other four transversions these editors do not make.
      for (final String change in <String>['A>C', 'T>G', 'C>A', 'G>T']) {
        expect(
          BaseEditor.forChange(from: change[0], to: change[2]),
          isNull,
          reason: change,
        );
      }
    });

    test('a change one of them does write names the editor and the strand', () {
      final ({BaseEditor editor, GuideStrand strand})? found =
          BaseEditor.forChange(from: 'T', to: 'C');
      expect(found?.editor, isA<AdenineBaseEditor>());
      expect(found?.strand, GuideStrand.antisense);

      final ({BaseEditor editor, GuideStrand strand})? direct =
          BaseEditor.forChange(from: 'A', to: 'G');
      expect(direct?.editor, isA<AdenineBaseEditor>());
      expect(direct?.strand, GuideStrand.sense);
    });

    test('every change it names is a change that editor really writes', () {
      for (final ({String from, String to}) change in BaseEditor.changes) {
        final ({BaseEditor editor, GuideStrand strand})? found =
            BaseEditor.forChange(from: change.from, to: change.to);
        expect(found, isNotNull, reason: '${change.from}>${change.to}');
        expect(found!.editor.rewrites(change.from, found.strand), change.to);
      }
    });
  });
}
