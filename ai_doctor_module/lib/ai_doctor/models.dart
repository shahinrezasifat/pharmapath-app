String aiSinceText(DateTime d) {
  final days = DateTime.now().difference(d).inDays;
  if (days < 1) return 'Started today';
  if (days < 30) return 'Started $days ${days == 1 ? 'day' : 'days'} ago';
  if (days < 365) {
    final months = days ~/ 30;
    return 'Started $months ${months == 1 ? 'month' : 'months'} ago';
  }
  final y = days ~/ 365, m = (days % 365) ~/ 30;
  final years = 'Started $y ${y == 1 ? 'year' : 'years'} ago';
  return m == 0 ? years : '$years, $m ${m == 1 ? 'month' : 'months'}';
}

class AiPatient {
  final int? id;
  final String name, relation, gender, bloodGroup, phone, photoPath;
  final int age;
  AiPatient({
    this.id,
    required this.name,
    required this.age,
    this.relation = '',
    this.gender = '',
    this.bloodGroup = '',
    this.phone = '',
    this.photoPath = '',
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'age': age,
    'relation': relation,
    'gender': gender,
    'blood_group': bloodGroup,
    'phone': phone,
    'photo_path': photoPath,
  };

  factory AiPatient.fromMap(Map<String, Object?> m) => AiPatient(
    id: m['id'] as int?,
    name: m['name'] as String,
    age: m['age'] as int,
    relation: (m['relation'] as String?) ?? '',
    gender: (m['gender'] as String?) ?? '',
    bloodGroup: (m['blood_group'] as String?) ?? '',
    phone: (m['phone'] as String?) ?? '',
    photoPath: (m['photo_path'] as String?) ?? '',
  );
}

class AiMedicineOption {
  const AiMedicineOption({
    required this.name,
    this.genericName = '',
    this.strength = '',
    this.dosageForm = '',
  });

  final String name;
  final String genericName;
  final String strength;
  final String dosageForm;

  String get subtitle => [
    genericName,
    strength,
    dosageForm,
  ].where((value) => value.trim().isNotEmpty).join(' · ');
}

class AiCondition {
  final int? id;
  final int patientId;
  final String name;
  final String type; // 'current' | 'past'
  final int? sinceYear;
  AiCondition({
    this.id,
    required this.patientId,
    required this.name,
    required this.type,
    this.sinceYear,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'patient_id': patientId,
    'name': name,
    'type': type,
    'since_year': sinceYear,
  };

  factory AiCondition.fromMap(Map<String, Object?> m) => AiCondition(
    id: m['id'] as int?,
    patientId: m['patient_id'] as int,
    name: m['name'] as String,
    type: m['type'] as String,
    sinceYear: m['since_year'] as int?,
  );
}

class AiDailyTask {
  const AiDailyTask({
    this.id,
    required this.patientId,
    required this.title,
    this.time = '',
    this.doneOn = '',
  });

  final int? id;
  final int patientId;
  final String title;
  final String time;
  final String doneOn;

  bool get isDoneToday {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return doneOn == today;
  }

  AiDailyTask copyWith({String? doneOn}) => AiDailyTask(
    id: id,
    patientId: patientId,
    title: title,
    time: time,
    doneOn: doneOn ?? this.doneOn,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'patient_id': patientId,
    'title': title,
    'time': time,
    'done_on': doneOn,
  };

  factory AiDailyTask.fromMap(Map<String, Object?> map) => AiDailyTask(
    id: map['id'] as int?,
    patientId: map['patient_id'] as int,
    title: map['title'] as String,
    time: (map['time'] as String?) ?? '',
    doneOn: (map['done_on'] as String?) ?? '',
  );
}

class AiMedication {
  final int? id;
  final int patientId;
  final String name, dose, status, unit, dosageForm;
  final int timesPerDay; // status: 'current' | 'stopped'
  final DateTime startedAt;
  final DateTime? stoppedAt;

  AiMedication({
    this.id,
    required this.patientId,
    required this.name,
    this.dose = '',
    this.timesPerDay = 1,
    this.unit = 'tablet',
    this.dosageForm = 'Tablet',
    DateTime? startedAt,
    this.status = 'current',
    this.stoppedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  String get since => aiSinceText(startedAt);

  AiMedication copyWith({
    String? name,
    String? dose,
    int? timesPerDay,
    String? unit,
    String? dosageForm,
    DateTime? startedAt,
    String? status,
    DateTime? stoppedAt,
  }) => AiMedication(
    id: id,
    patientId: patientId,
    name: name ?? this.name,
    dose: dose ?? this.dose,
    timesPerDay: timesPerDay ?? this.timesPerDay,
    unit: unit ?? this.unit,
    dosageForm: dosageForm ?? this.dosageForm,
    startedAt: startedAt ?? this.startedAt,
    status: status ?? this.status,
    stoppedAt: stoppedAt ?? this.stoppedAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'patient_id': patientId,
    'name': name,
    'dose': dose,
    'times_per_day': timesPerDay,
    'unit': unit,
    'dosage_form': dosageForm,
    'started_at': startedAt.millisecondsSinceEpoch,
    'status': status,
    'stopped_at': stoppedAt?.millisecondsSinceEpoch,
  };

  factory AiMedication.fromMap(Map<String, Object?> m) => AiMedication(
    id: m['id'] as int?,
    patientId: m['patient_id'] as int,
    name: m['name'] as String,
    dose: (m['dose'] as String?) ?? '',
    timesPerDay: (m['times_per_day'] as int?) ?? 1,
    unit: (m['unit'] as String?) ?? 'tablet',
    dosageForm: (m['dosage_form'] as String?) ?? 'Tablet',
    startedAt: DateTime.fromMillisecondsSinceEpoch(m['started_at'] as int),
    status: m['status'] as String,
    stoppedAt: m['stopped_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['stopped_at'] as int),
  );
}

class AiAllergy {
  final int? id;
  final int patientId;
  final String name;
  AiAllergy({this.id, required this.patientId, required this.name});

  Map<String, Object?> toMap() => {
    'id': id,
    'patient_id': patientId,
    'name': name,
  };
  factory AiAllergy.fromMap(Map<String, Object?> m) => AiAllergy(
    id: m['id'] as int?,
    patientId: m['patient_id'] as int,
    name: m['name'] as String,
  );
}

class AiChatMessage {
  final int? id;
  final int patientId;
  final String doctorId, role, text, imagePath;
  final DateTime createdAt;
  AiChatMessage({
    this.id,
    required this.patientId,
    required this.doctorId,
    required this.role,
    required this.text,
    this.imagePath = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
    'id': id,
    'patient_id': patientId,
    'doctor_id': doctorId,
    'role': role,
    'text': text,
    'image_path': imagePath,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory AiChatMessage.fromMap(Map<String, Object?> m) => AiChatMessage(
    id: m['id'] as int?,
    patientId: m['patient_id'] as int,
    doctorId: m['doctor_id'] as String,
    role: m['role'] as String,
    text: m['text'] as String,
    imagePath: (m['image_path'] as String?) ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );
}

class AiDoctor {
  final String id, name, initial, role, model;
  final bool vision, fast, best;
  const AiDoctor(
    this.id,
    this.name,
    this.initial,
    this.role,
    this.model, {
    this.vision = false,
    this.fast = false,
    this.best = false,
  });
}

const aiDoctors = <AiDoctor>[
  AiDoctor(
    'aftab',
    'Dr. Aftab Uddin',
    'A',
    'Lead Consultant',
    'nvidia/nemotron-3-ultra-550b-a55b:free',
    best: true,
  ),
  AiDoctor(
    'ariful',
    'Dr. Ariful Islam',
    'A',
    'Senior Consultant',
    'nvidia/nemotron-3.5-super-vl:free',
    vision: true,
  ),
  AiDoctor(
    'mahmuda',
    'Dr. Mahmuda Khatun',
    'M',
    'Senior Consultant',
    'nvidia/nemotron-3.5-lightning:free',
    fast: true,
  ),
  AiDoctor(
    'sajid',
    'Dr. Sajid Karim',
    'S',
    'Consultant',
    'google/gemma-4-31b-it:free',
    vision: true,
  ),
  AiDoctor(
    'tanvir',
    'Dr. Tanvir Ahmed',
    'T',
    'Resident',
    'google/gemma-4-26b-a4b-it:free',
    vision: true,
  ),
];
