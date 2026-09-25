import 'protein_ranking.dart';
import 'protein_target.dart';
import 'protein_track.dart';

/// The proteins this build bundles, in the order the search screen lists them.
///
/// This was the whole catalog. It is now the seed: `ProteinCatalogRepository`
/// starts from these rows and replaces them with what `/catalog` serves, so
/// what a reader sees comes from the service and what the *bundle* can draw
/// still comes from here. Three things keep it:
///
/// - The walk has to open before any request finishes, and a repository built
///   already holding these rows answers `bySlug` synchronously — which is what
///   lets the router stay a plain builder and search stay instant.
/// - The `tracks` map on each row says which families this build can draw for
///   that protein. It is not a claim about the bundle: a family that has moved
///   to storage is still seeded ready, because the track exists and a device
///   that cannot reach it has failed to fetch it rather than found it unbaked.
///   The four booleans the rows used to carry are retiring into this map, one
///   family at a time as that family moves.
/// - `tool/check_assets.py` and `tool/seed_catalog.py` read these rows out of
///   this file as text. They are one half of the gate that proves the service's
///   catalog and the baked assets still agree.
///
/// The order is not alphabetical. Insulin is first because it is the one the
/// app was built around, and the first ten run small to large, which is also
/// simplest to hardest: a nine-residue hormone, then a globin, then a
/// transcription factor, and dystrophin closing them because nothing about it
/// is ordinary. The ten after dystrophin keep the order they were added in, and
/// each was checked against its record before it was — see
/// `docs/protein-verification.md`. That sequence travels as `catalog_order` on
/// every served row, because a list the client no longer holds cannot carry it.
/// The assets are baked by `tool/`, off the table in `tool/targets.py` — the
/// two are checked against each other by the tests in
/// `test/features/gene_lookup/catalog/`.
/// What the twenty are seeded with.
///
/// Every one of them has all four data families and a record. Stated rather
/// than left empty: the booleans that used to say it are being retired into
/// [ProteinTarget.state], and a row that said nothing would read as a protein
/// with no tracks at all — which is the one thing none of these twenty is.
const Map<TrackKind, TrackRef> _seeded = <TrackKind, TrackRef>{
  TrackKind.constraint: TrackRef.seeded(),
  TrackKind.impact: TrackRef.seeded(),
  TrackKind.clinvar: TrackRef.seeded(),
  TrackKind.structure: TrackRef.seeded(),
};

/// The three genes the exact-allele AVI pilot covers.
const Map<TrackKind, TrackRef> _seededWithExplanations = <TrackKind, TrackRef>{
  ..._seeded,
  TrackKind.impactExplanations: TrackRef.seeded(),
};

abstract final class ProteinCatalog {
  static const ProteinTarget insulin = ProteinTarget(
    slug: 'insulin',
    tracks: _seededWithExplanations,
    impactExplanationsAvailable: true,
    display: 'Insulin',
    gene: 'INS',
    uniprot: 'P01308',
    accession: 'NG_007114',
    summary: 'The hormone that clears glucose from the blood.',
    facts: ProteinFacts(residues: 110, exons: 3, chains: 3, bridges: 3),
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature3),
      StructureChain('chainB', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '3I40',
      label: 'the hormone',
      count: 51,
      unit: 'residues',
      sentence: 'The C-peptide is cut out. Two disulfide bridges join A to B, a third folds A.',
      semantics:
          'The folded insulin molecule: the A and B chains, joined by two '
          'disulfide bridges, with a third inside the A chain. Drag to turn it.',
    ),
  );

  static const ProteinTarget hemoglobin = ProteinTarget(
    slug: 'hemoglobin',
    tracks: _seededWithExplanations,
    impactExplanationsAvailable: true,
    display: 'Hemoglobin (beta chain)',
    gene: 'HBB',
    uniprot: 'P68871',
    accession: 'NG_059281',
    summary: 'Carries oxygen from the lungs. Sickle-cell disease is one base of this gene.',
    facts: ProteinFacts(residues: 147, exons: 3, chains: 1, bridges: 0),
    chain: 'hemoglobin beta chain',
    chains: <StructureChain>[StructureChain('chainA', ChainTint.mature1)],
    structure: StructureChrome(
      pdb: '2DN1',
      label: 'the subunit',
      count: 146,
      unit: 'residues',
      sentence: 'One beta chain. Hemoglobin is four: two like this, and two alpha.',
      semantics:
          'The folded beta-globin chain, one of the four chains of a '
          'haemoglobin molecule. Drag to turn it.',
    ),
  );

  static const ProteinTarget myoglobin = ProteinTarget(
    slug: 'myoglobin',
    tracks: _seeded,
    display: 'Myoglobin',
    gene: 'MB',
    uniprot: 'P02144',
    accession: 'NG_007075',
    summary: 'Holds oxygen in muscle. The first protein whose structure was ever solved.',
    facts: ProteinFacts(residues: 154, exons: 3, chains: 1, bridges: 0),
    chain: 'myoglobin',
    chains: <StructureChain>[StructureChain('chainA', ChainTint.mature1)],
    structure: StructureChrome(
      pdb: '3RGK',
      label: 'the fold',
      count: 153,
      unit: 'residues',
      sentence: 'Eight helices around one pocket. The globin fold.',
      semantics:
          'The folded myoglobin molecule, eight helices around the pocket that '
          'holds its oxygen. Drag to turn it.',
    ),
  );

  static const ProteinTarget p53 = ProteinTarget(
    slug: 'p53',
    tracks: _seeded,
    display: 'p53',
    gene: 'TP53',
    uniprot: 'P04637',
    accession: 'NG_017013',
    summary: 'The tumour suppressor. Mutated in about half of all human cancers.',
    facts: ProteinFacts(residues: 393, exons: 11, chains: 1, bridges: 0),
    chain: 'p53',
    chains: <StructureChain>[StructureChain('chainA', ChainTint.mature1)],
    structure: StructureChrome(
      pdb: '2OCJ',
      modelled: (96, 289),
      label: 'the core',
      count: 194,
      unit: 'residues',
      sentence: 'The part that grips DNA. Most of the rest of p53 is disordered and has no structure.',
      semantics:
          'The folded DNA-binding core of p53. The rest of the protein, mostly '
          'disordered, is not drawn. Drag to turn it.',
    ),
  );

  static const ProteinTarget lysozyme = ProteinTarget(
    slug: 'lysozyme',
    tracks: _seeded,
    display: 'Lysozyme',
    gene: 'LYZ',
    uniprot: 'P61626',
    accession: 'NG_008195',
    summary: 'Cuts the cell walls of bacteria. In tears, saliva and milk.',
    facts: ProteinFacts(residues: 148, exons: 4, chains: 1, bridges: 4),
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '1REX',
      label: 'the enzyme',
      count: 130,
      unit: 'residues',
      sentence: 'Four disulfide bridges brace the cleft a cell wall has to fit into.',
      semantics:
          'The folded lysozyme molecule, with the four disulfide bridges that '
          'brace the cleft a cell wall binds in. Drag to turn it.',
    ),
  );

  static const ProteinTarget relaxin = ProteinTarget(
    slug: 'relaxin',
    tracks: _seeded,
    display: 'Relaxin',
    gene: 'RLN2',
    uniprot: 'P04090',
    accession: 'NC_000009.12',
    summary: 'Softens ligaments in pregnancy. Built like insulin, and cut the same way.',
    facts: ProteinFacts(residues: 185, exons: 2, chains: 3, bridges: 3),
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature3),
      StructureChain('chainB', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '6RLX',
      label: 'the hormone',
      count: 53,
      unit: 'residues',
      sentence: 'The same architecture as insulin: two chains, three disulfide bridges.',
      semantics:
          'The folded relaxin molecule: the A and B chains, joined by two '
          'disulfide bridges, with a third inside the A chain. Drag to turn it.',
    ),
  );

  static const ProteinTarget oxytocin = ProteinTarget(
    slug: 'oxytocin',
    tracks: _seeded,
    display: 'Oxytocin',
    gene: 'OXT',
    uniprot: 'P01178',
    accession: 'NC_000020.11',
    summary: 'Nine residues, cut out of a precursor a hundred and twenty-five long.',
    facts: ProteinFacts(residues: 125, exons: 3, chains: 2, bridges: 8),
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '7RYC',
      label: 'the hormone',
      count: 9,
      unit: 'residues',
      sentence: 'One bridge closes the ring. Neurophysin, its carrier, is cut away.',
      semantics:
          'The oxytocin nonapeptide, closed into a ring by its single disulfide '
          'bridge. Drag to turn it.',
    ),
  );

  static const ProteinTarget somatotropin = ProteinTarget(
    slug: 'somatotropin',
    tracks: _seeded,
    display: 'Growth hormone',
    gene: 'GH1',
    uniprot: 'P01241',
    accession: 'NG_011676',
    summary: 'Somatotropin. Drives growth in childhood and metabolism after it.',
    facts: ProteinFacts(residues: 217, exons: 5, chains: 1, bridges: 2),
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '1HGU',
      label: 'the hormone',
      count: 191,
      unit: 'residues',
      sentence: 'A bundle of four helices, pinned by two disulfide bridges.',
      semantics:
          'The folded growth hormone molecule, a bundle of four helices pinned '
          'by two disulfide bridges. Drag to turn it.',
    ),
  );

  static const ProteinTarget ubiquitin = ProteinTarget(
    slug: 'ubiquitin',
    tracks: _seeded,
    display: 'Ubiquitin',
    gene: 'UBB',
    uniprot: 'P0CG47',
    accession: 'NG_023320',
    summary: 'Made as three copies in a row, then cut into three identical tags.',
    facts: ProteinFacts(residues: 229, exons: 2, chains: 3, bridges: 0),
    chains: <StructureChain>[StructureChain('chainA', ChainTint.mature1)],
    structure: StructureChrome(
      pdb: '1UBQ',
      label: 'the tag',
      count: 76,
      unit: 'residues',
      sentence: 'One of the three. All three fold into the same tag.',
      semantics:
          'One folded ubiquitin molecule, the tag the precursor is cut into '
          'three of. Drag to turn it.',
    ),
  );

  static const ProteinTarget dystrophin = ProteinTarget(
    slug: 'dystrophin',
    tracks: _seeded,
    display: 'Dystrophin',
    gene: 'DMD',
    uniprot: 'P11532',
    accession: 'NG_012232',
    summary: 'The largest human gene: over 2 million bases, 79 exons, 3,685 residues.',
    facts: ProteinFacts(residues: 3685, exons: 79, chains: 1, bridges: 0),
    chain: 'dystrophin',
    chains: <StructureChain>[StructureChain('chainA', ChainTint.mature1)],
    structure: StructureChrome(
      pdb: '1DXX',
      modelled: (9, 246),
      label: 'the actin grip',
      count: 238,
      unit: 'residues',
      sentence: 'No structure exists for all 3,685 residues. This is the end that holds actin.',
      semantics:
          'The folded actin-binding end of dystrophin. The other three thousand '
          'residues are solved only in fragments, if at all, and are not drawn. '
          'Drag to turn it.',
    ),
  );

  static const ProteinTarget vasopressin = ProteinTarget(
    slug: 'vasopressin',
    tracks: _seeded,
    display: 'Vasopressin',
    gene: 'AVP',
    uniprot: 'P01185',
    accession: 'NG_008663',
    summary: 'Tells the kidneys to hold on to water. Cut from a precursor built like oxytocin.',
    facts: ProteinFacts(residues: 164, exons: 3, chains: 3, bridges: 8),
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '7KH0',
      label: 'the hormone',
      count: 9,
      unit: 'residues',
      sentence: 'One bridge closes the ring. Neurophysin 2 and copeptin are cut away.',
      semantics:
          'The vasopressin nonapeptide, closed into a ring by its single '
          'disulfide bridge. Drag to turn it.',
    ),
  );

  static const ProteinTarget glucagon = ProteinTarget(
    slug: 'glucagon',
    tracks: _seeded,
    display: 'Glucagon',
    gene: 'GCG',
    uniprot: 'P01275',
    accession: 'NC_000002.12',
    summary: 'Raises blood sugar. Its precursor also holds GLP-1 and GLP-2, cut out in the gut.',
    facts: ProteinFacts(residues: 180, exons: 6, chains: 1, bridges: 0),
    chain: 'pro-glucagon',
    chains: <StructureChain>[StructureChain('chainA', ChainTint.mature1)],
    structure: StructureChrome(
      pdb: '6LMK',
      label: 'the hormone',
      count: 29,
      unit: 'residues',
      sentence: 'One of several hormones cut from proglucagon. No disulfide bridges.',
      semantics:
          'Glucagon, the 29-residue hormone cut from proglucagon, as it sits in '
          'its receptor. The other peptides cut from the precursor are not '
          'drawn. Drag to turn it.',
    ),
  );

  static const ProteinTarget app = ProteinTarget(
    slug: 'app',
    tracks: _seeded,
    display: 'Amyloid precursor protein',
    gene: 'APP',
    uniprot: 'P05067',
    accession: 'NG_007376',
    summary: 'Cut into amyloid-beta, the peptide that builds up in the brain in Alzheimer disease.',
    facts: ProteinFacts(residues: 770, exons: 18, chains: 1, bridges: 9),
    chain: 'APP',
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '4PWQ',
      label: 'the E1 domain',
      count: 162,
      unit: 'residues',
      sentence: 'No structure exists for all 770 residues. This is its first folded domain.',
      semantics:
          'The E1 domain at the start of APP, held by six disulfide bridges. '
          'Amyloid-beta and the rest of the protein are solved only in pieces '
          'and are not drawn. Drag to turn it.',
    ),
  );

  static const ProteinTarget cftr = ProteinTarget(
    slug: 'cftr',
    tracks: _seededWithExplanations,
    impactExplanationsAvailable: true,
    display: 'CFTR',
    gene: 'CFTR',
    uniprot: 'P13569',
    accession: 'NG_016465',
    summary: 'A chloride channel in lungs and gut. Faults in it cause cystic fibrosis.',
    facts: ProteinFacts(residues: 1480, exons: 27, chains: 1, bridges: 0),
    chain: 'CFTR',
    chains: <StructureChain>[StructureChain('chainA', ChainTint.mature1)],
    structure: StructureChrome(
      pdb: '5UAK',
      label: 'the channel',
      count: 1480,
      unit: 'residues',
      sentence: 'Two halves, each a membrane domain and an ATP-binding domain.',
      semantics:
          'The folded CFTR channel: two halves that each cross the membrane six '
          'times and bind ATP. The regulatory region between them is too mobile '
          'to resolve and is not drawn. Drag to turn it.',
    ),
  );

  static const ProteinTarget erythropoietin = ProteinTarget(
    slug: 'erythropoietin',
    tracks: _seeded,
    display: 'Erythropoietin',
    gene: 'EPO',
    uniprot: 'P01588',
    accession: 'NG_021471',
    summary: 'Made in the kidney. Tells bone marrow to make red blood cells.',
    facts: ProteinFacts(residues: 193, exons: 5, chains: 1, bridges: 2),
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '1EER',
      label: 'the hormone',
      count: 166,
      unit: 'residues',
      sentence: 'A bundle of four helices, braced by two disulfide bridges.',
      semantics:
          'The folded erythropoietin molecule, a bundle of four helices braced '
          'by two disulfide bridges. Drag to turn it.',
    ),
  );

  static const ProteinTarget leptin = ProteinTarget(
    slug: 'leptin',
    tracks: _seeded,
    display: 'Leptin',
    gene: 'LEP',
    uniprot: 'P41159',
    accession: 'NG_007450',
    summary: 'Made by fat cells. Tells the brain how much energy the body has stored.',
    facts: ProteinFacts(residues: 167, exons: 3, chains: 1, bridges: 1),
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '1AX8',
      label: 'the hormone',
      count: 146,
      unit: 'residues',
      sentence: 'A bundle of four helices, closed by one disulfide bridge.',
      semantics:
          'The folded leptin molecule, a bundle of four helices with one '
          'disulfide bridge. Drag to turn it.',
    ),
  );

  static const ProteinTarget tnf = ProteinTarget(
    slug: 'tnf',
    tracks: _seeded,
    display: 'TNF-alpha',
    gene: 'TNF',
    uniprot: 'P01375',
    accession: 'NG_007462',
    summary: 'A signal of inflammation, and the target of drugs for arthritis.',
    facts: ProteinFacts(residues: 233, exons: 4, chains: 2, bridges: 1),
    // No `chain`: the record names both pieces ADAM17 leaves, so the gene page
    // reads them rather than its exons.
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    // One chain of an assembly, said the way haemoglobin's page says it: the
    // label, the sentence and what a screen reader hears. The gene makes every
    // chain of this one, so the name needs no qualifier.
    structure: StructureChrome(
      pdb: '7JRA',
      label: 'the subunit',
      count: 157,
      unit: 'residues',
      sentence: 'One chain of the soluble form. TNF works as three of these.',
      semantics:
          'One folded chain of soluble TNF, one of the three identical chains '
          'of an active TNF trimer, with its one disulfide bridge. Drag to turn '
          'it.',
    ),
  );

  static const ProteinTarget sod1 = ProteinTarget(
    slug: 'sod1',
    tracks: _seeded,
    display: 'SOD1',
    gene: 'SOD1',
    uniprot: 'P00441',
    accession: 'NG_008689',
    summary: 'Clears superoxide radicals from cells. Mutations in it cause an inherited form of ALS.',
    facts: ProteinFacts(residues: 154, exons: 5, chains: 1, bridges: 1),
    chain: 'superoxide dismutase',
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '2C9V',
      label: 'the subunit',
      count: 153,
      unit: 'residues',
      sentence: 'One chain. SOD1 works as a pair of these.',
      semantics:
          'One folded SOD1 chain, one of the two identical chains of the active '
          'enzyme, with its one disulfide bridge. Its copper and zinc are not '
          'drawn. Drag to turn it.',
    ),
  );

  static const ProteinTarget amylase = ProteinTarget(
    slug: 'amylase',
    tracks: _seeded,
    display: 'Amylase',
    gene: 'AMY1A',
    uniprot: 'P0DUB6',
    accession: 'NC_000001.11',
    summary: 'The enzyme in saliva that starts breaking starch down into sugar.',
    facts: ProteinFacts(residues: 511, exons: 11, chains: 1, bridges: 5),
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '1SMD',
      label: 'the enzyme',
      count: 496,
      unit: 'residues',
      sentence: 'Five disulfide bridges. Starch is cut in a cleft between its domains.',
      semantics:
          'The folded salivary amylase, with its five disulfide bridges and the '
          'cleft where starch is cut. Its calcium and chloride are not drawn. '
          'Drag to turn it.',
    ),
  );

  static const ProteinTarget prion = ProteinTarget(
    slug: 'prion',
    tracks: _seeded,
    display: 'Prion protein',
    gene: 'PRNP',
    uniprot: 'P04156',
    accession: 'NG_009087',
    summary: 'Harmless in its normal fold. Misfolded, it causes prion diseases such as CJD.',
    facts: ProteinFacts(residues: 253, exons: 2, chains: 1, bridges: 1),
    chains: <StructureChain>[
      StructureChain('chainA', ChainTint.mature1),
      StructureChain('bonds', ChainTint.cysteine),
    ],
    structure: StructureChrome(
      pdb: '4KML',
      label: 'the fold',
      count: 109,
      unit: 'residues',
      sentence: 'The folded half. The first hundred residues have no fixed shape.',
      semantics:
          'The folded C-terminal half of the prion protein: three helices, a '
          'short sheet and one disulfide bridge. The flexible N-terminal half '
          'is not drawn. Drag to turn it.',
    ),
  );

  static const List<ProteinTarget> all = <ProteinTarget>[
    insulin,
    oxytocin,
    ubiquitin,
    lysozyme,
    hemoglobin,
    myoglobin,
    relaxin,
    somatotropin,
    p53,
    dystrophin,
    vasopressin,
    glucagon,
    app,
    cftr,
    erythropoietin,
    leptin,
    tnf,
    sod1,
    amylase,
    prion,
  ];

  /// The one the home screen's chevron still leads to, and what `/gene` with no
  /// slug means. Named rather than `all.first` so moving a row cannot move it.
  static const ProteinTarget fallback = insulin;

  static ProteinTarget? bySlug(String slug) {
    for (final ProteinTarget target in all) {
      if (target.slug == slug) {
        return target;
      }
    }
    return null;
  }

  /// The target a `/gene/{accession}/{gene}` path is asking for, or null.
  ///
  /// Read by [MockApiClient], which is standing in for a service that answers
  /// on exactly those two path segments.
  static ProteinTarget? byPath(String accession, String gene) {
    for (final ProteinTarget target in all) {
      if (target.accession == accession && target.gene == gene) {
        return target;
      }
    }
    return null;
  }

  /// Everything bundled whose name, gene symbol, UniProt accession, RefSeq
  /// accession or summary contains [query], the closest matches first.
  ///
  /// The ranking itself lives in `protein_ranking.dart` so that this and the
  /// repository's search cannot drift into two implementations of it.
  static List<ProteinTarget> matching(String query) => rank(all, query);
}
