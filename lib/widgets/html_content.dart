import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../core/json_utils.dart';

class HtmlContent extends StatelessWidget {
  const HtmlContent(this.content, {super.key, this.style});

  final String content;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    if (!looksLikeHtml(trimmed)) {
      return Text(
        trimmed,
        style:
            style ??
            Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
      );
    }
    return HtmlWidget(
      trimmed,
      textStyle:
          style ??
          Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
    );
  }
}
