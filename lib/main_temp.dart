import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/theme.dart';
import 'controllers/assistant_controller.dart';
import 'controllers/favorites_controller.dart';
import 'controllers/home_controller.dart';
import 'controllers/learning_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/search_controller.dart';
import 'controllers/settings_controller.dart';
import 'core/app_config.dart';
import 'core/storage.dart';
import 'data/ai_dao.dart';
import 'data/app_database.dart';
import 'data/learning_dao.dart';
import 'data/learning_repository.dart';
import 'data/medicine_dao.dart';
import 'services/backup_service.dart';
import 'services/assistant_knowledge.dart';
import 'services/medicine_api.dart';
import 'services/oxion_assistant.dart';
import 'services/sync_service.dart';
import 'views/redesign_progress_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStorage.init();

  try {
    final db = await AppDatabase.open();
    final medicineDao = MedicineDao(db, pageSize: AppConfig.searchPageSize);
    final learningDao = LearningDao(db);
    final aiDao = AiDao(db);
    final learningRepository = LearningRepository(learningDao);
    final settings = SettingsController(db);
    final api = MedicineApi(baseUrl: () => settings.apiBase.value);
    final sync = SyncService(api: api, db: db, dao: medicineDao);
    final backup = BackupService(db);
    final assistantKnowledge = AssistantKnowledge(
      learningRepository,
      medicineDao,
    );
    final assistant = OxionAssistant();

    Get.put(db, permanent: true);
    Get.put(medicineDao, permanent: true);
    Get.put(learningRepository, permanent: true);
    Get.put(aiDao, permanent: true);
    Get.put(settings, permanent: true);
    Get.put(sync, permanent: true);
    Get.put(backup, permanent: true);
    Get.put(
      HomeController(medicineDao, learningRepository, sync, db, settings),
      permanent: true,
    );
    Get.put(LearningController(learningRepository), permanent: true);
    Get.put(FavoritesController(medicineDao), permanent: true);
    Get.put(MedicineSearchController(medicineDao), permanent: true);
    Get.put(NavigationController(), permanent: true);

    // Cloud AI assistant: knowledge grounding, the OxionAI client, and
    // the chat controller. All permanent so the tab and profile deep-links
    // share one conversation and one client.
    Get.put(assistantKnowledge, permanent: true);
    Get.put(assistant, permanent: true);
    Get.put(
      AssistantController(assistantKnowledge, assistant, aiDao),
      permanent: true,
    );

    runApp(const PharmaPathApp());
  } catch (error) {
    runApp(FatalApp(message: '$error'));
  }
}

class PharmaPathApp extends StatelessWidget {
  const PharmaPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    return Obx(
      () => GetMaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: switch (settings.themeMode.value) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        home: const RedesignProgressView(), // Temporary: Show progress view
        defaultTransition: Transition.cupertino,
      ),
    );
  }
}

class FatalApp extends StatelessWidget {
  const FatalApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('ফার্মাপাথ চালু করা যায়নি'),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
