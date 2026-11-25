import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/lesson_ai_controller.dart';
import '../core/json_utils.dart' show stripHtml;

import 'package:ai_doctor_module/ai_doctor.dart';

/// Opens the lesson mini-chat: a compact overlay where the reader asks about
/// *this* lesson and the model answers from the lesson text only.
void showLessonAskAiSheet(BuildContext context, LessonAiController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _LessonChatSheet(controller: controller),
  );
}

class _LessonChatSheet extends StatefulWidget {
  const _LessonChatSheet({required this.controller});

  final LessonAiController controller;

  /// Tappable starters according to PRD Section 13.1
  static const List<String> _starters = [
    'এই বিষয়টি সহজ বাংলায় বোঝাও',
    'মূল কথাগুলো সহজ করে বলুন',
    'এই পাঠের গুরুত্বপূর্ণ বিষয়গুলো কী?',
    'বাস্তব উদাহরণ দিয়ে বুঝিয়ে দিন',
    'কোন জরুরি লক্ষণে অবিলম্বে হাসপাতালে যেতে হবে?',
    'সাধারণত মানুষ কোন ভুলটি সবচেয়ে বেশি করে?',
  ];

  @override
  State<_LessonChatSheet> createState() => _LessonChatSheetState();
}

class _LessonChatSheetState extends State<_LessonChatSheet> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    widget.controller.ask(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    // Leave room for the keyboard without letting the sheet cover the page.
    final sheetHeight = ((media.size.height - media.viewInsets.bottom) * 0.82)
        .clamp(320.0, media.size.height * 0.92);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            _header(context),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                final chat = widget.controller.chat;
                if (chat.isEmpty) return _intro(context);
                // Reversed list: newest turn sits next to the input and the
                // view stays pinned to it without manual scroll handling.
                return ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  itemCount: chat.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final turn = chat[chat.length - 1 - index];
                    return _Bubble(turn: turn);
                  },
                );
              }),
            ),
            Obx(() {
              final error = widget.controller.chatError.value;
              final busy = widget.controller.answering.value;
              if (error.isEmpty && !busy) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: Row(
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: scheme.error,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        busy ? 'ফার্মাপাথ ভাবছে…' : error,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: busy ? scheme.onSurfaceVariant : scheme.error,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            _composer(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = widget.controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 0),
      child: Row(
        children: [
          Icon(Icons.forum_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'এই পাঠ নিয়ে জানুন',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  controller.lesson.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (controller.hasChat)
            IconButton(
              tooltip: 'কথোপকথন মুছুন',
              onPressed: () => controller.clearChat(),
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          IconButton(
            tooltip: 'বন্ধ করুন',
            onPressed: () => Get.back(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  /// The empty state: what this chat is grounded in, plus one-tap starters.
  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      children: [
        Text(
          'উত্তরগুলো শুধু এই পাঠের তথ্য থেকে তৈরি হয় '
          '(“${widget.controller.lesson.title}”). পাঠের বাইরের কোনো '
          'নতুন পরামর্শ এখানে আসে না।',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'চাপ দিয়ে শুরু করুন',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final starter in _LessonChatSheet._starters)
              ActionChip(
                label: Text(starter),
                avatar: Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onPressed: () => _send(starter),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: () {
            final lesson = widget.controller.lesson;
            final course = widget.controller.course;
            Get.back();
            Get.to(
              () => AiDoctorHomePage(
                initialQuestion:
                    'কোর্স: ${course.title}\nপাঠ: ${lesson.title}\n'
                    '${stripHtml(lesson.body)}',
              ),
            );
          },
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('পুরো সহায়ককে জিজ্ঞাসা করুন'),
        ),
      ],
    );
  }

  Widget _composer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 3,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'এই পাঠ সম্পর্কে আপনার প্রশ্ন…',
                hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Obx(
            () => FilledButton(
              onPressed: widget.controller.answering.value
                  ? null
                  : () => _send(),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Icon(Icons.send_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});

  final LessonChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fromUser = turn.role == 'user';
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: fromUser
                ? scheme.primaryContainer.withValues(alpha: 0.7)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(fromUser ? 16 : 6),
              bottomRight: Radius.circular(fromUser ? 6 : 16),
            ),
          ),
          child: SelectableText(
            turn.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.65,
              color: fromUser ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
