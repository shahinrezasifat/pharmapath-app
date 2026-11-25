import 'package:ai_doctor_module/ai_doctor/models.dart';
import 'package:ai_doctor_module/ai_doctor/ai_service.dart';
import 'package:ai_doctor_module/ai_doctor/localization.dart';
import 'package:ai_doctor_module/ai_doctor/pages/patient_form_page.dart';
import 'package:ai_doctor_module/ai_doctor/pages/patient_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('medicine chat prompt uses catalogue context and selected language', () {
    final prompt = aiBuildSystemPrompt(
      p: AiPatient(name: 'Napa', age: 0),
      doc: aiDoctors.first,
      conditions: const [],
      meds: const [],
      allergies: const [],
      medicineContext: 'ব্র্যান্ড: নাপা\nজেনেরিক: প্যারাসিটামল',
      languageCode: 'bn',
    );

    expect(prompt, contains('Reply entirely in Bengali'));
    expect(prompt, contains('ব্র্যান্ড: নাপা'));
    expect(prompt, contains('Do not invent missing facts'));
    expect(prompt, contains('No saved patient profile was selected'));
  });

  testWidgets('medicine chat opens without a patient record', (tester) async {
    AiDoctorConfig.setLanguage('bn');
    await tester.pumpWidget(
      MaterialApp(
        home: AiDoctorChatPage.forMedicine(
          medicineName: 'নাপা',
          medicineContext: 'ব্র্যান্ড: নাপা',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ওষুধ নিয়ে এআই-এর সাথে কথা বলুন'), findsOneWidget);
    expect(find.text('নাপা'), findsOneWidget);
    expect(find.text('আপনার প্রশ্ন লিখুন…'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    expect(find.text('এআই চিকিৎসক বেছে নিন'), findsOneWidget);
    await tester.tap(find.text('ডা. আরিফুল ইসলাম'));
    await tester.pumpAndSettle();
    expect(find.text('ডা. আরিফুল ইসলাম'), findsOneWidget);
  });

  test('patient interface language can be selected in Bengali or English', () {
    String? savedLanguage;
    AiDoctorConfig.onLanguageChanged = (value) => savedLanguage = value;
    AiDoctorConfig.setLanguage('bn');
    expect(aiText('রোগী', 'Patients'), 'রোগী');
    expect(aiLocalizedNumber(36), '৩৬');

    AiDoctorConfig.setLanguage('en');
    expect(savedLanguage, 'en');
    expect(aiText('রোগী', 'Patients'), 'Patients');
    expect(aiLocalizedNumber(36), '36');
    AiDoctorConfig.setLanguage('bn');
    AiDoctorConfig.onLanguageChanged = null;
  });

  group('AiPatient profile data', () {
    test('reads existing patient rows without the new optional fields', () {
      final patient = AiPatient.fromMap({
        'id': 7,
        'name': 'Samira',
        'age': 32,
        'gender': 'Female',
        'relation': 'Self',
      });

      expect(patient.id, 7);
      expect(patient.bloodGroup, isEmpty);
      expect(patient.phone, isEmpty);
      expect(patient.photoPath, isEmpty);
    });

    test('medication schedule survives serialization', () {
      final medication = AiMedication(
        patientId: 3,
        name: 'Paracetamol',
        dose: '2',
        unit: 'tablet',
        timesPerDay: 3,
        dosageForm: 'Tablet',
      );

      final restored = AiMedication.fromMap(medication.toMap());
      expect(restored.dose, '2');
      expect(restored.unit, 'tablet');
      expect(restored.timesPerDay, 3);
      expect(restored.dosageForm, 'Tablet');
    });

    test('round-trips the extended patient profile fields', () {
      final patient = AiPatient(
        id: 8,
        name: 'Rafi',
        age: 12,
        gender: 'Male',
        relation: 'Child',
        bloodGroup: 'B+',
        phone: '01700000000',
        photoPath: '/private/patients/rafi.jpg',
      );

      final restored = AiPatient.fromMap(patient.toMap());
      expect(restored.name, 'Rafi');
      expect(restored.bloodGroup, 'B+');
      expect(restored.phone, '01700000000');
      expect(restored.photoPath, '/private/patients/rafi.jpg');
    });

    test('daily care completion resets by date and serializes cleanly', () {
      final today = DateTime.now();
      final todayKey =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final task = AiDailyTask(
        id: 11,
        patientId: 3,
        title: 'Record blood pressure',
        time: '09:30',
        doneOn: todayKey,
      );

      final restored = AiDailyTask.fromMap(task.toMap());
      expect(restored.isDoneToday, isTrue);
      expect(restored.title, task.title);
      expect(restored.time, task.time);
      expect(restored.copyWith(doneOn: '').isDoneToday, isFalse);
    });

    test('chat image path persists with the message model', () {
      final message = AiChatMessage(
        patientId: 2,
        doctorId: 'vision-doctor',
        role: 'user',
        text: 'Please assess this rash.',
        imagePath: '/private/chat_images/rash.jpg',
      );

      final restored = AiChatMessage.fromMap(message.toMap());
      expect(restored.imagePath, message.imagePath);
      expect(restored.text, message.text);
    });
  });

  testWidgets('patient form follows the selected display language', (
    tester,
  ) async {
    AiDoctorConfig.setLanguage('bn');
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AiPatientFormPage()));
    await tester.pumpAndSettle();

    expect(find.text('নতুন রোগী'), findsOneWidget);
    expect(find.text('ছবি যোগ করুন'), findsOneWidget);
    expect(find.text('ব্যক্তিগত তথ্য'), findsOneWidget);
    expect(find.text('রক্তের গ্রুপ'), findsOneWidget);
    expect(find.text('ফোন নম্বর'), findsOneWidget);
    await tester.tap(find.text('ইং'));
    await tester.pumpAndSettle();
    expect(find.text('New patient'), findsOneWidget);
    expect(find.text('Personal details'), findsOneWidget);
    await tester.tap(find.text('বাং'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('রোগীর প্রোফাইল তৈরি করুন'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('রোগীর প্রোফাইল তৈরি করুন'), findsOneWidget);
  });

  test('emergency detection supports English and Bengali messages', () {
    expect(aiIsEmergency('I have severe chest pain'), isTrue);
    expect(aiIsEmergency('I am having DIFFICULTY BREATHING'), isTrue);
    expect(aiIsEmergency('আমার শ্বাসকষ্ট হচ্ছে'), isTrue);
    expect(aiIsEmergency('I have a mild headache'), isFalse);
  });
}
