import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import 'protein_card.dart';

/// The wait for the list, laid out as the list that replaces it.
///
/// The cards' own surface in the cards' places, breathing while the service
/// is asked, under whatever the list will have over it. What lands takes the
/// places the wait held for it, which is the walk's rule for its own wait
/// (`LoadingView`); that one stood here before, and held a gene map's place
/// where a list arrives.
///
/// It can stand for the best part of a minute: on a first launch the phone
/// holds no list yet, and the service may be asleep. [header] is where the
/// screen says so, in the place its line about the list will take.
class ListWait extends StatefulWidget {
  const ListWait({required this.label, this.header, super.key});

  /// What is being waited for, set as the walk's wait sets its own, where
  /// the first card's name will be.
  final String label;

  /// What stands over the list while it waits: the widget the screen will
  /// put there once the list is in, saying something else meanwhile, so that
  /// the first card lands where the first place was.
  final Widget? header;

  /// A card at rest: a name, a line of figures and two lines of prose.
  static const double _card = 102;

  @override
  State<ListWait> createState() => _ListWaitState();
}

class _ListWaitState extends State<ListWait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Never gone: a place held is still a place at the low end of a breath.
  late final Animation<double> _breath = Tween<double>(
    begin: 0.4,
    end: 1,
  ).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget place = FadeTransition(
      opacity: _breath,
      child: DecoratedBox(
        decoration: ProteinCard.surface(theme.colorScheme),
        child: const SizedBox.expand(),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ?widget.header,
        Expanded(
          // As many places as the screen holds, and no more: the list is
          // lazy, and this one cannot be scrolled past what is on it.
          child: ListView.builder(
            key: const ValueKey<String>('list-wait'),
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemExtent: ListWait._card + AppSpacing.sm,
            itemBuilder: (BuildContext context, int index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: index > 0
                  // Places, not content: nothing here for a screen reader.
                  ? ExcludeSemantics(child: place)
                  : Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        place,
                        // Steady while the place under it breathes, and set
                        // where a card sets its name.
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.topStart,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Flexible(
                                  child: Text(
                                    widget.label,
                                    style: theme.textTheme.labelSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
