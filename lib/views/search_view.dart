import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/search_controller.dart';
import '../core/format.dart';
import '../core/medicine_form.dart';
import '../core/navigation_mode.dart';
import '../models/medicine.dart';
import '../widgets/feedback.dart';
import '../widgets/featured_medicine_tile.dart';
import '../widgets/medicine_card.dart';
import 'detail_view.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  late final MedicineSearchController _controller;
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();

  static const _forms = MedicineForm.selectable;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<MedicineSearchController>();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels > _scroll.position.maxScrollExtent - 240) {
      _controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? scheme.surfaceContainerHigh
                    : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.25
                          : 0.05,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: TextField(
                controller: _text,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ঔষধ, জেনেরিক বা কোম্পানির নাম…',
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: scheme.primary,
                    size: 24,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(
                        () => _controller.query.value.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                tooltip: 'মুছুন',
                                onPressed: () {
                                  _text.clear();
                                  _controller.query.value = '';
                                  _controller.onQueryChanged('');
                                },
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                      ),
                      IconButton(
                        tooltip: 'ফিল্টার',
                        onPressed: _openFilters,
                        icon: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: _controller.hasFilters
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                onChanged: _controller.onQueryChanged,
                onSubmitted: (value) => _controller.search(),
              ),
            ),
          ),
          Obx(() {
            if (!_controller.searched.value && !_controller.hasFilters) {
              return const SizedBox.shrink();
            }
            return SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final form in _forms)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Obx(
                        () => FilterChip(
                          label: Text(form.label),
                          selected: _controller.dosageForm.value == form.key,
                          onSelected: (selected) => _controller.setDosageForm(
                            selected ? form.key : '',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
          Obx(() {
            if (!_controller.hasFilters) return const SizedBox(height: 4);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (_controller.company.value.isNotEmpty)
                    InputChip(
                      label: Text('কোম্পানি: ${_controller.company.value}'),
                      onDeleted: () => _controller.setCompany(''),
                    ),
                  if (_controller.generic.value.isNotEmpty)
                    InputChip(
                      label: Text('জেনেরিক: ${_controller.generic.value}'),
                      onDeleted: () => _controller.setGeneric(''),
                    ),
                  TextButton(
                    onPressed: _controller.clearFilters,
                    child: const Text('সব ফিল্টার মুছুন'),
                  ),
                ],
              ),
            );
          }),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final isLoading = _controller.loading.value;
      if (isLoading && _controller.results.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: LoadingList(count: 6),
        );
      }
      if (_controller.error.value.isNotEmpty) {
        return ErrorState(
          message: _controller.error.value,
          onRetry: _controller.search,
        );
      }
      if (!_controller.searched.value) return _defaultView(context);
      if (_controller.results.isEmpty) {
        return EmptyState(
          icon: Icons.search_off_rounded,
          title: 'কোনো ঔষধ পাওয়া যায়নি',
          message:
              'অন্য নামে চেষ্টা করুন, বানান বদলান, অথবা ফিল্টার সরিয়ে দিন।',
          action: _controller.hasFilters
              ? FilledButton.tonal(
                  onPressed: _controller.clearFilters,
                  child: const Text('ফিল্টার মুছুন'),
                )
              : null,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading) const LinearProgressIndicator(minHeight: 2.5),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
            child: Row(
              children: [
                Icon(
                  Icons.local_pharmacy_outlined,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${bn(_controller.total.value)}টি ঔষধ পাওয়া গেছে',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                16,
                6,
                16,
                GestureNavigation.shellContentBottomPadding(context),
              ),
              itemCount: _controller.results.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == _controller.results.length) {
                  if (_controller.loadingMore.value) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (_controller.hasMore) {
                    return Center(
                      child: TextButton(
                        onPressed: _controller.loadMore,
                        child: const Text('আরও ফলাফল'),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        'সব ফলাফল দেখানো হয়েছে',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }
                final medicine = _controller.results[index];
                return MedicineCard(
                  medicine: medicine,
                  onTap: () => _open(medicine),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  /// খোলার অবস্থান: প্রথমে প্রচলিত ঔষধের তালিকা, তারপর সার্চ ইতিহাস।
  Widget _defaultView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        GestureNavigation.shellContentBottomPadding(context),
      ),
      children: [
        Obx(() {
          if (_controller.featuredLoading.value &&
              _controller.featured.isEmpty) {
            return const LoadingList(count: 8);
          }
          if (_controller.featured.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_pharmacy_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'বাংলাদেশে প্রচলিত প্রয়োজনীয় ঔষধ',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${bn(_controller.featured.length)}টি',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'নাপা, প্যারাসিটামল, ভিটামিন সি — প্রতিদিনের সবচেয়ে প্রচলিত '
                'ঔষধগুলো। প্রতিটি তালিকা থেকে বিস্তারিত, বিকল্প ও ব্যবহারবিধি দেখুন।',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              for (final medicine in _controller.featured)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: FeaturedMedicineTile(
                    medicine: medicine,
                    onTap: () => _open(medicine),
                  ),
                ),
            ],
          );
        }),
        if (_controller.history.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'আপনার আগের সার্চের ঔষধ',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _controller.clearHistory,
                child: const Text('ইতিহাস মুছুন'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          if (_controller.recentMedicines.isEmpty)
            Text(
              'আগের সার্চগুলোর সাথে মিলে এমন ঔষধ পাওয়া যায়নি। '
              'নতুন নাম লিখে খুঁজুন।',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            for (final medicine in _controller.recentMedicines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MedicineCard(
                  medicine: medicine,
                  onTap: () => _open(medicine),
                ),
              ),
          const SizedBox(height: 16),
          Text(
            'সাম্প্রতিক সার্চ',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final term in _controller.history)
                ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 15),
                  label: Text(term),
                  onPressed: () {
                    _text.text = term;
                    _controller.useHistoryTerm(term);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _openFilters() async {
    final result =
        await showModalBottomSheet<({String company, String generic})>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => _SearchFilterSheet(
            initialCompany: _controller.company.value,
            initialGeneric: _controller.generic.value,
          ),
        );
    if (result != null) {
      _controller.company.value = result.company;
      _controller.generic.value = result.generic;
      _controller.applyFilters();
    }
  }

  void _open(Medicine medicine) {
    _controller.rememberCurrentQuery();
    Get.to(() => MedicineDetailView(medicine: medicine));
  }
}

class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet({
    required this.initialCompany,
    required this.initialGeneric,
  });

  final String initialCompany;
  final String initialGeneric;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late final TextEditingController _company;
  late final TextEditingController _generic;

  @override
  void initState() {
    super.initState();
    _company = TextEditingController(text: widget.initialCompany);
    _generic = TextEditingController(text: widget.initialGeneric);
  }

  @override
  void dispose() {
    _company.dispose();
    _generic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              'ফিল্টার',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _company,
              decoration: const InputDecoration(
                labelText: 'কোম্পানি',
                hintText: 'যেমন: Square',
                prefixIcon: Icon(Icons.factory_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _generic,
              decoration: const InputDecoration(
                labelText: 'জেনেরিক',
                hintText: 'যেমন: Paracetamol',
                prefixIcon: Icon(Icons.science_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context, (company: '', generic: ''));
                    },
                    child: const Text('মুছুন'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, (
                      company: _company.text.trim(),
                      generic: _generic.text.trim(),
                    )),
                    child: const Text('প্রয়োগ করুন'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
