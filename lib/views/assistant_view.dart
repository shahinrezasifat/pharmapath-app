import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/assistant_controller.dart';
import '../core/ai_doctors.dart';
import '../core/app_config.dart';
import '../core/format.dart';
import '../core/navigation_mode.dart';
import '../core/storage.dart';
import 'detail_view.dart';
import '../widgets/glass.dart';

/// The AI assistant screen — styled as a telemedicine consultation with
/// ডা. ফার্মাপাথ.
///
/// Behaviour mirrors a real doctor: symptoms trigger a multi-turn interview
/// (progress + confidence shown live) and no medicine is named until the
/// history is complete. Answers come from OxionAI cloud models grounded in
/// our data; the profile button in the header switches models instantly.
/// The composer keeps two visible helpers—a paperclip (photos, voice files
/// and documents) and a mic that records a voice note in place—and the
/// doctor always replies in Bangla, no matter which script the patient
/// types in. When the API is unavailable the deterministic knowledge
/// answer still shows.
class AssistantView extends StatefulWidget {
  const AssistantView({super.key, this.seed});

  final String? seed;

  @override
  State<AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<AssistantView> {
  final TextEditingController _text = TextEditingController();
  late final AssistantController _controller = Get.find<AssistantController>();
  Worker? _draftSync;

  @override
  void initState() {
    super.initState();
    // One source of truth for the composer: whatever the controller leaves in
    // [AssistantController.draft]—a sent message, a tapped chip, a seeded
    // question—is what the field shows. A typed answer can then never sit in
    // the box while different text goes out, nor be wiped without being sent.
    _draftSync = ever<String>(_controller.draft, (value) {
      if (_text.text != value) _text.text = value;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.applySeed(widget.seed);
      if (mounted && _controller.draft.value.isNotEmpty) {
        _text.text = _controller.draft.value;
      }
      _controller.loadModels();
      _maybeAskLanguagePreference();
    });
  }

  @override
  void dispose() {
    _draftSync?.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _controller.draft.value = value;
    _controller.suggest(value);
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    // Only clear the field when the message was actually accepted — pressing
    // enter while the doctor is still answering must not swallow the text.
    if (await _controller.send()) _text.clear();
  }

  /// First open of the chat: politely asks whether the patient wants to
  /// write in Bangla or English. Either choice is honoured for reading—
  /// the doctor's replies stay Bangla-only, exactly as promised in the sheet.
  Future<void> _maybeAskLanguagePreference() async {
    var asked = true;
    try {
      asked = AppStorage.box.read(AppStorage.kAiLanguageAsked) == true;
    } catch (_) {
      return; // Storage not ready (e.g. tests)—skip the greeting quietly.
    }
    if (asked || !mounted) return;
    try {
      await AppStorage.box.write(AppStorage.kAiLanguageAsked, true);
    } catch (_) {
      // Flag could not be persisted; still ask once this session.
    }
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _DoctorAvatar(size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ডা. ফার্মাপাথ-এ স্বাগতম',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'আপনি কি বাংলায় কথা বলতে চান অথবা ইংরেজিতে?',
              style: Theme.of(sheetContext).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'আপনি বাংলা, ইংরেজি বা মিশ্র ভাষায় লিখলেও ডাক্তার '
              'সব বুঝবেন; তবে উত্তর সবসময় সাবলীল বাংলায়ই আসবে।',
              style: Theme.of(sheetContext).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop('bn'),
                    icon: const Icon(Icons.record_voice_over_rounded),
                    label: const Text('বাংলায়'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop('en'),
                    icon: const Icon(Icons.translate_rounded),
                    label: const Text('English'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      await AppStorage.box.write(AppStorage.kAiLanguage, choice);
    } catch (_) {}
    Get.snackbar(
      'ভাষা পছন্দ',
      choice == 'bn'
          ? 'চমৎকার! সম্পূর্ণ পরামর্শ বাংলায়ই চলবে।'
          : 'ঠিক আছে—আপনি ইংরেজিতেই লিখুন, ডাক্তার সব বুঝবেন; '
                'তবে উত্তর বাংলায়ই আসবে।',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check hardware window insets directly via View.of(context) so keyboard
    // presence is correctly detected even if the parent Scaffold consumed viewInsets.
    final hasKeyboard =
        View.of(context).viewInsets.bottom > 0 ||
        MediaQuery.viewInsetsOf(context).bottom > 0;
    // When keyboard is open, stick cleanly 8dp above the keyboard.
    // When keyboard is closed, sit right above the floating navbar.
    final navBarTop =
        GestureNavigation.navBarHeight +
        GestureNavigation.bottomSpacing(
          context,
          safeMarginAboveGesture: 10,
          fullscreenMargin: 14,
        );
    final bottomSpace = hasKeyboard ? 8.0 : (navBarTop + 10.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // The parent ShellView already resizes for the keyboard; prevent double-insetting.
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        safe: false,
        child: SafeArea(
          top: true,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _ConsultHeader(
                  controller: _controller,
                  onNewChat: _controller.newChat,
                  onHistory: () => _showSessionsSheet(context),
                  onClear: _controller.messages.isEmpty
                      ? null
                      : _controller.clearChat,
                ),
                _InterviewBanner(controller: _controller),
                Expanded(child: _buildThread()),
                _buildSuggestions(),
                _QuickReplies(controller: _controller),
                _PendingStrip(controller: _controller),
                _InputBar(
                  text: _text,
                  controller: _controller,
                  onChanged: _onChanged,
                  onSend: _send,
                ),
                SizedBox(height: bottomSpace),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThread() {
    return Obx(() {
      final items = <Object>[..._controller.messages];
      if (_controller.thinking.value) items.add(_typingToken);
      if (items.isEmpty) {
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: const [_EmptyState()],
        );
      }
      return ListView.builder(
        reverse: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[items.length - 1 - index];
          if (item == _typingToken) return const _ThinkingRow();
          final turn = item as ChatTurn;
          return _Bubble(turn: turn);
        },
      );
    });
  }

  Widget _buildSuggestions() {
    return Obx(() {
      final suggestions = _controller.suggestions;
      if (_controller.draft.value.trim().isEmpty || suggestions.isEmpty) {
        return const SizedBox.shrink();
      }
      return SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final disease in suggestions)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(
                    Icons.medical_information_outlined,
                    size: 16,
                  ),
                  label: Text(disease),
                  onPressed: () {
                    _text.text = disease;
                    _onChanged(disease);
                  },
                ),
              ),
          ],
        ),
      );
    });
  }

  /// Bottom sheet listing every saved chat: tap to open, trash to delete.
  Future<void> _showSessionsSheet(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text(
                  'কথোপকথন',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Obx(() {
                final sessions = _controller.sessions;
                if (sessions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('এখনো কোনো কথোপকথন নেই।')),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final active =
                          session.id == _controller.activeConversationId.value;
                      return ListTile(
                        selected: active,
                        selectedTileColor: scheme.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Icon(
                          active
                              ? Icons.chat_bubble_rounded
                              : Icons.chat_bubble_outline_rounded,
                          color: active ? scheme.primary : null,
                        ),
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${bn(session.messages)}টি বার্তা · '
                          '${_sessionWhen(session.updatedAt)}',
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _controller.openChat(session.id);
                        },
                        trailing: IconButton(
                          tooltip: 'মুছে ফেলুন',
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: scheme.error,
                          ),
                          onPressed: () => _controller.deleteChat(session.id),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  static String _sessionWhen(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(time.year, time.month, time.day);
    final diff = today.difference(that).inDays;
    if (diff <= 0) return 'আজ';
    if (diff == 1) return 'গতকাল';
    return '${time.day}/${time.month}';
  }
}

const _typingToken = '__typing__';

/// Round doctor avatar with a live "online" presence dot.
/// When [initial] is given (the selected doctor's name letter) it replaces the
/// generic stethoscope glyph, so a model switch is visible on the avatar too.
class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({this.size = 44, this.initial});

  final double size;
  final String? initial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letter = initial;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.9),
                  scheme.secondaryContainer,
                ],
              ),
            ),
            child: letter == null
                ? Icon(
                    Icons.medical_services_rounded,
                    color: scheme.onPrimary,
                    size: size * 0.5,
                  )
                : Center(
                    child: Text(
                      letter,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimary,
                        fontSize: size * 0.44,
                        height: 1.0,
                      ),
                    ),
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.tertiary,
                border: Border.all(
                  color: scheme.surface,
                  width: size >= 56 ? 2.5 : 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Telemedicine top bar: doctor identity on the left; chat actions and the
/// profile button (which opens the live AI-model switcher) on the right.
class _ConsultHeader extends StatelessWidget {
  const _ConsultHeader({
    required this.controller,
    this.onNewChat,
    this.onHistory,
    this.onClear,
  });

  final AssistantController controller;
  final Future<void> Function()? onNewChat;
  final VoidCallback? onHistory;
  final Future<void> Function()? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // The live doctor identity: the persona behind the currently
          // selected model, swapped the instant the model panel picks one.
          Expanded(
            child: Obx(() {
              final model = controller.selectedModel.value;
              final doctor = model.isEmpty ? null : doctorFor(model);
              return Row(
                children: [
                  _DoctorAvatar(size: 44, initial: doctor?.initial),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor?.name ?? 'ডা. ফার্মাপাথ',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: .2,
                              ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 13,
                              color: scheme.tertiary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                doctor == null
                                    ? 'অনলাইন · AI টেলিমেডিসিন সহায়ক'
                                    : '${doctor.rank} · AI টেলিমেডিসিন',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
          if (onHistory != null || onNewChat != null || onClear != null)
            // One tidy menu instead of three loose buttons.
            PopupMenuButton<String>(
              tooltip: 'চ্যাট মেনু',
              icon: Icon(
                Icons.more_vert_rounded,
                color: scheme.onSurfaceVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'new':
                    onNewChat?.call();
                  case 'history':
                    onHistory?.call();
                  case 'clear':
                    onClear?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'new',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.add_comment_outlined),
                    title: Text('নতুন পরামর্শ'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'history',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.history_rounded),
                    title: Text('কথোপকথন'),
                  ),
                ),
                if (onClear != null)
                  const PopupMenuItem(
                    value: 'clear',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_sweep_outlined),
                      title: Text('এই চ্যাট মুছুন'),
                    ),
                  ),
              ],
            ),
          // Profile / settings: opens the live model switcher — tapping any
          // model takes effect on the very next answer, no restart, and the
          // choice is persisted across sessions.
          Obx(
            () => IconButton(
              tooltip:
                  'ডাক্তার প্যানেল — মডেল বদল (${controller.selectedModel.value})',
              onPressed: () => _showModelSheet(context, controller),
              icon: Icon(
                Icons.account_circle_outlined,
                color: scheme.primary,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live model switcher modal, opened from the header's profile button.
Future<void> _showModelSheet(
  BuildContext context,
  AssistantController controller,
) async {
  // Automatically trigger model analysis to fetch latest verified free models
  controller.loadModels();
  final scheme = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  const _DoctorAvatar(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ডা. ফার্মাপাথ — মডেল প্যানেল',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer.withValues(
                                  alpha: 0.55,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '১০০% ফ্রি',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'শুধু সক্রিয় ফ্রি মডেলগুলো উপলব্ধ — কোনো পেইড ক্রেডিট বা চার্জ কাটবে না।',
                          style: Theme.of(sheetContext).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Obx(
                    () => IconButton(
                      tooltip: 'তালিকা রিফ্রেশ',
                      onPressed: controller.modelsLoading.value
                          ? null
                          : controller.loadModels,
                      icon: controller.modelsLoading.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Obx(() {
              final models = controller.availableModels;
              // Read the selection inside the Obx body itself: lazily built
              // list items don't subscribe, so the check-mark could go stale.
              final selected = controller.selectedModel.value;
              final error = controller.modelsError.value;
              if (models.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    error.isNotEmpty
                        ? error
                        : 'মডেলের তালিকা আসেনি — রিফ্রেশ চাপুন।',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                );
              }
              // Best doctor first: the panel is ordered by clinical depth.
              final doctors = rankDoctors(models.toList());
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                  itemCount: doctors.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    final active = doctor.model == selected;
                    return _DoctorCard(
                      doctor: doctor,
                      starred: index == 0,
                      active: active,
                      onTap: () {
                        final changed = doctor.model != selected;
                        controller.selectModel(doctor.model);
                        Navigator.of(sheetContext).pop();
                        // Immediate proof the switch landed—the header name
                        // changes too, but a word confirms it unmistakably.
                        if (changed) {
                          Get.snackbar(
                            'ডাক্তার বদল',
                            '${doctor.name} — ${doctor.rank} এখন থেকে '
                                'আপনাকে পরামর্শ দিচ্ছেন।',
                            snackPosition: SnackPosition.BOTTOM,
                            duration: const Duration(seconds: 3),
                          );
                        }
                      },
                    );
                  },
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

/// One doctor-persona row in the model panel: avatar, name, style line,
/// raw model id, capability badges and the seniority score.
class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.starred,
    required this.active,
    required this.onTap,
  });

  final AiDoctor doctor;
  final bool starred;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.primaryContainer.withValues(alpha: 0.45) : null,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? scheme.primary.withValues(alpha: 0.65)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Initial-in-circle avatar; the top-ranked doctor wears a badge.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: active
                            ? [scheme.primary, scheme.secondaryContainer]
                            : [
                                scheme.surfaceContainerHighest,
                                scheme.surfaceContainerHigh,
                              ],
                      ),
                    ),
                    child: Text(
                      doctor.initial,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: active ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                  ),
                  if (starred)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        size: 18,
                        color: scheme.tertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            doctor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: active ? scheme.primary : null,
                                ),
                          ),
                        ),
                        if (starred) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.tertiary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'সেরা ডাক্তার',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.tertiary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${doctor.rank} · ${doctor.blurb}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (doctor.model.contains(':free'))
                          _miniChip(
                            context,
                            scheme,
                            'ফ্রি',
                            icon: Icons.check_circle_outline_rounded,
                            tint: scheme.primary,
                          ),
                        _miniChip(
                          context,
                          scheme,
                          doctor.model.split('/').last.replaceAll(':free', ''),
                        ),
                        if (modelHasVision(doctor.model))
                          _miniChip(
                            context,
                            scheme,
                            'ছবি বোঝে',
                            icon: Icons.visibility_rounded,
                          ),
                        if (modelHasAudio(doctor.model))
                          _miniChip(
                            context,
                            scheme,
                            'ভয়েস বোঝে',
                            icon: Icons.mic_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                active ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 20,
                color: active ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _miniChip(
    BuildContext context,
    ColorScheme scheme,
    String label, {
    IconData? icon,
    Color? tint,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    constraints: const BoxConstraints(maxWidth: 220),
    decoration: BoxDecoration(
      color: (tint ?? scheme.surfaceContainerHighest).withValues(
        alpha: tint != null ? 0.16 : 0.7,
      ),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: tint ?? scheme.onSurfaceVariant),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tint ?? scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Live consultation progress while the doctor's interview is running —
/// question counter and a confidence meter, so the patient understands why
/// answers, not prescriptions, come first.
class _InterviewBanner extends StatelessWidget {
  const _InterviewBanner({required this.controller});

  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      if (!controller.interviewActive.value) return const SizedBox.shrink();
      final percent = (controller.confidence.value * 100).round();
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.checklist_rounded, color: scheme.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'সাক্ষাৎকার — ${controller.interviewTopic.value}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: controller.confidence.value,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'প্রশ্ন ${bn(controller.questionNumber.value)}/'
                    '${bn(controller.questionTotal.value)} · আস্থা $percent% · '
                    'তথ্য শেষ হলেই ঔষধের পরামর্শ—আগে নয়।',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Tap-to-answer chips for the doctor's structured questions.
class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.controller});

  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final replies = controller.quickReplies;
      if (!controller.interviewActive.value ||
          replies.isEmpty ||
          controller.thinking.value) {
        return const SizedBox.shrink();
      }
      return SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final reply in replies)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: ActionChip(
                  avatar: Icon(
                    Icons.alternate_email_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(reply),
                  onPressed: () => controller.answerQuickly(reply),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// Thumbnails of images/voice notes queued for the next message.
class _PendingStrip extends StatelessWidget {
  const _PendingStrip({required this.controller});

  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final items = controller.pending;
      if (items.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                child: Stack(
                  children: [
                    _AttachmentTile(
                      kind: items[i].isImage
                          ? _AttachmentKind.image
                          : _AttachmentKind.audio,
                      name: items[i].name,
                      bytes: items[i].bytes,
                      path: items[i].path,
                      width: 56,
                      height: 56,
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => controller.removePending(i),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.error,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: scheme.onError,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}

enum _AttachmentKind { image, audio }

/// One attachment rendered as a tappable tile. Live attachments show from
/// in-memory bytes; reloaded ones fall back to the saved file path.
class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.kind,
    required this.name,
    required this.width,
    required this.height,
    this.bytes,
    this.path,
  });

  final _AttachmentKind kind;
  final String name;
  final double width;
  final double height;
  final Uint8List? bytes;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget content;
    if (kind == _AttachmentKind.image) {
      content = _imageBody(scheme);
    } else {
      content = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.graphic_eq_rounded, color: scheme.primary, size: 20),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: kind == _AttachmentKind.image
          ? () => _showFullImage(context)
          : null,
      child: content,
    );
  }

  Widget _imageBody(ColorScheme scheme) {
    Widget? image;
    if (bytes != null) {
      // Live attachment: render straight from the picked bytes.
      image = Image.memory(
        bytes!,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _placeholder(scheme),
      );
    } else if (path != null && path!.isNotEmpty && !kIsWeb) {
      image = File(path!).existsSync()
          ? Image.file(
              File(path!),
              fit: BoxFit.cover,
              width: width,
              height: height,
              errorBuilder: (_, _, _) => _placeholder(scheme),
            )
          : _placeholder(scheme);
    }
    if (image == null) return _placeholder(scheme);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: width, height: height, child: image),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(
      Icons.broken_image_outlined,
      color: scheme.onSurfaceVariant,
      size: 22,
    ),
  );

  void _showFullImage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: bytes != null
                    ? Image.memory(bytes!)
                    : (path != null && path!.isNotEmpty && !kIsWeb
                          ? Image.file(File(path!))
                          : const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.white54,
                              size: 48,
                            )),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});

  final ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = turn.isUser;
    if (user) return _userBubble(context, scheme);
    return _doctorBubble(context, scheme);
  }

  Widget _doctorBubble(BuildContext context, ColorScheme scheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DoctorAvatar(size: 30),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      'ডা. ফার্মাপাথ',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          turn.text,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurface, height: 1.45),
                        ),
                        if (turn.medicines.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final medicine in turn.medicines)
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.medication_outlined,
                                    size: 16,
                                  ),
                                  label: Text(medicine.brandName),
                                  onPressed: () => Get.to(
                                    () =>
                                        MedicineDetailView(medicine: medicine),
                                    preventDuplicates: false,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userBubble(BuildContext context, ColorScheme scheme) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (turn.attachments.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  for (final attachment in turn.attachments)
                    _AttachmentTile(
                      kind: attachment.isImage
                          ? _AttachmentKind.image
                          : _AttachmentKind.audio,
                      name: attachment.name,
                      path: attachment.path,
                      width: 72,
                      height: 72,
                    ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            SelectableText(
              turn.text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onPrimaryContainer, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

/// Typing indicator: three bouncing dots while the doctor composes the
/// answer — the classic telemedicine "doctor is writing" feel.
class _ThinkingRow extends StatefulWidget {
  const _ThinkingRow();

  @override
  State<_ThinkingRow> createState() => _ThinkingRowState();
}

class _ThinkingRowState extends State<_ThinkingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DoctorAvatar(size: 30),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final t = _pulse.value;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
                              child: _dot(scheme.primary, _phase(t, i)),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ডাক্তার লিখছেন…',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _phase(double t, int i) {
    final shifted = (t - i * 0.2 + 1) % 1;
    return shifted < 0.5 ? shifted * 2 : (1 - shifted) * 2;
  }

  static Widget _dot(Color color, double phase) => Container(
    width: 7 + 3 * phase,
    height: 7 + 3 * phase,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.45 + 0.55 * phase),
    ),
  );
}

/// Consultation composer: one rounded pill holding the two helpers the
/// patient needs in reach—a paperclip (photos / voice files / documents)
/// and a mic that records a voice note in place—plus the message field
/// and the send action. While recording, the field becomes a live red
/// timer strip until the note is stopped and sent.
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.text,
    required this.controller,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController text;
  final AssistantController controller;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Paperclip — files, photos, documents.
          Obx(
            () => IconButton(
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              padding: EdgeInsets.zero,
              tooltip: 'ছবি, ফাইল বা ডকুমেন্ট যোগ করুন',
              onPressed: controller.attaching.value || controller.thinking.value
                  ? null
                  : () => _showAttachSheet(context),
              icon: controller.attaching.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.attach_file_rounded,
                      color: scheme.primary,
                      size: 22,
                    ),
            ),
          ),
          // 2. Mic — tap to record, tap again to stop and send.
          Obx(
            () => IconButton(
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              padding: EdgeInsets.zero,
              tooltip: controller.recording.value
                  ? 'রেকর্ডিং থামিয়ে ভয়েস নোট পাঠান'
                  : 'ভয়েস নোট রেকর্ড করুন',
              onPressed: controller.thinking.value
                  ? null
                  : controller.toggleRecording,
              icon: Icon(
                controller.recording.value
                    ? Icons.stop_circle_rounded
                    : Icons.mic_rounded,
                color: controller.recording.value
                    ? scheme.error
                    : scheme.primary,
                size: controller.recording.value ? 26 : 22,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Obx(() {
              if (controller.recording.value) {
                return _RecordingPanel(seconds: controller.recordSeconds.value);
              }
              return TextField(
                controller: text,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onChanged: onChanged,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: controller.interviewActive.value
                      ? 'প্রশ্নের উত্তর লিখুন…'
                      : 'লক্ষণ বা ওষুধের নাম লিখুন…',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              );
            }),
          ),
          const SizedBox(width: 4),
          Obx(
            () => FilledButton(
              onPressed:
                  controller.thinking.value ||
                      controller.recording.value ||
                      (controller.draft.value.trim().isEmpty &&
                          controller.pending.isEmpty)
                  ? null
                  : onSend,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                minimumSize: const Size(40, 40),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.send_rounded, size: 19),
            ),
          ),
        ],
      ),
    );
  }

  /// Attachment chooser — visual symptom photos (camera/gallery), saved
  /// voice/audio files and readable documents. The service forwards each
  /// to the model when it supports vision or audio input; text files are
  /// quoted into the message itself.
  Future<void> _showAttachSheet(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        Future<void> close(void Function() action) async {
          Navigator.of(sheetContext).pop();
          action();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text(
                  'সংযোগ করুন',
                  style: Theme.of(sheetContext).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  'ক্ষত, র‍্যাশ বা রিপোর্টের ছবি, অডিও ফাইল, আর txt/csv-এর '
                  'মতো লেখার ডকুমেন্ট পাঠাতে পারেন—ছবি ও অডিও '
                  'ভিশন/অডিও-সক্ষম মডেল বিশ্লেষণ করবে, লেখার ফাইল '
                  'বার্তার সাথে যুক্ত হবে।',
                  style: Theme.of(sheetContext).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_camera_rounded,
                  color: scheme.primary,
                ),
                title: const Text('ক্যামেরায় ছবি তুলুন'),
                onTap: () =>
                    close(() => controller.pickImage(fromCamera: true)),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_rounded,
                  color: scheme.primary,
                ),
                title: const Text('গ্যালারি থেকে ছবি'),
                onTap: () => close(() => controller.pickImage()),
              ),
              ListTile(
                leading: Icon(Icons.description_rounded, color: scheme.primary),
                title: const Text('ফাইল / ডকুমেন্ট (ছবি, অডিও, txt/csv)'),
                onTap: () => close(controller.pickFiles),
              ),
              ListTile(
                leading: Icon(Icons.graphic_eq_rounded, color: scheme.primary),
                title: const Text('সংরক্ষিত অডিও ফাইল পাঠান'),
                onTap: () => close(controller.pickAudio),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Live red strip inside the composer while the mic is recording: a soft
/// pulsing dot, the elapsed/maximum time, and how to stop.
class _RecordingPanel extends StatefulWidget {
  const _RecordingPanel({required this.seconds});

  final int seconds;

  @override
  State<_RecordingPanel> createState() => _RecordingPanelState();
}

class _RecordingPanelState extends State<_RecordingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final limit = AppConfig.assistantMaxVoiceSeconds;
    final m = widget.seconds ~/ 60;
    final ss = (widget.seconds % 60).toString().padLeft(2, '0');
    final lm = limit ~/ 60;
    final lss = (limit % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.error.withValues(
                  alpha: 0.45 + 0.55 * _pulse.value,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'রেকর্ডিং…  ${bn('$m:$ss')} / ${bn('$lm:$lss')} — থামাতে '
              'আবার মাইকে চাপুন, নোট সরাসরি পাঠিয়ে দেওয়া হবে।',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.error, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AssistantController>();
    final scheme = Theme.of(context).colorScheme;
    final starters = [
      (
        icon: Icons.thermostat_rounded,
        label: 'আমার জ্বর হয়েছে, কী করব?',
        accent: scheme.primary,
      ),
      (
        icon: Icons.favorite_rounded,
        label: 'উচ্চ রক্তচাপে কোন ঔষধ?',
        accent: scheme.secondary,
      ),
      (
        icon: Icons.water_drop_rounded,
        label: 'Diarrhea-র জন্য কী খাব?',
        accent: scheme.tertiary,
      ),
      (
        icon: Icons.medical_services_rounded,
        label: 'গ্যাস্ট্রিকের ঘরোয়া ও ঔষধ সমাধান?',
        accent: scheme.primary,
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Welcome Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Obx(() {
                      final model = controller.selectedModel.value;
                      final doctor = model.isEmpty ? null : doctorFor(model);
                      return _DoctorAvatar(size: 58, initial: doctor?.initial);
                    }),
                    const SizedBox(height: 12),
                    Text(
                      'ডা. ফার্মাপাথ-এ স্বাগতম',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'আপনার শারীরিক সমস্যা এক বাক্যে বলুন। ডাক্তার তথ্য বিশ্লেষণ করে সঠিক ঔষধ ও খাওয়ার নিয়ম জানাবেন।',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _FeatureBadge(
                          icon: Icons.chat_bubble_outline_rounded,
                          text: 'লক্ষণ বিশ্লেষণ',
                          scheme: scheme,
                        ),
                        _FeatureBadge(
                          icon: Icons.mic_none_rounded,
                          text: 'ভয়েস নোট',
                          scheme: scheme,
                        ),
                        _FeatureBadge(
                          icon: Icons.medication_outlined,
                          text: 'ডোজ নির্দেশিকা',
                          scheme: scheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Suggestion Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'দ্রুত পরামর্শ শুরু করুন',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 3. Starters
              Column(
                children: [
                  for (final s in starters)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => controller.ask(s.label),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: s.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    s.icon,
                                    size: 18,
                                    color: s.accent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    s.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurface,
                                        ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({
    required this.icon,
    required this.text,
    required this.scheme,
  });

  final IconData icon;
  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
