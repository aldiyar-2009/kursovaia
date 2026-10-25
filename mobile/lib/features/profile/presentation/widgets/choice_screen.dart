import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';

/// One option of a [ChoiceScreen].
class ChoiceOption<T> {
  final T value;
  final String title;
  final String? subtitle;

  const ChoiceOption({required this.value, required this.title, this.subtitle});
}

/// Settings sub-page with a single-choice list and a check mark on the
/// selected row. Rebuilds from [listenable] so the mark follows the setting.
class ChoiceScreen<T> extends StatelessWidget {
  final String title;
  final List<ChoiceOption<T>> options;
  final T Function() selected;
  final ValueChanged<T> onSelected;
  final Listenable listenable;

  const ChoiceScreen({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.listenable,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ContentAppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (context, constraints) => ListenableBuilder(
          listenable: listenable,
          builder: (context, _) {
            final current = selected();
            return ListView(
              padding: contentPadding(constraints.maxWidth, top: 8, bottom: 32),
              children: [
                ListGroup(
                  children: [
                    for (final option in options)
                      Semantics(
                        selected: option.value == current,
                        inMutuallyExclusiveGroup: true,
                        child: ListRow(
                          title: option.title,
                          subtitle: option.subtitle,
                          trailing: option.value == current
                              ? Icon(
                                  Icons.check,
                                  color: context.palette.accent,
                                  size: 20,
                                )
                              : null,
                          onTap: () => onSelected(option.value),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
