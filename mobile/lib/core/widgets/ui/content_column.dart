import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Maximum width of the readable content column on wide screens.
const double kContentMaxWidth = 720;

/// Side gutter on phones (screen padding from the Global Constraints).
const double kContentGutter = 16;

/// Horizontal offset of the content column inside an area [width] wide:
/// [minInset] on narrow screens, and enough to centre a [maxWidth] column on
/// wide ones.
///
/// Every content primitive below uses this, so an [AppBar] title, a list and
/// a [ContentColumn] all start at the same x. Pass the width of the area the
/// screen actually gets (the shell's rail takes part of the window), e.g. from
/// a [LayoutBuilder]; [ContentAppBar] and [SliverContentColumn] do it for you.
double contentInset(
  double width, {
  double maxWidth = kContentMaxWidth,
  double minInset = kContentGutter,
}) => math.max(minInset, (width - maxWidth) / 2);

/// Symmetric horizontal padding that centres a [maxWidth] column, plus
/// optional [top] / [bottom]. Handy for `ListView(padding: ...)`, which keeps
/// the scrollbar and mouse-wheel area at full width.
EdgeInsets contentPadding(
  double width, {
  double maxWidth = kContentMaxWidth,
  double top = 0,
  double bottom = 0,
}) {
  final side = contentInset(width, maxWidth: maxWidth);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Centres [child] in a column at most [maxWidth] wide.
///
/// The horizontal part of [padding] is the minimum gutter (applied on
/// phones); on wide screens the gutter grows so the column is centred and
/// its left edge equals [contentInset]. The vertical part is applied as is.
/// The child is stretched to the column width (`min(width - 32, 720)`).
///
/// For a scrollable list prefer [contentPadding] or [SliverContentColumn]
/// so the scroll area stays full width.
class ContentColumn extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ContentColumn({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: kContentGutter),
  });

  @override
  Widget build(BuildContext context) {
    final pad = padding.resolve(Directionality.of(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite) {
          return Padding(padding: pad, child: child);
        }
        final centred = (width - maxWidth) / 2;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            math.max(pad.left, centred),
            pad.top,
            math.max(pad.right, centred),
            pad.bottom,
          ),
          // The child always gets the full column width.
          child: SizedBox(width: double.infinity, child: child),
        );
      },
    );
  }
}

/// Sliver counterpart of [ContentColumn] for `CustomScrollView`.
class SliverContentColumn extends StatelessWidget {
  final Widget sliver;
  final double maxWidth;
  final double top;
  final double bottom;

  const SliverContentColumn({
    super.key,
    required this.sliver,
    this.maxWidth = kContentMaxWidth,
    this.top = 0,
    this.bottom = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverPadding(
        padding: contentPadding(
          constraints.crossAxisExtent,
          maxWidth: maxWidth,
          top: top,
          bottom: bottom,
        ),
        sliver: sliver,
      ),
    );
  }
}

/// [AppBar] whose title and actions line up with the centred content column.
///
/// Drop-in for the common `AppBar(title:, actions:)` case: it measures its
/// own width and sets `titleSpacing` / `actionsPadding` to [contentInset].
/// With a back button (or [leading]) the title keeps the default spacing
/// after it and only the actions are aligned.
class ContentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final double? toolbarHeight;
  final double maxWidth;

  const ContentAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.toolbarHeight,
    this.maxWidth = kContentMaxWidth,
  });

  @override
  Size get preferredSize => Size.fromHeight(
    (toolbarHeight ?? kToolbarHeight) + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final hasLeading =
        leading != null ||
        (automaticallyImplyLeading && (route?.impliesAppBarDismissal ?? false));
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = contentInset(constraints.maxWidth, maxWidth: maxWidth);
        // IconButtons carry ~12 px of internal padding around a 24 px icon;
        // subtract it so the glyph, not the hit box, meets the column edge.
        final actionsInset = math.max(4.0, inset - 12);
        return AppBar(
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          title: title,
          titleSpacing: hasLeading ? null : inset,
          actions: actions,
          actionsPadding: EdgeInsets.only(right: actionsInset),
          bottom: bottom,
          toolbarHeight: toolbarHeight,
        );
      },
    );
  }
}
