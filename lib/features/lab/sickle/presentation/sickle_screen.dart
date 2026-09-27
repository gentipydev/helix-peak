import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/biology/gene_record.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/evidence/gene_clinvar.dart';
import '../../../../core/evidence/variant_evidence.dart';
import '../../../../core/network/track_source.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/nucleotide_colors.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../../../../shared/clinvar/evidence_row.dart';
import '../../../../shared/clinvar/evidence_sections.dart';
import '../../../../shared/clinvar/sources_note.dart';
import '../../../../shared/format.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../../crispr/domain/base_editor.dart';
import '../../crispr/domain/guide_finder.dart';
import '../../mutate/domain/apply_edit.dart';
import '../../mutate/presentation/edit_ripple.dart';
import '../../mutate/presentation/outcome_sentence.dart';
import '../../presentation/lab_anatomy_view.dart';
import '../../presentation/lab_record.dart';
import '../domain/sickle_story.dart';

/// `/lab/sickle`: the one flow in the lab that does not ask which protein.
///
/// A story names its own subject, so this asks the catalog for the row whose
/// gene is [sickleGene] and says so plainly where the catalog has none.
class SickleRoute extends StatelessWidget {
  const SickleRoute({super.key});

  static const String title = 'The sickle cell story';

  @override
  Widget build(BuildContext context) {
    final ProteinCatalogRepository catalog = context
        .read<ProteinCatalogRepository>();
    return ValueListenableBuilder<List<ProteinTarget>>(
      valueListenable: catalog.rows,
      builder: (BuildContext context, List<ProteinTarget> rows, _) {
        if (rows.isEmpty) {
          return const Scaffold(body: LoadingView(label: 'LOADING PROTEINS'));
        }
        ProteinTarget? subject;
        for (final ProteinTarget row in rows) {
          if (row.gene == sickleGene) {
            subject = row;
            break;
          }
        }
        if (subject == null) {
          return Scaffold(
            appBar: AppBar(title: const Text(title)),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.screenPadding),
                child: Text(
                  'This story is about $sickleGene, and the catalog has no '
                  'row for it.',
                  key: ValueKey<String>('sickle-no-subject'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return LabRecordView(
          target: subject,
          title: title,
          builder: (BuildContext context, GeneRecord record) =>
              SickleScreen(target: subject!, record: record),
        );
      },
    );
  }
}

/// Three chapters about one base, told with the machinery the lab already
/// has.
///
/// Every number and every letter here is read off the record or worked out by
/// the edit engine, the base editors and the guide finder: what the codon
/// reads, what each change makes of it, which editor could write it and which
/// guides could carry one. Every clinical word belongs to a source — ClinVar's
/// own rows, quoted, and the papers each chapter links — and no sentence here
/// says what any of it means for a person.
class SickleScreen extends StatefulWidget {
  const SickleScreen({required this.target, required this.record, super.key});

  final ProteinTarget target;
  final GeneRecord record;

  @override
  State<SickleScreen> createState() => _SickleScreenState();
}

class _SickleScreenState extends State<SickleScreen> {
  late final SickleStory? _story = SickleStory.of(widget.record);
  late final AnatomyModel _reference = AnatomyModel.derive(
    widget.record,
    chain: widget.target.chain,
  );
  late final AnatomyModel? _sickle = _story == null
      ? null
      : AnatomyModel.derive(_story.sickle, chain: widget.target.chain);
  late final AnatomyModel? _makassar = _story == null
      ? null
      : AnatomyModel.derive(_story.makassar, chain: widget.target.chain);

  int _chapter = 0;

  List<VariantEvidence> _evidence = const <VariantEvidence>[];
  bool _clinvarSettled = false;

  /// The ClinVar rows opened in place, by Variation ID.
  final Set<String> _open = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.target.clinvarAvailable) {
      unawaited(_loadClinVar());
    } else {
      _clinvarSettled = true;
    }
  }

  Future<void> _loadClinVar() async {
    try {
      final GeneClinVar snapshot = await GeneClinVar.load(
        widget.target,
        tracks: context.read<TrackSource>(),
      );
      if (!snapshot.matchesRecord(widget.record)) {
        throw const FormatException('ClinVar snapshot names another record');
      }
      final List<VariantEvidence> evidence = VariantEvidence.build(
        snapshot,
        nonCoding: nonCodingSections(_reference),
      );
      if (mounted) {
        setState(() {
          _evidence = evidence;
          _clinvarSettled = true;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _clinvarSettled = true);
      }
    }
  }

  /// ClinVar's records of exactly one change at the story's base.
  List<VariantEvidence> _recordsOf(String alt) {
    final SickleStory? story = _story;
    if (story == null) {
      return const <VariantEvidence>[];
    }
    return <VariantEvidence>[
      for (final VariantEvidence evidence in _evidence)
        if (evidence.variant.position == story.position &&
            evidence.variant.alt == alt)
          evidence,
    ];
  }

  void _toggle(VariantEvidence evidence) => setState(() {
    final String id = evidence.variant.id;
    if (!_open.remove(id)) {
      _open.add(id);
    }
  });

  @override
  Widget build(BuildContext context) {
    final SickleStory? story = _story;
    if (story == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(SickleRoute.title)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.screenPadding),
            child: Text(
              'This record does not hold the codon the story is about, so '
              'there is no story to tell from it.',
              key: ValueKey<String>('sickle-untellable'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final ThemeData theme = Theme.of(context);
    final List<_Chapter> chapters = <_Chapter>[
      _casgevy(story),
      _correction(story),
      _makassarChapter(story),
    ];
    final _Chapter chapter = chapters[_chapter];
    return Scaffold(
      appBar: AppBar(title: const Text(SickleRoute.title)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Chapter ${spelled(_chapter + 1)} of '
                    '${spelled(chapters.length)}',
                    key: const ValueKey<String>('sickle-chapter'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(chapter.title, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: ValueKey<int>(_chapter),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  AppSpacing.lg,
                ),
                children: <Widget>[
                  ...chapter.body,
                  const SizedBox(height: AppSpacing.lg),
                  Text('Sources', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  SourcesNote(
                    key: ValueKey<String>('sickle-sources-$_chapter'),
                    sources: chapter.sources,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                0,
                AppSpacing.screenPadding,
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      key: const ValueKey<String>('sickle-back'),
                      onPressed: _chapter == 0
                          ? null
                          : () => setState(() => _chapter--),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey<String>('sickle-next'),
                      onPressed: _chapter == chapters.length - 1
                          ? null
                          : () => setState(() => _chapter++),
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- chapter 1

  _Chapter _casgevy(SickleStory story) => _Chapter(
    title: 'The approved therapy does not edit this gene',
    sources: _casgevySources,
    body: <Widget>[
      Container(
        key: const ValueKey<String>('sickle-not-this-gene'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'BCL11A — another gene, not in this catalog',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _Body(
              'Nothing on this page is drawn on BCL11A. The other two '
              'chapters change one base of ${widget.record.gene}, which this '
              'catalog does hold; this chapter is about a gene it does not, '
              'and so it is told in words alone.',
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      const _Body(
        'The approved therapy, exagamglogene autotemcel, is aimed at BCL11A '
        'and not at the haemoglobin gene at all. Its guide cuts a GATA1 '
        'binding site inside the enhancer that BCL11A uses in red-cell '
        'precursors and nowhere else.',
      ),
      const SizedBox(height: AppSpacing.sm),
      const _Body(
        'Breaking that one site lowers BCL11A in those cells. BCL11A is what '
        'holds the fetal globin genes quiet after birth, so with less of it '
        'they are read again and fetal haemoglobin rises. The gene this story '
        'draws is left exactly as it was: the therapy changes which globin a '
        'cell makes, not the letters of this one.',
      ),
    ],
  );

  // ------------------------------------------------------------- chapter 2

  _Chapter _correction(SickleStory story) {
    final List<({String from, String to})> changes = BaseEditor.changes;
    return _Chapter(
      title: 'Why no editor puts the change back',
      sources: _editorSources,
      body: <Widget>[
        _Body(
          'Codon ${grouped(sickleCodon)} of the chain this gene codes for '
          'reads ${story.codonIn(story.reference)}. The sickle change is one '
          'base of it: the '
          '${story.codonIn(story.reference)[1]} in the middle reads '
          '${story.codonIn(story.sickle)[1]} instead.',
        ),
        const SizedBox(height: AppSpacing.md),
        _CodonStrip(
          before: story.codonIn(story.reference),
          after: story.codonIn(story.sickle),
          beforeResidue: story.residueIn(story.reference),
          afterResidue: story.residueIn(story.sickle),
          storyKey: const ValueKey<String>('sickle-codon'),
        ),
        const SizedBox(height: AppSpacing.md),
        _Sentence(
          outcomeSentence(
            story.sickleOutcome,
            before: story.reference,
            after: story.sickle,
          ),
          sentenceKey: const ValueKey<String>('sickle-outcome'),
        ),
        if (_sickle case final AnatomyModel after) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _Ripple(
            before: _reference,
            after: after,
            outcome: story.sickleOutcome,
            viewKey: const ValueKey<String>('sickle-ripple'),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _Body(
          'To put it back, the base that now reads '
          '${story.codonIn(story.sickle)[1]} would have to read '
          '${story.codonIn(story.reference)[1]} again. No base editor writes '
          'that. Between them the ${spelled(BaseEditor.all.length)} editors '
          'write ${spelled(changes.length)} of the twelve changes one base '
          'can become, on either strand:',
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          key: const ValueKey<String>('sickle-editor-changes'),
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final ({String from, String to}) change in changes)
              Chip(
                label: Text('${change.from} to ${change.to}'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _Body(
          'The one this codon would need — '
          '${story.codonIn(story.sickle)[1]} to '
          '${story.codonIn(story.reference)[1]} — is not among them, and '
          'neither is it on the other strand. A deaminase turns A into G or C '
          'into T; it cannot turn one of a pair into the other.',
        ),
        ..._clinvarRows(
          alt: story.sickleEdit.newBase,
          heading: 'ClinVar’s record of this change, in its own words',
          rowKey: 'sickle-clinvar-change',
        ),
      ],
    );
  }

  // ------------------------------------------------------------- chapter 3

  _Chapter _makassarChapter(SickleStory story) {
    final ({BaseEditor editor, GuideStrand strand})? editor =
        story.makassarEditor;
    return _Chapter(
      title: 'The Makassar workaround',
      sources: _makassarSources,
      body: <Widget>[
        _Body(
          'If the change cannot be undone, the codon can still be moved '
          'somewhere else. An adenine editor turns the middle base from '
          '${story.codonIn(story.sickle)[1]} into '
          '${story.codonIn(story.makassar)[1]}, and '
          '${story.codonIn(story.sickle)} becomes '
          '${story.codonIn(story.makassar)}.',
        ),
        const SizedBox(height: AppSpacing.md),
        _CodonStrip(
          before: story.codonIn(story.sickle),
          after: story.codonIn(story.makassar),
          beforeResidue: story.residueIn(story.sickle),
          afterResidue: story.residueIn(story.makassar),
          storyKey: const ValueKey<String>('makassar-codon'),
        ),
        const SizedBox(height: AppSpacing.md),
        _Sentence(
          outcomeSentence(
            story.makassarOutcome,
            before: story.sickle,
            after: story.makassar,
          ),
          sentenceKey: const ValueKey<String>('makassar-outcome'),
        ),
        if (_sickle case final AnatomyModel before)
          if (_makassar case final AnatomyModel after) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _Ripple(
              before: before,
              after: after,
              outcome: story.makassarOutcome,
              viewKey: const ValueKey<String>('makassar-ripple'),
            ),
          ],
        const SizedBox(height: AppSpacing.lg),
        if (editor != null)
          _Body(
            'The editor deaminates an A, and the A here is the one paired '
            'with the base the page draws, so its guide has to be aimed at '
            'the ${editor.strand == GuideStrand.antisense ? 'other' : 'drawn'} '
            'strand. That is the ${editor.editor.name} '
            '(${editor.editor.abbreviation}), writing '
            '${editor.editor.from} to ${editor.editor.to} on the strand it '
            'is aimed at.',
            bodyKey: const ValueKey<String>('makassar-editor'),
          ),
        const SizedBox(height: AppSpacing.md),
        _Body(
          story.carried
              ? 'This record offers ${spelled(story.carriers.length)} guide '
                    'that would carry the editor there.'
              : 'No guide this screen searches for can carry it there. '
                    '${spelledLeading(story.reach.length)} NGG '
                    '${story.reach.length == 1 ? 'guide covers' : 'guides cover'} '
                    'the base at all, and they hold it at '
                    '${story.reach.map((GuideReach r) => grouped(r.place)).join(' and ')} '
                    'of their twenty; an editor reaches '
                    '${grouped(BaseEditor.windowFrom)} to '
                    '${grouped(BaseEditor.windowTo)}. Aiming one at this base '
                    'means a nuclease that reads a PAM other than NGG, which '
                    'is not what the guide finder here looks for.',
          bodyKey: const ValueKey<String>('makassar-reach'),
        ),
        ..._clinvarRows(
          alt: story.makassarEdit.newBase,
          heading: 'ClinVar’s record of this change, in its own words',
          rowKey: 'makassar-clinvar-change',
        ),
      ],
    );
  }

  /// ClinVar's rows for one change, through the walk's own [EvidenceRow], or
  /// a line saying where the snapshot has got to.
  List<Widget> _clinvarRows({
    required String alt,
    required String heading,
    required String rowKey,
  }) {
    final ThemeData theme = Theme.of(context);
    final List<VariantEvidence> records = _recordsOf(alt);
    if (records.isEmpty) {
      return <Widget>[
        const SizedBox(height: AppSpacing.lg),
        _Quiet(
          !_clinvarSettled
              ? 'Reading ClinVar…'
              : 'ClinVar has no record of this exact change in this snapshot.',
          quietKey: ValueKey<String>('$rowKey-none'),
        ),
      ];
    }
    return <Widget>[
      const SizedBox(height: AppSpacing.lg),
      Text(heading, style: theme.textTheme.titleSmall),
      for (final VariantEvidence evidence in records)
        EvidenceRow(
          key: ValueKey<String>('$rowKey-${evidence.variant.id}'),
          evidence: evidence,
          column: EvidenceColumn.both,
          expanded: _open.contains(evidence.variant.id),
          onToggle: () => _toggle(evidence),
          allele: true,
          place: false,
        ),
    ];
  }
}

/// One chapter: what it is called, what it shows, and where its claims are
/// answered for.
@immutable
final class _Chapter {
  const _Chapter({
    required this.title,
    required this.body,
    required this.sources,
  });

  final String title;
  final List<Widget> body;
  final List<SourceEntry> sources;
}

/// The papers each chapter rests on. A claim and the place it is answered for
/// belong on the same screen, so each chapter carries its own.
final List<SourceEntry> _casgevySources = <SourceEntry>[
  SourceEntry(
    name: 'Canver et al., 2015',
    text:
        'Nature 527:192. Cas9 saturating mutagenesis across the BCL11A '
        'enhancer, which is where the GATA1 binding site in the '
        'erythroid-specific enhancer was found.',
    uri: Uri.parse('https://doi.org/10.1038/nature15521'),
  ),
  SourceEntry(
    name: 'Frangoul et al., 2021',
    text:
        'N Engl J Med 384:252. The first report of this editing strategy '
        'given to people, and where its mechanism is set out.',
    uri: Uri.parse('https://doi.org/10.1056/NEJMoa2031054'),
  ),
  SourceEntry(
    name: 'FDA, December 2023',
    text:
        'The approval of exagamglogene autotemcel. What a therapy is approved '
        'for, and for whom, is the label’s to say and not this screen’s.',
    uri: Uri.parse(
      'https://www.fda.gov/news-events/press-announcements/'
      'fda-approves-first-gene-therapies-treat-patients-sickle-cell-disease',
    ),
  ),
];

final List<SourceEntry> _editorSources = <SourceEntry>[
  SourceEntry(
    name: 'Komor et al., 2016',
    text:
        'Nature 533:420. The cytosine base editor: C deaminated to U, which '
        'is read as T.',
    uri: Uri.parse('https://doi.org/10.1038/nature17946'),
  ),
  SourceEntry(
    name: 'Gaudelli et al., 2017',
    text:
        'Nature 551:464. The adenine base editor: A deaminated to inosine, '
        'which is read as G.',
    uri: Uri.parse('https://doi.org/10.1038/nature24644'),
  ),
  const SourceEntry(
    name: 'ClinVar',
    text:
        'NCBI, germline classifications. The rows above are quoted from the '
        'snapshot this app stores, classification and conditions as ClinVar '
        'gives them. Records are submissions, not patients.',
  ),
];

final List<SourceEntry> _makassarSources = <SourceEntry>[
  SourceEntry(
    name: 'Newby et al., 2021',
    text:
        'Nature 595:295. Adenine base editing of the sickle codon to the '
        'Makassar codon, and the editor and PAM that reach it.',
    uri: Uri.parse('https://doi.org/10.1038/s41586-021-03609-w'),
  ),
  const SourceEntry(
    name: 'ClinVar',
    text:
        'NCBI, germline classifications. Hb G-Makassar is quoted below as '
        'ClinVar classifies it, in its own words, with the conditions it '
        'names. Records are submissions, not patients.',
  ),
];

/// A paragraph of the chapter's own prose.
class _Body extends StatelessWidget {
  const _Body(this.text, {this.bodyKey});

  final String text;
  final ValueKey<String>? bodyKey;

  @override
  Widget build(BuildContext context) =>
      Text(text, key: bodyKey, style: Theme.of(context).textTheme.bodyMedium);
}

/// The edit engine's own sentence about a change, set apart from the prose.
class _Sentence extends StatelessWidget {
  const _Sentence(this.text, {required this.sentenceKey});

  final String text;
  final ValueKey<String> sentenceKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text, key: sentenceKey, style: theme.textTheme.bodyMedium),
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet(this.text, {this.quietKey});

  final String text;
  final ValueKey<String>? quietKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      key: quietKey,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// One codon before and after, with the base that differs picked out.
class _CodonStrip extends StatelessWidget {
  const _CodonStrip({
    required this.before,
    required this.after,
    required this.beforeResidue,
    required this.afterResidue,
    required this.storyKey,
  });

  final String before;
  final String after;
  final String beforeResidue;
  final String afterResidue;
  final ValueKey<String> storyKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NucleotideColors bases = context.nucleotideColors;
    Widget triplet(String codon, String other) => Text.rich(
      TextSpan(
        children: <InlineSpan>[
          for (int i = 0; i < codon.length; i++)
            TextSpan(
              text: codon[i],
              style: TextStyle(
                color: bases.forBase(codon[i]),
                fontWeight: codon[i] == other[i]
                    ? FontWeight.w400
                    : FontWeight.w700,
                decoration: codon[i] == other[i]
                    ? null
                    : TextDecoration.underline,
                decorationColor: bases.forBase(codon[i]),
              ),
            ),
        ],
      ),
      style: theme.textTheme.titleLarge?.copyWith(
        fontFamily: AppTypography.monoFamily,
      ),
    );
    return Row(
      key: storyKey,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            triplet(before, after),
            Text(
              AminoAcids.nameOf(beforeResidue).toLowerCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            triplet(after, before),
            Text(
              AminoAcids.nameOf(afterResidue).toLowerCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The chain turning from one protein into the other, on the walk's own page.
class _Ripple extends StatelessWidget {
  const _Ripple({
    required this.before,
    required this.after,
    required this.outcome,
    required this.viewKey,
  });

  final AnatomyModel before;
  final AnatomyModel after;
  final EditOutcome outcome;
  final ValueKey<String> viewKey;

  /// Tall enough for the chain, short enough to leave the chapter readable.
  static const double height = 260;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final Size viewport = Size(box.maxWidth, box.maxHeight);
        return SingleChildScrollView(
          child: LabAnatomyView(
            key: viewKey,
            scene: editRipple(
              before: before,
              after: after,
              target: rippleTargets(
                before: before.record.protein?.translation ?? '',
                after: after.record.protein?.translation ?? '',
                outcome: outcome,
              ),
              viewport: viewport,
            ),
            duration: const Duration(milliseconds: 1400),
          ),
        );
      },
    ),
  );
}
