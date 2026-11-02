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
                  'longest.',
            ),
            paragraph(
              'Shift',
              'Input x is each frame less its last place, target y each frame less '
                  'its first: under each place lies the token after it, which the place '
                  'is trained to predict without seeing it. Only x goes into the model; '
                  'y is the answer key its guesses are graded against, '
                  '${trace.targetCount} targets in the batch, all at once; padding is '
                  'ignored.',
            ),
            paragraph(
              'Embedding',
              'Each id picks its row of the token embedding, ${model.width} learned '
                  'numbers for each of the ${trace.vocab.length} tokens, and each place '
                  'adds its own row of the position embedding, one for each of '
                  '${model.context} places; the sum, ${model.width} numbers a place, is x0, '
                  'the residual stream as the first block reads it.',
            ),
            paragraph(
              'Scores',
              'Each block first evens out each place\'s row (LayerNorm): its numbers less '
                  'their mean, over their standard deviation, then a learned scale and shift for each '
                  'column. Learned weights make one query, one key and one value of '
                  '${model.width} numbers from that row, the same weights at every place, '
                  'and cut each into ${spelled(model.heads)} equal slices, one for each '
                  'head: ${trace.headSize} numbers a head, which is why the width must '
                  'divide by the heads. A place\'s query is scored against each key up to '
                  'its own, number by number, summed and divided by √${trace.headSize}, the '
                  'root of a head\'s size, which keeps the scores on one scale however wide '
                  'a head is; softmax makes the scores shares. Without the division the '
                  'top place would take most of the share.',
            ),
            paragraph(
              'Attention',
              'Each head hands the place its shares of the places\' values, never of '
                  'those after it, number by number: number 1 of its answer is each '
                  'place\'s value number 1 times its share, summed, and so on. The heads\' '
                  'answers, side by side, are mixed back to ${model.width} numbers and added '
                  'to the stream.',
            ),
            paragraph(
              'Feed-forward',
              'Then the block evens each row out again and passes every place, on its own, '
                  'through the same small network: ${model.width} numbers in, '
                  '${model.feedForward} neurons, each a weighted sum through GELU, and '
                  '${model.width} out, added to the stream.',
            ),
            paragraph(
              'Forward',
              'Each block after the first runs the same two parts on the rows the one before '
                  'left, with weights, and so maps, of its own. '
                  'Every part reads a place\'s row as it stands and adds its output to it, so after '
                  'the ${spelled(model.layers)} blocks the row is x0 plus what each of the '
                  '${spelled(2 * model.layers)} parts added. A final LayerNorm, with a scale and shift '
                  'of its own, evens it out once more, and the output layer reads that row.'
                  '${config.dropout == 0 ? ' Dropout is off for this run, so the forward pass drawn is the one trained.' : ''}',
            ),
            paragraph(
              'Predict',
              'The output layer, one linear layer, has a row of ${model.width} weights and a '
                  'bias for each of the ${trace.vocab.length} tokens. A place\'s last row times a '
                  'token\'s weights, summed, plus its bias, is that token\'s score, its logit: '
                  'high where the two agree in sign and size. <pad> and <bos> can never come '
                  'next, so theirs are set to −∞; softmax raises e to each of the other '
                  '$allowed and divides each by their sum, probabilities that add to one. '
                  'Every place makes its guess at once, with the same weights. On the map each '
                  'probability is a square, its area that share of its slot, so a place\'s squares '
                  'add up to one slot; the slot of the token that came next is lit.',
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
