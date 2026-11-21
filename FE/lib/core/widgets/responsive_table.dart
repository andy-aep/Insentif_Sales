import 'package:flutter/material.dart';

/// A wrapper widget that ensures data tables and wide components
/// are horizontally scrollable with visible scrollbar and min-width expansion.
class ResponsiveTableCard extends StatefulWidget {
  final Widget child;
  final double minWidth;

  const ResponsiveTableCard({
    super.key,
    required this.child,
    this.minWidth = 650,
  });

  @override
  State<ResponsiveTableCard> createState() => _ResponsiveTableCardState();
}

class _ResponsiveTableCardState extends State<ResponsiveTableCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final targetMinWidth = constraints.maxWidth > widget.minWidth
            ? constraints.maxWidth
            : widget.minWidth;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: false,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: targetMinWidth),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
