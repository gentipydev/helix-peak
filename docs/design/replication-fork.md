# Genome replication: a close view of one fork

![Helicase close-up in the guided replication animation](replication-fork.png)

## Experience

LAB → Replication opens an animation immediately. There is no protein picker,
record download or gene-specific error list. Old `/lab/replication/<slug>` links
redirect to this view. The subject is a human nuclear replication fork in an
illustrative 200-base-pair stretch, with two 100-nucleotide Okazaki fragments.

The camera opens on the whole fork, visits each working site, and returns to
both daughter duplexes after ligation. Playback takes 2 min 40 s at 1×, with
0.25×, 0.5×, 1.5× and 2× available. The shared Ribosome transport
provides pause, replay and chapter stepping. The walk's vertical scrubber sits
beside the scene: dragging pauses and seeks, with a bubble showing the time and
phase. The header holds the subject and window size, leaving more room for the
molecular view. Short captions describe the action below it.
Reduced motion starts on a still. Backgrounding pauses playback, and opening the
research sheet also pauses it. “Whole fork” keeps the entire mechanism in view
at the current playback time; “Follow steps” resumes the guided framing.

### Camera chapters

| Playback | Close-up |
| --- | --- |
| 0 s | The whole replication fork |
| 4 s | CMG helicase separating the parental strands |
| 14 s | RPA protecting exposed single strands |
| 24 s | Topoisomerase ahead of the fork |
| 34 s | Primase building the RNA start |
| 44 s | Pol α extending the primer and handing off to Pol δ with PCNA |
| 58 s | Pol ε and continuous leading-strand synthesis |
| 70 s | Pol δ moving away from the fork on the lagging strand |
| 88 s | The next RNA–DNA primer |
| 100 s | A second Okazaki fragment growing towards the first |
| 126 s | Primer replacement and the FEN1 flap |
| 140 s | DNA ligase closing the nick |
| 152 s | Both daughter duplexes, each with an old and a new strand |

Each camera move takes the previous chapter's last 2.5 seconds, with smooth
acceleration and deceleration. The working site is already in view when a
chapter is selected. Tracking continues as a fragment grows. Zoom ranges from
2.15× to 3×; labels keep their size and only name the relevant structures.
DNA extends to the edges of the close-up on tall phones as well.

These are views of concurrent processes at an established fork. The tour does
not imply that topoisomerase starts only after helicase or RPA. The final chapter
shows the local result while the fork continues; the newest RNA primer awaits
the next fragment beyond this example.

## Research and its consequences

### Human replisome architecture

The bacterial Pol III labels in the supplied AVIF are not appropriate for this
human-genome view. Human cryo-EM resolves CMG associated with Pol ε and fork
protection factors. Here CMG follows the leading template through its central
channel; the lagging template exits outside it. Pol ε remains close behind.
The cutaway separates components enough to see DNA enter and leave each enzyme.
The molecular envelopes borrow the Ribosome's lighting and folded lobes; they
are original procedural illustrations, not imported atomic surfaces.
[Jones et al., 2021, core human replisome, PDB 7PFO](https://www.rcsb.org/structure/7PFO)

### Single-strand protection

The close-up names RPA as the human SSB. Human RPA binds exposed single-stranded
DNA; the bacterial SSB protein is not substituted into this human scene.
[Human RPA binding to single-stranded DNA, Wyka et al., 2003](https://pubmed.ncbi.nlm.nih.gov/14596605/)

### Priming and strand direction

Human and yeast structures position primase near the excluded lagging template.
The animation gives each fragment an RNA start, followed by a short Pol α DNA
extension and transfer to Pol δ with PCNA. The polymerase exchange takes about two
seconds, so the clamp and outgoing enzyme remain visible during
handoff. Leading synthesis proceeds towards the fork; lagging synthesis proceeds
away from it. Both add to a growing 3′ end.
[Jones et al., 2023, Molecular Cell](https://doi.org/10.1016/j.molcel.2023.06.035),
[human primase–replisome structure, PDB 8B9D](https://www.rcsb.org/structure/8B9D)

The model chooses 10 RNA nucleotides and 20 Pol α DNA nucleotides per primer.
Experiments on human Pol α–primase support a 7–10-nt RNA start and approximately
20-nt DNA extension. These chosen lengths are a teaching example, not fixed
lengths for every primer in a cell.
[Primer synthesis and handoff in human Pol α–primase, 2023](https://doi.org/10.1016/j.jmb.2023.168330)

### Fragment size and the local window

Eukaryotic Okazaki fragments are commonly about 100–200 nucleotides. Two fragments
at the short end of that range fit the requested window. Origin assembly occurs
before this view begins: the opening frame already has an active leading strand
and exposed lagging template. The supplied illustration references inform the
readable fork shape, but this scene does not imply that one fork copies an entire
chromosome or that replication follows protein-coding boundaries.
[NCBI Bookshelf, DNA Replication Mechanisms](https://www.ncbi.nlm.nih.gov/books/NBK26850/)

### RNA removal before ligation

The next fragment reaches the earlier fragment's RNA primer. Pol δ extends while
displacing that primer; FEN1 removes the short flap. Only after those RNA bases
are replaced does a nick remain for ligase. The simulation exposes that nick
between model positions 89 and 90, then joins the backbone.

The illustrated short-flap route is one route. Human biochemical work shows
that primer removal can be slow and that RNase H2 can facilitate it; DNA2 also
participates in processing some flaps. The information sheet mentions these
alternatives. No claim is made that the illustrated route alone accounts for
all primer processing in vivo.
[Raducanu et al., 2022, human Okazaki-fragment maturation](https://doi.org/10.1038/s41467-022-34751-2)

Human structural work places Lig1 around nicked DNA and shows how PCNA supports
its coordination with FEN1. The animated ligase encloses the nick and departs
once the new strand is continuous. The most recent primer remains RNA: its
replacement requires a later fragment outside this example. Finishing the
playback does not mean the chromosome has finished replicating.
[Blair et al., 2022, Lig1 regulation by PCNA](https://doi.org/10.1038/s41467-022-35475-z)

## Visual language

- The same warm dark ground, muted nucleotide palette and lit molecular
  material as Protein Analysis → Ribosome.
- Grey parental backbones, sage new DNA and amber RNA. The colours distinguish
  ancestry and material even while the base colours retain the app's A/T/C/G
  convention.
- Folded protein envelopes, soft depth and exposed working channels. RPA is
  drawn only on unpaired lagging template and clears as synthesis proceeds.
- Free nucleotide particles and drifting primer debris are removed. New bases
  appear on the growing strands; the short RNA flap remains attached at its
  processing site. Arrows make both synthesis directions explicit.
- Continuous shaded paths keep the backbones smooth when magnified. A subtle
  glow marks the active site without adding a floating bead.
- Labels can be hidden. The information sheet explains the model and links
  primary structures and experimental research.

## Deliberate simplifications

The renderer samples every fifth base and compresses spacing to expose a useful
part of the mechanism on a phone. Helical pitch, protein dimensions and distances
between enzymes are illustrative. The position of the leading active site is
an explicit layout choice, not a measured nucleotide separation from CMG.
The underlying model tracks every position, including bases between the
rendered samples. Repeated flanking sequence supplies context beyond the 200-base
teaching sequence. This is not a reference-genome coordinate or a named locus.

DNA paths are spread apart to reveal both strands; the drawing does not impose
a bacterial trombone-loop architecture on the human fork. It omits chromatin,
most accessory factors, origin activation, explicit RFC motion, detailed ATP
chemistry and proofreading. The educational clock expands different reactions
by different amounts, so it should not be converted into a biological rate.

## Implementation and checks

`genome_replication.dart` owns the sequence, synthesis fronts, primer material,
replacement and nick state. `replication_tour.dart` maps the 160-second tour to
that synthesis model. `replication_camera.dart` reads the same state to frame
each machine and ease between views. Every motion, including the camera, stops
when playback stops and is reproduced by seeking. Protein surfaces are recorded once as vector pictures and disposed
with the screen.

The domain checks cover primer composition, complementary bases, synthesis after
unwinding, opposite extension directions, RNA replacement before sealing and the
remaining final primer. Widget checks cover direct and legacy navigation,
autoplay, pause, phase seeking, replay, reduced motion, lifecycle changes, the
research sheet and small or enlarged-text layouts. Screen checks also exercise
the side scrubber inside the scrolling page, phone safe areas through every
phase, and text enlarged to 3.2× on a 320-pixel screen. Legend labels wrap within
the available width. Camera checks cover working-site visibility, continuity
at every chapter boundary, tracking through extension, seeking, reduced motion
and the whole-fork override.

To capture the real screen at 390 and 320 logical pixels:

```sh
REPLICATION_DESIGN_SHOTS=/tmp/replication flutter test test/replication_design_render_check.dart
```

Captures include every camera chapter, the polymerase handoff and the joined
backbone after ligation.

### Validation — 29 September 2026

- `flutter analyze --no-pub`: no issues.
- Full suite: 1,607 passed; 32 platform-dependent tests skipped.
- Camera tests cover every chapter boundary, active-site visibility,
  deterministic seeking and reduced motion.
- Rendered every chapter at 390 and 320 logical pixels, including the polymerase
  handoff, primer replacement, nick and joined backbone.
- Built and inspected the running animation in the iPhone 17 simulator.
