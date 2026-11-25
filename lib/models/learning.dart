/// Level of medical alert / red flags
enum RedFlagLevel {
  observation, // সাধারণ যত্ন ও পর্যবেক্ষণ
  doctor, // চিকিৎসকের পরামর্শ
  emergency, // জরুরি চিকিৎসা / হাসপাতাল
}

class RedFlagItem {
  const RedFlagItem({
    required this.level,
    required this.title,
    required this.description,
    this.action = '',
  });

  final RedFlagLevel level;
  final String title;
  final String description;
  final String action;

  factory RedFlagItem.fromJson(Map<String, dynamic> json) {
    final rawLevel = json['level']?.toString().toLowerCase() ?? 'doctor';
    final level = switch (rawLevel) {
      'emergency' || 'urgent' || 'critical' => RedFlagLevel.emergency,
      'observation' || 'mild' || 'home' => RedFlagLevel.observation,
      _ => RedFlagLevel.doctor,
    };
    return RedFlagItem(
      level: level,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'title': title,
    'description': description,
    'action': action,
  };
}

/// Clinical or educational source reference
class MedicalReference {
  const MedicalReference({
    required this.id,
    required this.sourceName,
    required this.sourceTitle,
    this.contentId = '',
    this.sourceUrl = '',
    this.publicationDate,
    this.lastVerifiedAt,
    this.evidenceNote,
  });

  final String id;
  final String contentId;
  final String sourceName; // e.g. 'WHO', 'DGHS Bangladesh', 'CDC', 'NICE'
  final String sourceTitle;
  final String sourceUrl;
  final String? publicationDate;
  final String? lastVerifiedAt;
  final String? evidenceNote;

  factory MedicalReference.fromJson(
    Map<String, dynamic> json,
  ) => MedicalReference(
    id: json['id']?.toString() ?? '',
    contentId: json['content_id']?.toString() ?? '',
    sourceName:
        json['source_name']?.toString() ??
        json['sourceName']?.toString() ??
        'Official Health Guideline',
    sourceTitle:
        json['source_title']?.toString() ??
        json['sourceTitle']?.toString() ??
        '',
    sourceUrl:
        json['source_url']?.toString() ?? json['sourceUrl']?.toString() ?? '',
    publicationDate:
        json['publication_date']?.toString() ??
        json['publicationDate']?.toString(),
    lastVerifiedAt:
        json['last_verified_at']?.toString() ??
        json['lastVerifiedAt']?.toString(),
    evidenceNote:
        json['evidence_note']?.toString() ?? json['evidenceNote']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'content_id': contentId,
    'source_name': sourceName,
    'source_title': sourceTitle,
    'source_url': sourceUrl,
    'publication_date': publicationDate,
    'last_verified_at': lastVerifiedAt,
    'evidence_note': evidenceNote,
  };
}

/// Interactive medical term dictionary item
class MedicalTerm {
  const MedicalTerm({
    required this.id,
    required this.termEn,
    required this.termBn,
    required this.definitionBn,
    this.simpleExplanationBn = '',
    this.exampleBn = '',
    this.relatedLessonId,
    this.category = 'General',
  });

  final String id;
  final String termEn;
  final String termBn;
  final String definitionBn;
  final String simpleExplanationBn;
  final String exampleBn;
  final String? relatedLessonId;
  final String category;

  factory MedicalTerm.fromJson(Map<String, dynamic> json) => MedicalTerm(
    id: json['id']?.toString() ?? '',
    termEn: json['term_en']?.toString() ?? json['termEn']?.toString() ?? '',
    termBn: json['term_bn']?.toString() ?? json['termBn']?.toString() ?? '',
    definitionBn:
        json['definition_bn']?.toString() ??
        json['definitionBn']?.toString() ??
        '',
    simpleExplanationBn:
        json['simple_explanation_bn']?.toString() ??
        json['simpleExplanationBn']?.toString() ??
        '',
    exampleBn:
        json['example_bn']?.toString() ?? json['exampleBn']?.toString() ?? '',
    relatedLessonId:
        json['related_lesson_id']?.toString() ??
        json['relatedLessonId']?.toString(),
    category: json['category']?.toString() ?? 'General',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'term_en': termEn,
    'term_bn': termBn,
    'definition_bn': definitionBn,
    'simple_explanation_bn': simpleExplanationBn,
    'example_bn': exampleBn,
    'related_lesson_id': relatedLessonId,
    'category': category,
  };
}

/// Content block types for structured lesson articles
enum ContentBlockType {
  heading,
  paragraph,
  bulletList,
  numberedList,
  medicalTerm,
  image,
  diagram,
  safetyNotice,
  warning,
  comparisonTable,
  clinicalCase,
  referenceList,
  summary,
}

/// A structured content block in a lesson
class ContentBlock {
  const ContentBlock({
    required this.type,
    this.title,
    this.content = '',
    this.items = const [],
    this.tableHeaders = const [],
    this.tableRows = const [],
    this.term,
    this.severity = 'info',
  });

  final ContentBlockType type;
  final String? title;
  final String content;
  final List<String> items;
  final List<String> tableHeaders;
  final List<List<String>> tableRows;
  final MedicalTerm? term;
  final String severity; // 'info', 'warning', 'danger'

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString().toLowerCase() ?? 'paragraph';
    final type = switch (rawType) {
      'heading' || 'h1' || 'h2' || 'h3' => ContentBlockType.heading,
      'bullet_list' || 'bullets' || 'bulletlist' => ContentBlockType.bulletList,
      'numbered_list' ||
      'numbers' ||
      'numberedlist' => ContentBlockType.numberedList,
      'medical_term' || 'term' || 'medicalterm' => ContentBlockType.medicalTerm,
      'image' => ContentBlockType.image,
      'diagram' => ContentBlockType.diagram,
      'safety_notice' ||
      'safety' ||
      'notice' ||
      'safetynotice' => ContentBlockType.safetyNotice,
      'warning' || 'alert' => ContentBlockType.warning,
      'comparison_table' ||
      'table' ||
      'comparisontable' => ContentBlockType.comparisonTable,
      'clinical_case' ||
      'case' ||
      'clinicalcase' => ContentBlockType.clinicalCase,
      'reference_list' ||
      'references' ||
      'referencelist' => ContentBlockType.referenceList,
      'summary' => ContentBlockType.summary,
      _ => ContentBlockType.paragraph,
    };

    return ContentBlock(
      type: type,
      title: json['title']?.toString(),
      content: json['content']?.toString() ?? '',
      items: (json['items'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      tableHeaders: (json['table_headers'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      tableRows: (json['table_rows'] as List? ?? const [])
          .whereType<List>()
          .map((row) => row.map((cell) => cell.toString()).toList())
          .toList(),
      term: json['term'] is Map
          ? MedicalTerm.fromJson(Map<String, dynamic>.from(json['term'] as Map))
          : null,
      severity: json['severity']?.toString() ?? 'info',
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (title != null) 'title': title,
    'content': content,
    if (items.isNotEmpty) 'items': items,
    if (tableHeaders.isNotEmpty) 'table_headers': tableHeaders,
    if (tableRows.isNotEmpty) 'table_rows': tableRows,
    if (term != null) 'term': term!.toJson(),
    'severity': severity,
  };
}

/// Human Body System (Section 5 & 16.2)
class BodySystem {
  const BodySystem({
    required this.id,
    required this.nameBn,
    required this.nameEn,
    required this.descriptionBn,
    required this.descriptionEn,
    required this.iconKey,
    this.group = '',
    this.relatedCourseIds = const [],
    this.sortOrder = 0,
    this.bodyParts = const [],
    this.diseaseTopics = const [],
  });

  final String id;
  final String nameBn;
  final String nameEn;
  final String descriptionBn;
  final String descriptionEn;
  final String iconKey;

  /// Atlas bucket: `core`, `organ`, `region`, `life` or `group`. Empty on the
  /// original curriculum, which the repository files under `core`.
  final String group;

  /// Courses the catalogue links to this region, organ or condition class.
  final List<String> relatedCourseIds;

  final int sortOrder;
  final List<BodyPart> bodyParts;
  final List<DiseaseTopic> diseaseTopics;

  factory BodySystem.fromJson(Map<String, dynamic> json) => BodySystem(
    id: json['id']?.toString() ?? '',
    nameBn: json['name_bn']?.toString() ?? json['nameBn']?.toString() ?? '',
    nameEn: json['name_en']?.toString() ?? json['nameEn']?.toString() ?? '',
    descriptionBn:
        json['description_bn']?.toString() ??
        json['descriptionBn']?.toString() ??
        '',
    descriptionEn:
        json['description_en']?.toString() ??
        json['descriptionEn']?.toString() ??
        '',
    iconKey:
        json['icon_key']?.toString() ??
        json['iconKey']?.toString() ??
        'anatomy',
    group: json['group']?.toString() ?? '',
    relatedCourseIds: (json['related_course_ids'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    bodyParts: (json['body_parts'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => BodyPart.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    diseaseTopics: (json['disease_topics'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => DiseaseTopic.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name_bn': nameBn,
    'name_en': nameEn,
    'description_bn': descriptionBn,
    'description_en': descriptionEn,
    'icon_key': iconKey,
    'group': group,
    'related_course_ids': relatedCourseIds,
    'sort_order': sortOrder,
    'body_parts': bodyParts.map((e) => e.toJson()).toList(),
    'disease_topics': diseaseTopics.map((e) => e.toJson()).toList(),
  };
}

/// Human Body Part (Section 16.3)
class BodyPart {
  const BodyPart({
    required this.id,
    required this.bodySystemId,
    required this.nameBn,
    required this.nameEn,
    required this.description,
    this.relatedBodyPartIds = const [],
    this.diseaseTopics = const [],
  });

  final String id;
  final String bodySystemId;
  final String nameBn;
  final String nameEn;
  final String description;
  final List<String> relatedBodyPartIds;
  final List<DiseaseTopic> diseaseTopics;

  factory BodyPart.fromJson(Map<String, dynamic> json) => BodyPart(
    id: json['id']?.toString() ?? '',
    bodySystemId:
        json['body_system_id']?.toString() ??
        json['bodySystemId']?.toString() ??
        '',
    nameBn: json['name_bn']?.toString() ?? json['nameBn']?.toString() ?? '',
    nameEn: json['name_en']?.toString() ?? json['nameEn']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    relatedBodyPartIds: (json['related_body_part_ids'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    diseaseTopics: (json['disease_topics'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => DiseaseTopic.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'body_system_id': bodySystemId,
    'name_bn': nameBn,
    'name_en': nameEn,
    'description': description,
    'related_body_part_ids': relatedBodyPartIds,
    'disease_topics': diseaseTopics.map((e) => e.toJson()).toList(),
  };
}

/// Disease Topic Model (Section 16.4 & Section 7 Standard Template)
class DiseaseTopic {
  const DiseaseTopic({
    required this.id,
    required this.titleBn,
    required this.titleEn,
    required this.summary,
    this.bodyPartId = '',
    this.bodySystemId = '',
    this.slug = '',
    this.causes = const [],
    this.symptoms = const [],
    this.differentialDiagnosis = const [],
    this.treatmentOverview = const [],
    this.homeCare = const [],
    this.whatToDo = const [],
    this.whatNotToDo = const [],
    this.prevention = const [],
    this.relatedMedicines = const [],
    this.redFlags = const [],
    this.references = const [],
    this.contentVersion = 1,
    this.lastVerifiedAt = '2026-10-26',
    this.reviewStatus = 'Verified',
    this.lessons = const [],
    this.courseId,
  });

  final String id;
  final String bodyPartId;
  final String bodySystemId;
  final String titleBn;
  final String titleEn;
  final String slug;
  final String summary;
  final List<String> causes;
  final List<String> symptoms;
  final List<String> differentialDiagnosis;
  final List<String> treatmentOverview;
  final List<String> homeCare;
  final List<String> whatToDo;
  final List<String> whatNotToDo;
  final List<String> prevention;
  final List<String> relatedMedicines;
  final List<RedFlagItem> redFlags;
  final List<MedicalReference> references;
  final int contentVersion;
  final String lastVerifiedAt;
  final String reviewStatus;
  final List<Lesson> lessons;
  final String? courseId;

  factory DiseaseTopic.fromJson(Map<String, dynamic> json) => DiseaseTopic(
    id: json['id']?.toString() ?? '',
    bodyPartId:
        json['body_part_id']?.toString() ??
        json['bodyPartId']?.toString() ??
        '',
    bodySystemId:
        json['body_system_id']?.toString() ??
        json['bodySystemId']?.toString() ??
        '',
    titleBn:
        json['title_bn']?.toString() ??
        json['titleBn']?.toString() ??
        json['title']?.toString() ??
        '',
    titleEn: json['title_en']?.toString() ?? json['titleEn']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    summary: json['summary']?.toString() ?? '',
    causes: (json['causes'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    symptoms: (json['symptoms'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    differentialDiagnosis: (json['differential_diagnosis'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    treatmentOverview: (json['treatment_overview'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    homeCare: (json['home_care'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    whatToDo: (json['what_to_do'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    whatNotToDo: (json['what_not_to_do'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    prevention: (json['prevention'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    relatedMedicines: (json['related_medicines'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    redFlags: (json['red_flags'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => RedFlagItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    references: (json['references'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MedicalReference.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    contentVersion:
        int.tryParse(json['content_version']?.toString() ?? '') ?? 1,
    lastVerifiedAt: json['last_verified_at']?.toString() ?? '2026-10-26',
    reviewStatus: json['review_status']?.toString() ?? 'Verified',
    lessons: (json['lessons'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    courseId: json['course_id']?.toString() ?? json['courseId']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'body_part_id': bodyPartId,
    'body_system_id': bodySystemId,
    'title_bn': titleBn,
    'title_en': titleEn,
    'slug': slug,
    'summary': summary,
    'causes': causes,
    'symptoms': symptoms,
    'differential_diagnosis': differentialDiagnosis,
    'treatment_overview': treatmentOverview,
    'home_care': homeCare,
    'what_to_do': whatToDo,
    'what_not_to_do': whatNotToDo,
    'prevention': prevention,
    'related_medicines': relatedMedicines,
    'red_flags': redFlags.map((e) => e.toJson()).toList(),
    'references': references.map((e) => e.toJson()).toList(),
    'content_version': contentVersion,
    'last_verified_at': lastVerifiedAt,
    'review_status': reviewStatus,
    'lessons': lessons.map((e) => e.toJson()).toList(),
    if (courseId != null) 'course_id': courseId,
  };
}

/// Course Model (Section 16.1)
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.lessons,
    required this.quiz,
    this.category = 'medicine',
    this.track = '',
    this.atlasTags = const [],
    this.titleBn,
    this.titleEn,
    this.descriptionBn,
    this.descriptionEn,
    this.bodySystemId,
    this.difficulty = 'Beginner',
    this.estimatedDuration = 15,
    this.version = 1,
    this.status = 'published',
    this.passingScoreRatio = 0.8, // 80% passing score as required by PRD 11.5
    this.references = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final List<Lesson> lessons;
  final List<QuizQuestion> quiz;

  /// `medicine` for drug-literacy courses, `body` for body-system and disease
  /// courses, `pharmacy` for pharmacy practice courses.
  final String category;

  /// Shelf id from `library_tracks.json` this course sits on. Empty on assets
  /// that predate the shelves; `LearningRepository` maps them onto one.
  final String track;

  /// Atlas rows (`body_systems_atlas.json` ids) this course helps read.
  final List<String> atlasTags;

  final String? titleBn;
  final String? titleEn;
  final String? descriptionBn;
  final String? descriptionEn;
  final String? bodySystemId;
  final String difficulty;
  final int estimatedDuration;
  final int version;
  final String status;
  final double passingScoreRatio;
  final List<MedicalReference> references;

  double get passRatio => passingScoreRatio;
  double effectivePassRatio([Lesson? lesson]) =>
      lesson?.passingScoreRatio ?? passingScoreRatio;

  bool get isBodySystem => category == 'body';
  bool get isPharmacy => category == 'pharmacy';

  String get effectiveTitle => titleBn ?? title;
  String get effectiveSubtitle => descriptionBn ?? subtitle;

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? json['title_bn']?.toString() ?? '',
    subtitle:
        json['subtitle']?.toString() ??
        json['description_bn']?.toString() ??
        '',
    icon: json['icon']?.toString() ?? 'book',
    category: json['category']?.toString() ?? 'medicine',
    track: json['track']?.toString() ?? '',
    atlasTags: (json['atlas_tags'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    titleBn: json['title_bn']?.toString(),
    titleEn: json['title_en']?.toString(),
    descriptionBn: json['description_bn']?.toString(),
    descriptionEn: json['description_en']?.toString(),
    bodySystemId: json['body_system_id']?.toString(),
    difficulty: json['difficulty']?.toString() ?? 'Beginner',
    estimatedDuration:
        int.tryParse(json['estimated_duration']?.toString() ?? '') ?? 15,
    version: int.tryParse(json['version']?.toString() ?? '') ?? 1,
    status: json['status']?.toString() ?? 'published',
    passingScoreRatio: (json['passing_score_ratio'] as num?)?.toDouble() ?? 0.8,
    references: (json['references'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MedicalReference.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    lessons: (json['lessons'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Lesson.fromJson(e.cast<String, dynamic>()))
        .toList(),
    quiz: (json['quiz'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => QuizQuestion.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'icon': icon,
    'category': category,
    'track': track,
    'atlas_tags': atlasTags,
    if (titleBn != null) 'title_bn': titleBn,
    if (titleEn != null) 'title_en': titleEn,
    if (descriptionBn != null) 'description_bn': descriptionBn,
    if (descriptionEn != null) 'description_en': descriptionEn,
    if (bodySystemId != null) 'body_system_id': bodySystemId,
    'difficulty': difficulty,
    'estimated_duration': estimatedDuration,
    'version': version,
    'status': status,
    'passing_score_ratio': passingScoreRatio,
    'references': references.map((e) => e.toJson()).toList(),
    'lessons': lessons.map((e) => e.toJson()).toList(),
    'quiz': quiz.map((e) => e.toJson()).toList(),
  };
}

/// A named shelf of the course library, as declared in `library_tracks.json`.
class LearningTrack {
  const LearningTrack({required this.id, required this.labelBn});

  final String id;
  final String labelBn;

  factory LearningTrack.fromJson(Map<String, dynamic> json) => LearningTrack(
    id: json['id']?.toString() ?? '',
    labelBn: json['label_bn']?.toString() ?? json['labelBn']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'label_bn': labelBn};
}

/// One indication inside a pharmacy subject, e.g. "bacterial sore throat →
/// penicillin group". Educational only — never a prescription.
class SubjectIndication {
  const SubjectIndication({
    required this.condition,
    required this.group,
    required this.note,
  });

  final String condition;
  final String group;
  final String note;

  factory SubjectIndication.fromJson(Map<String, dynamic> json) =>
      SubjectIndication(
        condition: json['condition']?.toString() ?? '',
        group: json['group']?.toString() ?? '',
        note: json['note']?.toString() ?? '',
      );
}

/// A subject in the redesigned course library. Subjects group several of the
/// existing library shelves and add practice-oriented subtopics on top.
class StudySubject {
  const StudySubject({
    required this.id,
    required this.titleBn,
    required this.descriptionBn,
    required this.icon,
    required this.trackIds,
    this.subtopics = const [],
    this.indications = const [],
    this.courseIds = const [],
    this.accentIndex = 0,
  });

  final String id;
  final String titleBn;
  final String descriptionBn;
  final String icon;
  final List<String> trackIds;
  final List<String> subtopics;
  final List<SubjectIndication> indications;
  final List<String> courseIds;
  final int accentIndex;

  factory StudySubject.fromJson(Map<String, dynamic> json) => StudySubject(
    id: json['id']?.toString() ?? '',
    titleBn: json['title_bn']?.toString() ?? '',
    descriptionBn: json['description_bn']?.toString() ?? '',
    icon: json['icon']?.toString() ?? 'book',
    trackIds: (json['tracks'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    subtopics: (json['subtopics'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    indications: (json['indications'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (e) => SubjectIndication.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(),
    courseIds: (json['courses'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    accentIndex:
        int.tryParse(json['accent']?.toString() ?? '') ?? 0,
  );

  bool matches(Course course) =>
      courseIds.contains(course.id) || trackIds.contains(course.track);
}

/// Lesson Model (Section 16.5 & Section 10 Reader)
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.keyPoints,
    required this.minutes,
    this.quiz = const [],
    this.courseId,
    this.moduleId,
    this.diseaseTopicId,
    this.titleBn,
    this.titleEn,
    this.contentBlocks = const [],
    this.learningObjectives = const [],
    this.sortOrder = 0,
    this.prerequisiteLessonIds = const [],
    this.version = 1,
    this.reviewStatus = 'Verified',
    this.references = const [],
    this.passingScoreRatio = 0.8,
  });

  final String id;
  final String title;
  final String summary;
  final String body;
  final List<String> keyPoints;
  final int minutes;
  final List<QuizQuestion> quiz;

  final String? courseId;
  final String? moduleId;
  final String? diseaseTopicId;
  final String? titleBn;
  final String? titleEn;
  final List<ContentBlock> contentBlocks;
  final List<String> learningObjectives;
  final int sortOrder;
  final List<String> prerequisiteLessonIds;
  final int version;
  final String reviewStatus;
  final List<MedicalReference> references;
  final double passingScoreRatio;

  double get passRatio => passingScoreRatio;
  bool get hasQuiz => quiz.isNotEmpty;
  bool get hasContentBlocks => contentBlocks.isNotEmpty;
  String get effectiveTitle => titleBn ?? title;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? json['title_bn']?.toString() ?? '',
    summary: json['summary']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    keyPoints:
        (json['keyPoints'] as List? ?? json['key_points'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
    minutes:
        int.tryParse(
          json['minutes']?.toString() ??
              json['estimated_duration']?.toString() ??
              '',
        ) ??
        5,
    quiz: (json['quiz'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => QuizQuestion.fromJson(e.cast<String, dynamic>()))
        .toList(),
    courseId: json['course_id']?.toString() ?? json['courseId']?.toString(),
    moduleId: json['module_id']?.toString() ?? json['moduleId']?.toString(),
    diseaseTopicId:
        json['disease_topic_id']?.toString() ??
        json['diseaseTopicId']?.toString(),
    titleBn: json['title_bn']?.toString(),
    titleEn: json['title_en']?.toString(),
    contentBlocks: (json['content_blocks'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ContentBlock.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    learningObjectives: (json['learning_objectives'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    prerequisiteLessonIds:
        (json['prerequisite_lesson_ids'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
    version: int.tryParse(json['version']?.toString() ?? '') ?? 1,
    reviewStatus: json['review_status']?.toString() ?? 'Verified',
    references: (json['references'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => MedicalReference.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    passingScoreRatio: (json['passing_score_ratio'] as num?)?.toDouble() ?? 0.8,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'body': body,
    'keyPoints': keyPoints,
    'minutes': minutes,
    'quiz': quiz.map((e) => e.toJson()).toList(),
    if (courseId != null) 'course_id': courseId,
    if (moduleId != null) 'module_id': moduleId,
    if (diseaseTopicId != null) 'disease_topic_id': diseaseTopicId,
    if (titleBn != null) 'title_bn': titleBn,
    if (titleEn != null) 'title_en': titleEn,
    if (contentBlocks.isNotEmpty)
      'content_blocks': contentBlocks.map((e) => e.toJson()).toList(),
    if (learningObjectives.isNotEmpty)
      'learning_objectives': learningObjectives,
    'sort_order': sortOrder,
    if (prerequisiteLessonIds.isNotEmpty)
      'prerequisite_lesson_ids': prerequisiteLessonIds,
    'version': version,
    'review_status': reviewStatus,
    if (references.isNotEmpty)
      'references': references.map((e) => e.toJson()).toList(),
    'passing_score_ratio': passingScoreRatio,
  };
}

/// Question Types (Section 11.2)
enum QuizQuestionType {
  singleChoice,
  trueFalse,
  clinicalScenario,
  symptomIdentification,
  medicineSafety,
  medicalTerminology,
}

/// Quiz Question Model (Section 16.6)
class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.id,
    this.lessonId,
    this.questionBn,
    this.questionEn,
    this.questionType = QuizQuestionType.singleChoice,
    this.explanationBn,
    this.explanationEn,
    this.difficulty = 'Medium',
    this.reviewStatus = 'Verified',
  });

  final String? id;
  final String? lessonId;
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;
  final String? questionBn;
  final String? questionEn;
  final QuizQuestionType questionType;
  final String? explanationBn;
  final String? explanationEn;
  final String difficulty;
  final String reviewStatus;

  String get effectiveQuestion => questionBn ?? question;
  String get effectiveExplanation => explanationBn ?? explanation;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final rawType =
        json['question_type']?.toString().toLowerCase() ?? 'single_choice';
    final questionType = switch (rawType) {
      'true_false' || 'truefalse' => QuizQuestionType.trueFalse,
      'clinical_scenario' || 'scenario' => QuizQuestionType.clinicalScenario,
      'symptom_identification' ||
      'symptom' => QuizQuestionType.symptomIdentification,
      'medicine_safety' || 'safety' => QuizQuestionType.medicineSafety,
      'medical_terminology' ||
      'terminology' => QuizQuestionType.medicalTerminology,
      _ => QuizQuestionType.singleChoice,
    };

    return QuizQuestion(
      id: json['id']?.toString(),
      lessonId: json['lesson_id']?.toString(),
      question:
          json['question']?.toString() ?? json['question_bn']?.toString() ?? '',
      options: (json['options'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      answer: int.tryParse(json['answer']?.toString() ?? '') ?? 0,
      explanation:
          json['explanation']?.toString() ??
          json['explanation_bn']?.toString() ??
          '',
      questionBn: json['question_bn']?.toString(),
      questionEn: json['question_en']?.toString(),
      questionType: questionType,
      explanationBn: json['explanation_bn']?.toString(),
      explanationEn: json['explanation_en']?.toString(),
      difficulty: json['difficulty']?.toString() ?? 'Medium',
      reviewStatus: json['review_status']?.toString() ?? 'Verified',
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (lessonId != null) 'lesson_id': lessonId,
    'question': question,
    'options': options,
    'answer': answer,
    'explanation': explanation,
    if (questionBn != null) 'question_bn': questionBn,
    if (questionEn != null) 'question_en': questionEn,
    'question_type': questionType.name,
    if (explanationBn != null) 'explanation_bn': explanationBn,
    if (explanationEn != null) 'explanation_en': explanationEn,
    'difficulty': difficulty,
    'review_status': reviewStatus,
  };
}

/// Transient quiz state
class QuizOutcome {
  const QuizOutcome({required this.score, required this.total});

  final int score;
  final int total;

  double get ratio => total == 0 ? 0 : score / total;
}

/// One lesson the reader opened, as recorded in `learning_progress`.
class LessonRead {
  const LessonRead({
    required this.courseId,
    required this.lessonId,
    required this.visits,
    required this.lastReadAt,
    this.completed = false,
  });

  final String courseId;
  final String lessonId;
  final int visits;
  final int lastReadAt;
  final bool completed;

  String get key => '$courseId::$lessonId';
}

/// A lesson the learning hub proposes next
class LessonSuggestion {
  const LessonSuggestion({
    required this.course,
    required this.lesson,
    required this.reason,
    required this.score,
    this.easierEntry = false,
  });

  final Course course;
  final Lesson lesson;
  final String reason;
  final int score;
  final bool easierEntry;

  String get key => '${course.id}::${lesson.id}';
}

/// Quiz Attempt Record (Section 16.8)
class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.courseId,
    required this.lessonId,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.submittedAt,
    this.attemptNumber = 1,
    this.passed = false,
  });

  final int id;
  final String courseId;
  final String lessonId;
  final int score;
  final int totalQuestions;
  final int correctAnswers;
  final int submittedAt;
  final int attemptNumber;
  final bool passed;

  double get percentage =>
      totalQuestions == 0 ? 0 : (score / totalQuestions) * 100;

  factory QuizAttempt.fromJson(Map<String, dynamic> json) => QuizAttempt(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    courseId: json['course_id']?.toString() ?? '',
    lessonId: json['lesson_id']?.toString() ?? '',
    score: int.tryParse(json['score']?.toString() ?? '') ?? 0,
    totalQuestions:
        int.tryParse(
          json['total_questions']?.toString() ??
              json['total']?.toString() ??
              '',
        ) ??
        0,
    correctAnswers:
        int.tryParse(
          json['correct_answers']?.toString() ??
              json['score']?.toString() ??
              '',
        ) ??
        0,
    submittedAt:
        int.tryParse(
          json['submitted_at']?.toString() ??
              json['taken_at']?.toString() ??
              '',
        ) ??
        0,
    attemptNumber: int.tryParse(json['attempt_number']?.toString() ?? '') ?? 1,
    passed: json['passed'] == 1 || json['passed'] == true,
  );
}
