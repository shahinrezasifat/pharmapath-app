import 'package:get/get.dart';

import '../data/medicine_dao.dart';
import '../models/medicine.dart';

class FavoritesController extends GetxController {
  FavoritesController(this._dao);

  final MedicineDao _dao;

  final RxList<Medicine> items = <Medicine>[].obs;
  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = '';
    try {
      items.assignAll(await _dao.favorites());
    } catch (e) {
      error.value = 'ফেভারিট পড়া যায়নি: $e';
    } finally {
      loading.value = false;
    }
  }

  Future<void> remove(int id) async {
    await _dao.toggleFavorite(id);
    items.removeWhere((e) => e.id == id);
  }
}
