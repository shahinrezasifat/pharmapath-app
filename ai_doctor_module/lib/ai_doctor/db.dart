import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class AiDoctorDb {
  AiDoctorDb._();
  static final AiDoctorDb i = AiDoctorDb._();
  Future<Database>? _dbFuture;

  /// Cache the in-flight future, not just the result: two concurrent first
  /// callers must share one connection instead of opening two handles.
  Future<Database> get db => _dbFuture ??= _open();

  Future<Database> _open() async {
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final path = p.join(directory.path, 'ai_doctor.db');
    return openDatabase(
      path,
      version: 5,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        await d.execute('''CREATE TABLE patients(
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
          age INTEGER NOT NULL, gender TEXT, relation TEXT,
          blood_group TEXT, phone TEXT, photo_path TEXT)''');
        await d.execute('''CREATE TABLE conditions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
          name TEXT NOT NULL, type TEXT NOT NULL, since_year INTEGER)''');
        await d.execute('''CREATE TABLE medications(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
          name TEXT NOT NULL, dose TEXT, started_at INTEGER NOT NULL,
          times_per_day INTEGER NOT NULL DEFAULT 1,
          unit TEXT NOT NULL DEFAULT 'tablet', dosage_form TEXT NOT NULL DEFAULT 'Tablet',
          status TEXT NOT NULL DEFAULT 'current', stopped_at INTEGER)''');
        await d.execute('''CREATE TABLE allergies(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
          name TEXT NOT NULL)''');
        await d.execute('''CREATE TABLE messages(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
          doctor_id TEXT NOT NULL, role TEXT NOT NULL, text TEXT NOT NULL,
          image_path TEXT, created_at INTEGER NOT NULL)''');
        await d.execute('''CREATE TABLE daily_tasks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
          title TEXT NOT NULL, time TEXT NOT NULL DEFAULT '',
          done_on TEXT NOT NULL DEFAULT '')''');
      },
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await d.execute('ALTER TABLE patients ADD COLUMN blood_group TEXT');
          await d.execute('ALTER TABLE patients ADD COLUMN phone TEXT');
          await d.execute('ALTER TABLE patients ADD COLUMN photo_path TEXT');
        }
        if (oldVersion < 3) {
          await d.execute(
            'ALTER TABLE medications ADD COLUMN times_per_day INTEGER NOT NULL DEFAULT 1',
          );
          await d.execute(
            "ALTER TABLE medications ADD COLUMN unit TEXT NOT NULL DEFAULT 'tablet'",
          );
          await d.execute(
            "ALTER TABLE medications ADD COLUMN dosage_form TEXT NOT NULL DEFAULT 'Tablet'",
          );
        }
        if (oldVersion < 4) {
          await d.execute('ALTER TABLE messages ADD COLUMN image_path TEXT');
        }
        if (oldVersion < 5) {
          await d.execute('''CREATE TABLE daily_tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
            title TEXT NOT NULL, time TEXT NOT NULL DEFAULT '',
            done_on TEXT NOT NULL DEFAULT '')''');
        }
      },
    );
  }

  // ---- patients
  Future<List<AiPatient>> patients() async {
    final r = await (await db).query('patients', orderBy: 'id DESC');
    return r.map(AiPatient.fromMap).toList();
  }

  Future<AiPatient?> patient(int id) async {
    final r = await (await db).query(
      'patients',
      where: 'id=?',
      whereArgs: [id],
    );
    if (r.isEmpty) return null;
    return AiPatient.fromMap(r.first);
  }

  Future<int> addPatient(AiPatient p) async =>
      (await db).insert('patients', p.toMap()..remove('id'));

  Future<void> updatePatient(AiPatient p) async {
    if (p.id == null) throw ArgumentError.value(p.id, 'id', 'Required');
    await (await db).update(
      'patients',
      p.toMap()..remove('id'),
      where: 'id=?',
      whereArgs: [p.id],
    );
  }

  Future<void> deletePatient(int id) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('daily_tasks', where: 'patient_id=?', whereArgs: [id]);
      await txn.delete('messages', where: 'patient_id=?', whereArgs: [id]);
      await txn.delete('allergies', where: 'patient_id=?', whereArgs: [id]);
      await txn.delete('medications', where: 'patient_id=?', whereArgs: [id]);
      await txn.delete('conditions', where: 'patient_id=?', whereArgs: [id]);
      await txn.delete('patients', where: 'id=?', whereArgs: [id]);
    });
  }

  /// তালিকার কার্ডের জন্য এক লাইনের সারাংশ
  Future<String> currentSummary(int patientId) async {
    final r = await (await db).query(
      'conditions',
      where: 'patient_id=? AND type=?',
      whereArgs: [patientId, 'current'],
    );
    return r.isEmpty
        ? 'No current conditions added'
        : r.map((e) => e['name']).join(', ');
  }

  // ---- conditions
  Future<List<AiCondition>> conditions(int pid, {String? type}) async {
    final r = await (await db).query(
      'conditions',
      where: type == null ? 'patient_id=?' : 'patient_id=? AND type=?',
      whereArgs: type == null ? [pid] : [pid, type],
    );
    return r.map(AiCondition.fromMap).toList();
  }

  Future<void> addCondition(AiCondition c) async =>
      (await db).insert('conditions', c.toMap()..remove('id'));
  Future<void> deleteCondition(int id) async =>
      (await db).delete('conditions', where: 'id=?', whereArgs: [id]);

  // ---- medications
  Future<List<AiMedication>> meds(int pid, {String status = 'current'}) async {
    final r = await (await db).query(
      'medications',
      where: 'patient_id=? AND status=?',
      whereArgs: [pid, status],
      orderBy: 'started_at ASC',
    );
    return r.map(AiMedication.fromMap).toList();
  }

  Future<void> addMed(AiMedication m) async =>
      (await db).insert('medications', m.toMap()..remove('id'));

  Future<void> updateMed(AiMedication m) async => (await db).update(
    'medications',
    m.toMap(),
    where: 'id=?',
    whereArgs: [m.id],
  );

  /// বন্ধ করা ওষুধ মোছে না, ইতিহাসে রাখে
  Future<void> stopMed(AiMedication m) async =>
      updateMed(m.copyWith(status: 'stopped', stoppedAt: DateTime.now()));

  // ---- allergies
  Future<List<AiAllergy>> allergies(int pid) async {
    final r = await (await db).query(
      'allergies',
      where: 'patient_id=?',
      whereArgs: [pid],
    );
    return r.map(AiAllergy.fromMap).toList();
  }

  Future<void> addAllergy(AiAllergy a) async =>
      (await db).insert('allergies', a.toMap()..remove('id'));
  Future<void> deleteAllergy(int id) async =>
      (await db).delete('allergies', where: 'id=?', whereArgs: [id]);

  Future<List<AiDailyTask>> dailyTasks(int patientId) async {
    final rows = await (await db).query(
      'daily_tasks',
      where: 'patient_id=?',
      whereArgs: [patientId],
      orderBy: 'time ASC, id ASC',
    );
    return rows.map(AiDailyTask.fromMap).toList();
  }

  Future<int> addDailyTask(AiDailyTask task) async =>
      (await db).insert('daily_tasks', task.toMap()..remove('id'));

  Future<void> updateDailyTask(AiDailyTask task) async {
    if (task.id == null) throw ArgumentError.value(task.id, 'id', 'Required');
    await (await db).update(
      'daily_tasks',
      task.toMap()..remove('id'),
      where: 'id=?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteDailyTask(int id) async =>
      (await db).delete('daily_tasks', where: 'id=?', whereArgs: [id]);

  // ---- messages
  Future<List<AiChatMessage>> messages(int pid) async {
    final r = await (await db).query(
      'messages',
      where: 'patient_id=?',
      whereArgs: [pid],
      orderBy: 'id ASC',
    );
    return r.map(AiChatMessage.fromMap).toList();
  }

  Future<void> addMessage(AiChatMessage m) async =>
      (await db).insert('messages', m.toMap()..remove('id'));
}
