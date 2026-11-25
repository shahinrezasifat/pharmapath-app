import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/medicine_detail_controller.dart';
import '../services/ai_learning_tools.dart';

/// Slide-up AI explanation panel for one medicine.
///
/// Opened by "বিস্তারিত ব্যাখ্যা" on the detail page. The text is generated once
/// per medicine and kept in the local `ai_cache`, so reopening the panel — even
/// on a plane — is instant, and the reader can always ask for a fresh answer.
void showMedicineExplanationSheet(
  BuildContext context,
  MedicineDetailController controller,
) {
  // Kick off generation before the sheet animates in, so the spinner and the
  // answer appear inside the same frame budget.
  if (controller.explanation.isEmpty &&
      controller.explanationError.isEmpty &&
      !controller.explaining.value) {
    controller.loadExplanation();
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ExplanationSheet(controller: controller),
  );
}

class _ExplanationSheet extends StatefulWidget {
  const _ExplanationSheet({required this.controller});

  final MedicineDetailController controller;

  @override
  State<_ExplanationSheet> createState() => _ExplanationSheetState();
}

class _ExplanationSheetState extends State<_ExplanationSheet> {
  late final TextEditingController _questionController;

  MedicineDetailController get controller => widget.controller;

  /// The four headings the prompt mandates; anything else is body text.
  static const Set<String> _headings = {
    'কেন এই ওষুধ',
    'কীভাবে খাবেন',
    'কী এড়াবেন',
    'সাধারণ ভুল ধারণা',
  };

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _sendQuestion() {
    final question = _questionController.text.trim();
    if (question.isEmpty || controller.answeringMedicineChat.value) return;
    _questionController.clear();
    setState(() {});
    controller.askAboutMedicine(question);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => ColoredBox(
        color: scheme.surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'বিস্তারিত ব্যাখ্যা',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          controller.subtitle.isEmpty
                              ? controller.brandName
                              : '${controller.brandName} — ${controller.subtitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'বন্ধ করুন',
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  children: [
                    if (controller.explaining.value &&
                        controller.explanation.isEmpty)
                      const LinearProgressIndicator(minHeight: 3),
                    if (controller.explanation.value.trim().isNotEmpty)
                      ..._body(context, controller.explanation.value)
                    else
                      _explanationUnavailable(context),
                    const SizedBox(height: 22),
                    Text(
                      'এই ওষুধ নিয়ে প্রশ্ন করুন',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final turn in controller.medicineChat)
                      _chatBubble(context, turn.role, turn.text),
                    if (controller.answeringMedicineChat.value)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    if (controller.medicineChatError.value.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          controller.medicineChatError.value,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                  ],
                );
              }),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _questionController,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendQuestion(),
                        decoration: const InputDecoration(
                          hintText: 'এই ওষুধ সম্পর্কে প্রশ্ন লিখুন',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Obx(() {
                      final answering = controller.answeringMedicineChat.value;
                      return IconButton.filled(
                        tooltip: 'প্রশ্ন পাঠান',
                        onPressed: answering ? null : _sendQuestion,
                        icon: const Icon(Icons.send_rounded),
                      );
                    }),
                  ],
                ),
              ),
            ),
            // Educational-use footer, always visible while the panel is open.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AiLearningTools.disclaimer,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _explanationUnavailable(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          if (!controller.explaining.value) ...[
            Icon(
              Icons.cloud_off_outlined,
              size: 30,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              controller.explanationError.value.isEmpty
                  ? AiLearningTools.offlineNotice
                  : controller.explanationError.value,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: controller.explaining.value
                  ? null
                  : () => controller.loadExplanation(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('আবার চেষ্টা করুন'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chatBubble(BuildContext context, String role, String text) {
    final scheme = Theme.of(context).colorScheme;
    final isAi = role == 'ai';
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isAi
              ? scheme.surfaceContainerHighest
              : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isAi ? scheme.onSurface : scheme.onPrimaryContainer,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  /// Renders the Bangla explanation: mandated headings as bold section titles,
  /// '•' lines as bullets, everything else as plain paragraphs.
  List<Widget> _body(BuildContext context, String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final widgets = <Widget>[];
    if (controller.explanationCached.value) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(Icons.offline_bolt_rounded, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'সংরক্ষিত ব্যাখ্যা — ইন্টারনেট ছাড়াই দেখানো হচ্ছে',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final clean = line.replaceFirst('•', '').trim();
      if (_headings.contains(clean)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              clean,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
        );
      } else if (line.startsWith('•')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    clean,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectableText(
              line,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
        );
      }
    }
    widgets.add(
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => controller.loadExplanation(),
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('নতুন করে ব্যাখ্যা লিখুন'),
        ),
      ),
    );
    return widgets;
  }
}
