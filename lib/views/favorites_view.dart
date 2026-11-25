import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/favorites_controller.dart';
import '../controllers/navigation_controller.dart';
import '../core/navigation_mode.dart';
import '../widgets/feedback.dart';
import '../widgets/medicine_card.dart';
import 'detail_view.dart';

class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FavoritesController>();
    return Scaffold(
      body: Obx(() {
        if (controller.loading.value && controller.items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingList(count: 5),
          );
        }
        if (controller.error.value.isNotEmpty && controller.items.isEmpty) {
          return ErrorState(
            message: controller.error.value,
            onRetry: controller.load,
          );
        }
        if (controller.items.isEmpty) {
          return EmptyState(
            icon: Icons.favorite_border,
            title: 'এখনো কিছু সংরক্ষিত নেই',
            message: 'ওষুধের পাতায় হার্ট আইকন চাপলে সেটি এখানে জমা হবে এবং অফলাইনে থাকবে।',
            action: FilledButton.tonal(
              onPressed: () => Get.find<NavigationController>().goTo(1),
              child: const Text('ওষুধ খুঁজুন'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              GestureNavigation.shellContentBottomPadding(context),
            ),
            itemCount: controller.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final medicine = controller.items[index];
              return MedicineCard(
                medicine: medicine,
                onTap: () =>
                    Get.to(() => MedicineDetailView(medicine: medicine)),
                trailing: IconButton(
                  tooltip: 'সরান',
                  onPressed: () => controller.remove(medicine.id),
                  icon: const Icon(Icons.close, size: 18),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
