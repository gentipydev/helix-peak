import 'package:flutter/material.dart';

import '../../../shared/format.dart';
import '../domain/training_trace.dart';
import 'lm_format.dart';

/// What each stage of a training step does, on demand: one paragraph a stage,
/// and what made the run. Every number is the run's own.
class LmAboutSheet extends StatelessWidget {
  const LmAboutSheet({required this.trace, super.key});

  final TrainingTrace trace;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final TraceModel model = trace.model;
    final TraceConfig config = trace.config;
    final int peptides = trace.peptides.length;
    final int allowed = trace.allowed.length;
    final bool firstsDiffer =
        trace.peptides.map((TracePeptide p) => p.sequence[0]).toSet().length == peptides;
    final Object? torch = trace.provenance['torch'];
    final Object? device = trace.provenance['device'];

    Widget paragraph(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: text.titleSmall),
          const SizedBox(height: 6),
          Text(body, style: text.bodyMedium),
        ],
      ),
    );

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: <Widget>[
            Text('How this model learns', style: text.titleLarge),
            const SizedBox(height: 22),
            paragraph(
              'This run',
              'HelixPeekLM, ${grouped(model.parameters)} parameters: '
                  '${spelled(model.layers)} blocks of ${spelled(model.heads)} attention '
                  'heads, ${model.width} numbers a position. Trained by the engine\'s own '
                  'step for ${trace.steps.count} steps'
                  '${device is String ? ' on $device' : ''}, seed ${config.seed}'
                  '${torch is String ? ', PyTorch $torch' : ''}, with every number '
                  'recorded as it went. This page plays the recording; recorded again, '
                  'the run is the same, byte for byte.',
            ),
            paragraph(
              'The data',
              '${spelledLeading(peptides)} peptides, ${trace.residues} residues, from '
                  'the curated proteins: '
                  '${trace.peptides.map((TracePeptide p) => '${p.source.label} (${p.source.gene})').join(', ')}. '
                  'All are trained on and none held out: so few cannot be split into '
                  'training and validation, so this run shows a model learning, not one '
                  'generalising.',
            ),
            paragraph(
              'Tokenise',
              '${trace.vocab.length} tokens: <pad>, <bos>, <eos> and the twenty '
                  'residues. Each peptide is framed by <bos> and <eos> and padded to the '
                  'longest, and each id is trained to predict the one after it: '
                  '${trace.targetCount} targets in the batch, padding ignored.',
            ),
            paragraph(
              'Forward',
              'Each id picks its row of a learned embedding, and each position its '
                  'own; their sum, ${model.width} numbers, is the residual stream. Each '
                  'block normalises it (LayerNorm), lets every position read the ones '
                  'before it, never those after, through ${spelled(model.heads)} '
                  'attention heads, and adds what it read; then it passes each position '
                  'through a feed-forward layer (${model.width} → ${model.feedForward} '
                  '→ ${model.width}, GELU) and adds that too.'
                  '${config.dropout == 0 ? ' Dropout is off for this run, so the forward pass drawn is the one trained.' : ''}',
            ),
            paragraph(
              'Predict',
              'A final LayerNorm, then one linear layer, gives each position '
                  '${trace.vocab.length} scores, its logits. <pad> and <bos> can never '
                  'come next, so theirs are set to −∞, and softmax turns the other '
                  '$allowed into probabilities that sum to one.',
            ),
            paragraph(
              'Loss',
              'Cross-entropy: −ln of the probability given to the token that came '
                  'next, averaged over the batch\'s ${trace.targetCount} targets. '
                  'Guessing evenly scores ln $allowed = ${nats(trace.uniform)} nats; '
                  'counting residues, ${nats(trace.unigram)}; the residue before, '
                  '${nats(trace.bigram)}. No model can score under '
                  '${nats(trace.floor)} on these peptides: from <bos> alone nothing says '
                  'which one comes'
                  '${firstsDiffer ? ', so each first residue costs ln $peptides' : ''}.',
            ),
            paragraph(
              'Backward',
              'Backpropagation carries the loss\'s gradient back through every layer '
                  'by the chain rule. At the output it is p − y: the probabilities, '
                  'less one at the token that came next. Where all the gradients\' norm '
                  'is over ${config.gradClip}, every one is scaled down to it.',
            ),
            paragraph(
              'Update',
              'AdamW moves each weight by about the learning rate times its '
                  'gradient\'s running mean over its running size, so steps are even '
                  'where gradients are not, and shrinks the weight matrices by '
                  '${config.weightDecay} of the rate each step. The rate warms up over '
                  '${config.warmupSteps} steps to ${scientific(config.learningRate)}, '
                  'then falls on a cosine to ${scientific(config.etaMin)}.',
            ),
            paragraph(
              'Loop',
              'The same batch, ${trace.steps.count} times. Every step\'s loss, '
                  'gradients and output layer are kept; ${spelled(trace.checkpoints.length)} '
                  'steps keep every activation too: the first, the first below each '
                  'baseline and below one nat and a tenth of one, and the last.',
            ),
          ],
        ),
      ),
    );
  }
}
