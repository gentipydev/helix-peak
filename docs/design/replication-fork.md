# Genome replication: from an origin to two forks

![Two forks leaving the origin in the guided replication animation](replication-fork.png)

## Experience

LAB → Replication opens an animation immediately. There is no protein picker,
record download or gene-specific error list. Old `/lab/replication/<slug>` links
redirect to this view. The subject is a human origin firing and one of its two
forks followed through an illustrative 200-base-pair stretch with two
100-nucleotide Okazaki fragments.

Playback takes 3 min 32 s at 1×, with 0.25×, 0.5×, 1.5× and 2× available. The
shared Ribosome transport provides pause, replay and chapter stepping. The
walk's vertical scrubber sits beside the scene: dragging pauses and seeks, with
a bubble showing the time and phase. Short captions describe the action below
it. Reduced motion starts on a still. Backgrounding pauses playback, and opening
the research sheet also pauses it. "Whole fork" keeps the whole scene in view at
the current playback time; "Follow steps" resumes the guided framing. Switching
between them glides over half a second (it cuts under reduced motion).

### Chapters

| Playback | View |
| --- | --- |
| 0 s | Origin: an A/T-rich unwinding element; each pair's hydrogen bonds drawn |
| 8 s | Pre-replication complex: ORC and Cdc6 bind; Cdt1 brings two MCM2–7 rings, which close head to head |
| 20 s | Origin firing: Cdc45 and GINS make two CMGs; the origin melts and the CMGs pass each other |
| 30 s | Two forks: the bubble grows both ways; leading strands start at the origin |
| 44 s | The upper fork |
| 48 s | CMG helicase, its ATPase sites firing in turn |
| 58 s | RPA on exposed single strands |
| 68 s | Topoisomerase II relieving the overwound DNA ahead |
| 82 s | Primase building the RNA primer |
| 92 s | RFC loading PCNA; Pol α hands the primer to Pol δ |
| 106 s | Pol ε and continuous leading-strand synthesis |
| 118 s | Pol δ moving away from the fork on the lagging strand |
| 136 s | The next RNA–DNA primer |
| 148 s | A second Okazaki fragment growing towards the first |
| 174 s | Primer replacement: three strokes, FEN1 cutting each flap |
| 188 s | DNA ligase I closing the nick |
| 200 s | Both daughter duplexes, then the camera pulls back to the whole bubble |

Each camera move takes the previous chapter's last 2.5 seconds, with smooth
acceleration and deceleration. Initiation is seen whole (1.35× to 1.7×, then
zoomed out to fit the bubble); the fork's close-ups run from 2.15× to 3×.
Labels keep their size, name only the relevant structures, fade out as the
camera starts to move and fade in as it arrives.

These are views of concurrent processes. The tour does not imply that
topoisomerase starts only after helicase or RPA. The final chapter shows the
local result while both forks continue; the newest RNA primer awaits the next
fragment beyond this example.

## Research and its consequences

### Origins, licensing and firing

Human origins share no consensus sequence; replication tends to begin in open
chromatin and many origins are G/C-rich. Where DNA first melts, A/T-rich
stretches open most easily: an A·T pair has two hydrogen bonds and a G·C pair
three, and A/T steps stack less tightly. The illustrated origin is drawn A/T-rich
to show this, and the information sheet says so.
[Prioleau & MacAlpine, 2016](https://doi.org/10.1101/gad.285114.116)

In G1, ORC and Cdc6 bind the origin and, with Cdt1, load MCM2–7 as a
head-to-head double hexamer around the duplex: the pre-replication complex.
[Remus et al., 2009](https://doi.org/10.1016/j.cell.2009.10.015)
In S phase, DDK and CDK drive the recruitment of Cdc45 and GINS to each ring,
making two CMG helicases. The CMGs untwist the origin, each closes round one
strand, and, translocating N-terminal tier first, they pass each other and move
apart. [Douglas et al., 2018](https://doi.org/10.1038/nature25787)

The animation loads both rings at once, as mirror images; in cells one ORC
loads them in turn. The kinases are named in the caption and sheet, not drawn.

### Two forks

One origin makes two forks moving in opposite directions. Each fork's leading
strand starts at the origin, and each fork's first Okazaki fragment runs back to
the origin and replaces the other fork's leading primer. The lower fork is drawn
as the upper fork turned 180° about the origin, which is exactly the double
hexamer's two-fold symmetry; in cells the forks move independently.

### Human replisome architecture

Human cryo-EM resolves CMG associated with Pol ε and fork protection factors.
Here CMG's MCM2–7 ring follows the leading template through its central channel;
the lagging template exits outside it. Pol ε remains close behind.
[Jones et al., 2021, core human replisome, PDB 7PFO](https://www.rcsb.org/structure/7PFO)

CMG's six ATPase sites hydrolyse ATP as it unwinds. The C-terminal tier lights
them in turn, one sweep per eight nucleotides unwound, so the wave stops when
the fork stops.

### Single-strand protection

RPA, the human SSB, coats exposed single-stranded DNA: it keeps the parental
strands from reannealing and protects them from nucleases. It is drawn on any
bare template, both strands in the opening bubble, and clears as synthesis or
an enzyme arrives. [Wyka et al., 2003](https://pubmed.ncbi.nlm.nih.gov/14596605/)

### Priming, the clamp and strand direction

DNA polymerases only extend an existing 3′ end, so primase lays an RNA primer
first. Human and yeast structures position primase near the excluded lagging
template. Each fragment gets an RNA start, a short Pol α DNA extension, and a
handoff: RFC opens the PCNA ring, closes it round the primer end and leaves, and
Pol δ docks on the clamp. Leading synthesis proceeds towards the fork; lagging
synthesis proceeds away from it. Both add to a growing 3′ end.
[Jones et al., 2023, Molecular Cell](https://doi.org/10.1016/j.molcel.2023.06.035),
[human primase–replisome structure, PDB 8B9D](https://www.rcsb.org/structure/8B9D)

PCNA is drawn after its structure: a homotrimer ring of two-domain subunits,
one tint per subunit, the helices lining its hole seen through it, held at a
tilt around the new duplex behind each polymerase. It turns once per helical
turn as it slides. [Gulbis et al., 1996, PDB 1AXC](https://www.rcsb.org/structure/1AXC)

The model chooses 10 RNA nucleotides and 20 Pol α DNA nucleotides per primer.
Experiments on human Pol α–primase support a 7–10-nt RNA start and approximately
20-nt DNA extension. These chosen lengths are a teaching example.
[Primer synthesis and handoff in human Pol α–primase, 2023](https://doi.org/10.1016/j.jmb.2023.168330)

### Supercoiling and topoisomerase II

Unwinding overwinds the DNA ahead of each fork. The helix ahead winds visibly
tighter until topoisomerase II acts. Drawn after its structure, it lies along
the duplex it binds: a dimer, an ATPase N-gate on one side, the C-gate on the
other, the G-segment through the DNA gate between. It captures a crossing
duplex (the T-segment, seen end-on), cuts both strands of the G-segment four
nucleotides apart with two tyrosines that hold the cut ends, passes the
T-segment through the break into the C-gate, reseals the break and releases
it; the helix ahead then relaxes. Human TOP2A relaxes positive supercoils
rapidly, consistent with action ahead of forks; TOP1, which nicks one strand
and lets the DNA swivel, relieves the same strain and is described in the sheet.
[Wu et al., 2011, PDB 3QX3](https://www.rcsb.org/structure/3QX3),
[McClendon et al., 2005](https://doi.org/10.1074/jbc.M503320200)

### Fragment size and the local window

Eukaryotic Okazaki fragments are commonly about 100–200 nucleotides. Two
fragments at the short end of that range fit the window.
[NCBI Bookshelf, DNA Replication Mechanisms](https://www.ncbi.nlm.nih.gov/books/NBK26850/)

### RNA removal before ligation

The next fragment reaches the earlier fragment's RNA primer. Pol δ extends
while displacing that primer in three strokes, pausing while FEN1 removes each
short flap. Only after those RNA bases are replaced does a nick remain for
ligase. The simulation exposes that nick between model positions 89 and 90,
then joins the backbone. Fragment 0 processes fragment −1's primer the same
way, out of view, and each fork's first fragment does so at the origin.

The illustrated short-flap route is one route. Human biochemical work shows
that primer removal can be slow and that RNase H2 can facilitate it; DNA2 also
participates in processing some flaps. The information sheet mentions these
alternatives. [Raducanu et al., 2022](https://doi.org/10.1038/s41467-022-34751-2)

Human structural work places Lig1 around nicked DNA and shows how PCNA supports
its coordination with FEN1. The most recent primer remains RNA: its replacement
requires a later fragment outside this example.
[Blair et al., 2022, Lig1 regulation by PCNA](https://doi.org/10.1038/s41467-022-35475-z)

## Visual language

- The same warm dark ground and lit molecular material as Protein Analysis →
  Ribosome. Colours come from theme tokens (`ReplicationInks`).
- One colour per strand: grey parental, teal new DNA, amber RNA; each strand's
  bases and phosphate beads wear its colour. The three stay at least 20 ΔE00
  apart for normal vision and through protan, deutan and tritan simulation.
  Proteins are muted, one hue family each; multi-chain proteins (PCNA, MCM2–7,
  topo II, ORC with Cdc6, RFC) show their chains as tints of that hue.
- Rings (PCNA, MCM2–7, RFC, ORC) are drawn in two halves, the far half before
  the DNA and the near half after it, so the DNA threads the hole. Other
  proteins are folded envelopes with cut faces exposing the DNA inside.
- At the origin, the lines between paired bases count their hydrogen bonds.
- Words never lie on the DNA, a protein or other words. A label's line
  leaves it on the side facing what it names, so it never crosses the
  label. Two names that share a place take turns rather than overlap.
- Labels can be hidden. The information sheet explains the model and links
  primary structures and experimental research.

## Smooth motion

Every value on screen is a continuous function of playback time, so the
animation cannot flicker:

- The model keeps exact, continuous strand ends (`DaughterPiece`): a strand
  grows and a primer is replaced continuously, never a whole base at once.
- A template's pairing with its new strand is a continuous field: it winds in
  behind a growing 3′ end, unwinds past a 5′ end, and closes as two pieces
  meet. A step at each fragment's 5′ end had made the template jump 20 design
  units sideways, the kinks at the primers.
- Strands are sampled at fixed positions on the DNA plus their exact ends; a
  grid that slid with the camera had made every strand end shimmer.
- New bases grow in as a strand's end passes them, and RNA gives way to DNA
  gradually only at a displacement front. Everything that arrives or leaves
  (RPA, clamps, enzymes, flaps, nicks, labels) eases in and out.
- The chapter clock, fork travel and synthesis are monotone cubics, so speeds
  never jump at a chapter boundary or a polymerase handover.

`ReplicationStaging` stages every element as keyed, continuous values, and
`replication_smoothness_test` walks the whole tour at 60 fps and fails on any
jump, pop, kink or camera jolt.

## Deliberate simplifications

The renderer samples every fifth base and compresses spacing to expose a useful
part of the mechanism on a phone. Helical pitch, protein dimensions and
distances between enzymes are illustrative. The two forks mirror each other.
The educational clock expands different reactions by different amounts, so it
should not be converted into a biological rate. It omits chromatin, most
accessory factors, explicit kinase action and proofreading.

## Implementation and checks

`genome_replication.dart` owns the sequence, origin, fork travel, strand
pieces, primer replacement and the timing of initiation and topoisomerase II.
`replication_tour.dart` maps the 212-second tour to that model.
`replication_camera.dart` frames each chapter and eases between views.
`replication_staging.dart` stages everything shown; `replication_scene.dart`
draws it, the lower fork as a turned pass. `replication_rings.dart` and
`replication_topo.dart` draw the ring proteins and topoisomerase II. Pictures
are recorded once and disposed with the screen.

The domain checks cover primer composition, synthesis after unwinding, opposite
extension directions, RNA replacement before sealing, the remaining final
primer, the origin's symmetry, the hand-over from the bubble to the tour, and
topoisomerase II's order (the T-segment only crosses a cut, open gate).
Widget checks cover navigation, autoplay, pause, phase seeking, replay, reduced
motion, lifecycle changes, the research sheet, the side scrubber and small or
enlarged-text layouts. Camera checks cover working-site visibility, continuity,
tracking and the whole-fork override. `replication_labels_test` stages the tour
every quarter second on a tall and a narrow phone, measures each close-up label
in the app's font, and fails if it lies on DNA, a protein, other words or off
the frame.

To capture the real screen at 390 and 320 logical pixels:

```sh
REPLICATION_DESIGN_SHOTS=/tmp/replication flutter test test/replication_design_render_check.dart
```
