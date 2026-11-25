// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../core/api_exception.dart';
import '../core/clinical_knowledge_engine.dart';
import '../core/json_utils.dart' show stripHtml;
import '../data/medicine_dao.dart';
import '../models/medicine.dart';
import '../services/ai_learning_tools.dart';
import '../services/sync_service.dart';

typedef MedicineChatTurn = ({String role, String text});

class MedicineDetailController extends GetxController {
  MedicineDetailController({
    required Medicine initial,
    required MedicineDao dao,
    required SyncService sync,
    AiLearningTools? ai,
  }) : medicine = initial.obs,
       _dao = dao,
       _sync = sync,
       _ai = ai;

  final Rx<Medicine> medicine;
  final MedicineDao _dao;
  final SyncService _sync;

  /// Bangla translation / explanation helper. Absent in slim builds and tests
  /// that do not register it, where both actions simply stay unavailable.
  final AiLearningTools? _ai;

  final RxBool loadingDetail = false.obs;
  final RxString detailError = ''.obs;
  final RxBool favorite = false.obs;

  /// `MedicineSection.key` → cached or freshly translated Bangla.
  final RxMap<String, String> translations = <String, String>{}.obs;

  final RxBool translating = false.obs;

  /// A transient Bangla status line: progress, a partial-translation warning,
  /// or the offline notice when nothing could be translated.
  final RxString translateNote = ''.obs;

  /// The "বিস্তারিত ব্যাখ্যা" text and its own loading/error state.
  final RxString explanation = ''.obs;
  final RxBool explaining = false.obs;
  final RxString explanationError = ''.obs;

  final RxList<MedicineChatTurn> medicineChat = <MedicineChatTurn>[].obs;
  final RxBool answeringMedicineChat = false.obs;
  final RxString medicineChatError = ''.obs;

  /// True when the visible explanation came from the local cache.
  final RxBool explanationCached = false.obs;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    await _dao.recordView(medicine.value.id);
    favorite.value = await _dao.isFavorite(medicine.value.id);
    await loadDetail();
    if (_ai == null) await refreshTranslation();
  }

  Future<void> loadDetail({bool force = false}) async {
    loadingDetail.value = true;
    detailError.value = '';
    if (!force) {
      try {
        final stored = await _dao.byId(medicine.value.id);
        if (stored != null) {
          medicine.value = stored;
          favorite.value = await _dao.isFavorite(stored.id);
        }
      } on Exception catch (error) {
        debugPrint('Local medicine lookup failed: $error');
        detailError.value = 'সংরক্ষিত ওষুধের তথ্য পড়া যায়নি।';
      } finally {
        loadingDetail.value = false;
      }
      if (_ai != null) await refreshTranslation();
      return;
    }

    try {
      // Refresh is an explicit import into the same local catalogue; opening
      // a medicine page never depends on a separate API database.
      final fresh = await _sync.ensureDetail(medicine.value, force: true);
      medicine.value = fresh;
      favorite.value = await _dao.isFavorite(fresh.id);
    } on ApiException {
      detailError.value = 'ইন্টারনেট থেকে বিস্তারিত আনা যায়নি। সংরক্ষিত তথ্য দেখানো হচ্ছে; সংযোগ এলে আবার চেষ্টা করুন।';
      final cached = await _dao.byId(medicine.value.id);
      if (cached != null) medicine.value = cached;
    } on Exception catch (error) {
      debugPrint('Medicine detail load failed: $error');
      detailError.value =
          'বিস্তারিত তথ্য লোড করা যায়নি। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।';
    } finally {
      loadingDetail.value = false;
    }
    if (_ai != null) await refreshTranslation();
  }

  /// Same-active-ingredient AND same-strength alternatives from other
  /// manufacturers, so a 500 mg brand only ever lists 500 mg replacements.
  Future<List<Medicine>> findSimilar() async {
    final generic = medicine.value.genericName?.trim() ?? '';
    if (generic.isEmpty) return const [];
    return _dao.findSimilarByGeneric(
      generic,
      strength: medicine.value.strength,
      excludeId: medicine.value.id,
    );
  }

  Future<void> toggleFavorite() async {
    favorite.value = await _dao.toggleFavorite(medicine.value.id);
  }

  // ---------------------------------------------------------------------------
  // Bangla translation & detailed explanation
  // ---------------------------------------------------------------------------

  /// Displays translated text when available, otherwise verified Bengali monograph or source text.
  String fieldText(MedicineSection section) {
    final translated = translations[section.key]?.trim();
    if (translated != null && translated.isNotEmpty) {
      return translated;
    }
    final hasBengali = RegExp(r'[\u0980-\u09FF]').hasMatch(section.value);
    if (!hasBengali) {
      final engineVal =
          ClinicalKnowledgeEngine.getClinicalSections(medicine.value)[section.key];
      if (engineVal != null && engineVal.isNotEmpty) {
        return engineVal;
      }
    }
    return section.value;
  }

  int get translatedCount => translations.length;
  int get translationFieldCount => medicine.value.translationFields.length;

  /// The medicine's brand name, kept in its official English packaging typography.
  String get brandName => medicine.value.brandName;

  /// The manufacturer / company name, kept in English.
  String get companyName {
    final company = medicine.value.company?.trim();
    if (company == null || company.isEmpty) return 'Unknown';
    return company;
  }

  /// The active generic name / drug group, kept in English.
  String get genericName => medicine.value.genericName?.trim() ?? '';

  /// The strength, kept in English packaging notation (e.g. 500 mg).
  String get strength => medicine.value.strength?.trim() ?? '';

  /// The dosage form, kept in English (e.g. Tablet, Capsule, Syrup, Suspension).
  String get formLabel {
    final form = medicine.value.dosageForm?.trim();
    if (form != null && form.isNotEmpty) return form;
    return medicine.value.form.name;
  }

  String get subtitle {
    final value = medicine.value;
    return [
      if (genericName.isNotEmpty) genericName,
      if (strength.isNotEmpty) strength,
      if (value.dosageForm?.trim().isNotEmpty ?? false) formLabel,
    ].join(' · ');
  }

  /// The price, kept in standard English format.
  String get priceLabel {
    final value = medicine.value;
    if (value.unitPrice?.trim().isNotEmpty ?? false) {
      final price = value.unitPrice!.trim();
      return '৳ $price';
    }
    if (value.priceText?.trim().isNotEmpty ?? false) {
      return value.priceText!;
    }
    return 'N/A';
  }

  String get packLabel {
    final pack = medicine.value.packSizes?.trim();
    if (pack == null || pack.isEmpty) return '';
    return 'Pack: $pack';
  }

  /// Asks [AiLearningTools] for the fields that are not cached yet. Safe to
  /// call repeatedly: cached sections never hit the network again, and a second
  /// call while one is running is ignored.
  Future<void> refreshTranslation() async {
    final tools = _ai;
    if (tools == null) {
      translateNote.value = AiLearningTools.offlineNotice;
      return;
    }
    if (translating.value) return;
    if (medicine.value.translationFields.isEmpty) return;
    translating.value = true;
    translateNote.value = tools.available
        ? 'বাংলায় অনুবাদ হচ্ছে…'
        : AiLearningTools.offlineNotice;
    try {
      final result = await tools.translateMedicine(medicine.value);
      translations.assignAll(result.fields);
      translateNote.value = result.error;
    } on Exception catch (error) {
      debugPrint('Medicine detail translation failed: $error');
      translateNote.value = 'বাংলা অনুবাদ আনা যায়নি। আবার চেষ্টা করুন।';
    } finally {
      translating.value = false;
    }
  }

  /// Produces (or re-reads from cache) the conversational Bangla explanation
  /// shown in the slide-up panel.
  Future<void> loadExplanation() async {
    if (explaining.value) return;
    final tools = _ai;
    if (tools == null) {
      explanationError.value = AiLearningTools.offlineNotice;
      return;
    }
    explaining.value = true;
    explanationError.value = '';
    try {
      final answer = await tools.explainMedicine(medicine.value);
      if (RegExp(r'[A-Za-z]').hasMatch(stripHtml(answer.text))) {
        explanation.value = '';
        explanationError.value = 'সম্পূর্ণ বাংলা ব্যাখ্যা পাওয়া যায়নি।';
        return;
      }
      explanation.value = answer.text;
      explanationCached.value = answer.cached;
      explanationError.value = answer.ok ? '' : answer.error;
    } on Exception catch (error) {
      debugPrint('Medicine explanation failed: $error');
      explanationError.value = 'ব্যাখ্যা আনা যায়নি। আবার চেষ্টা করুন।';
    } finally {
      explaining.value = false;
    }
  }

  Future<void> askAboutMedicine(String question) async {
    final text = question.trim();
    if (text.isEmpty || answeringMedicineChat.value) return;
    medicineChat.add((role: 'user', text: text));
    medicineChatError.value = '';
    final tools = _ai;
    if (tools == null) {
      medicineChatError.value = AiLearningTools.offlineNotice;
      return;
    }

    answeringMedicineChat.value = true;
    try {
      final history = medicineChat
          .take(medicineChat.length - 1)
          .toList()
          .map(
            (turn) => (
              role: turn.role == 'ai' ? 'assistant' : 'user',
              text: turn.text,
            ),
          )
          .toList();
      final answer = await tools.askAboutMedicine(
        medicine: medicine.value,
        question: text,
        history: history,
      );
      if (answer.ok) {
        medicineChat.add((role: 'ai', text: answer.text));
      } else {
        medicineChatError.value = answer.error.isEmpty
            ? 'উত্তর পাওয়া যায়নি। আবার চেষ্টা করুন।'
            : answer.error;
      }
    } on Exception catch (error) {
      debugPrint('Medicine chat failed: $error');
      medicineChatError.value = 'উত্তর আনা যায়নি। আবার চেষ্টা করুন।';
    } finally {
      answeringMedicineChat.value = false;
    }
  }
}
